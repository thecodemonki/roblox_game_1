-- Evolve Game Server
-- Phase 1: Food spawning + points system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalPools = require(Shared:WaitForChild("AnimalPools"))

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUp = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
local animalPicked = ReplicatedStorage:WaitForChild("AnimalPicked") :: RemoteEvent
local playerDied = ReplicatedStorage:WaitForChild("PlayerDied") :: RemoteEvent
local playerEaten = ReplicatedStorage:WaitForChild("PlayerEaten") :: RemoteEvent

local EVOLUTION_FF_NAME = "EvolutionPickShield"

-- Level curve: piecewise linear between (points, level) anchors; below 10 pts stays level 1.
local LEVEL_ANCHORS = {
	{ points = 10, level = 2 },
	{ points = 30, level = 5 },
	{ points = 75, level = 10 },
	{ points = 150, level = 18 },
	{ points = 280, level = 28 },
	{ points = 450, level = 40 },
	{ points = 700, level = 55 },
}

local function getLevelFromPoints(points: number): number
	if points < 10 then
		return 1
	end
	if points >= LEVEL_ANCHORS[#LEVEL_ANCHORS].points then
		return LEVEL_ANCHORS[#LEVEL_ANCHORS].level
	end
	for i = 1, #LEVEL_ANCHORS - 1 do
		local a = LEVEL_ANCHORS[i]
		local b = LEVEL_ANCHORS[i + 1]
		if points < b.points then
			local t = (points - a.points) / (b.points - a.points)
			return math.floor(a.level + t * (b.level - a.level))
		end
	end
	return LEVEL_ANCHORS[#LEVEL_ANCHORS].level
end

-- Smallest point total that yields `targetLevel` under getLevelFromPoints.
local function getMinPointsForLevel(targetLevel: number): number
	if targetLevel <= 1 then
		return 0
	end
	for p = 0, 800 do
		if getLevelFromPoints(p) == targetLevel then
			return p
		end
	end
	return 0
end

-- Config
local FOOD_COUNT = 50        -- how many pellets on map at once
local FOOD_SIZE = 2          -- size of each pellet
local MAP_SIZE = 200         -- how big the map is
local POINTS_PER_FOOD = 1    -- points per pellet eaten
local POINTS_PER_PLAYER_EAT = 15
local PLAYER_EAT_RANGE = 6   -- studs between roots to consume
local RESPAWN_DELAY = 3      -- seconds before pellet respawns

-- Storage
local playerPoints = {}
local playerLevel = {} -- last synced level (for LevelUp detection)
local pendingEvolution: { [Player]: { choices: { { name: string, ability: string } }, expires: number } } = {}
local playerAnimal: { [Player]: string } = {}
-- Kill title progress: persists through death (handlePlayerDeath does not reset this).
local playerKills: { [Player]: number } = {}

local function addPickShield(player: Player)
	local character = player.Character
	if not character then
		return
	end
	if character:FindFirstChild(EVOLUTION_FF_NAME) then
		return
	end
	local ff = Instance.new("ForceField")
	ff.Name = EVOLUTION_FF_NAME
	ff.Parent = character
end

local function removePickShield(character: Model)
	local ff = character:FindFirstChild(EVOLUTION_FF_NAME)
	if ff then
		ff:Destroy()
	end
end

local function applyPacifistGlow(character: Model)
	local existing = character:FindFirstChild("EvolutionPacifistGlow")
	if existing then
		existing:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "EvolutionPacifistGlow"
	h.FillColor = Color3.fromRGB(255, 220, 50)
	h.OutlineColor = Color3.fromRGB(255, 200, 0)
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0.3
	h.Parent = character
	task.delay(3, function()
		if h.Parent then
			h:Destroy()
		end
	end)
end

-- Create food folder
local foodFolder = Instance.new("Folder")
foodFolder.Name = "Food"
foodFolder.Parent = workspace

-- Spawn a single food pellet at random position
local function spawnFood()
	local food = Instance.new("Part")
	food.Name = "FoodPellet"
	food.Shape = Enum.PartType.Ball
	food.Size = Vector3.new(FOOD_SIZE, FOOD_SIZE, FOOD_SIZE)
	food.Position = Vector3.new(
		math.random(-MAP_SIZE, MAP_SIZE),
		2,
		math.random(-MAP_SIZE, MAP_SIZE)
	)
	food.Anchored = true
	food.BrickColor = BrickColor.new("Bright green")
	food.Material = Enum.Material.Neon
	food.CanCollide = false
	food.Parent = foodFolder
	return food
end

-- Spawn all food on start
for i = 1, FOOD_COUNT do
	spawnFood()
end

local function handlePlayerDeath(player: Player, character: Model)
	if playerPoints[player] == nil then
		return
	end

	local currentLevel = getLevelFromPoints(playerPoints[player])
	local newLevel = math.max(1, currentLevel - 2)
	local newPoints = getMinPointsForLevel(newLevel)

	pendingEvolution[player] = nil
	removePickShield(character)

	playerPoints[player] = newPoints
	playerLevel[player] = newLevel

	pointsUpdate:FireClient(player, newPoints, newLevel)
	playerDied:FireClient(player, newLevel)
end

local function syncPointsAndLevel(player: Player)
	local points = playerPoints[player]
	if points == nil then
		return
	end
	local newLevel = getLevelFromPoints(points)
	pointsUpdate:FireClient(player, points, newLevel)
	local prev = playerLevel[player] or 1
	if newLevel > prev then
		playerLevel[player] = newLevel
		local choices = AnimalPools.sampleChoicesForLevel(newLevel)
		pendingEvolution[player] = {
			choices = choices,
			expires = tick() + 60,
		}
		addPickShield(player)
		levelUp:FireClient(player, newLevel, choices)
	else
		playerLevel[player] = newLevel
	end
end

-- Give points to player
local function addPoints(player, amount)
	if playerPoints[player] then
		playerPoints[player] = playerPoints[player] + amount
		print(player.Name .. " has " .. playerPoints[player] .. " points")
		syncPointsAndLevel(player)
	end
end

local function performEat(eater: Player, victim: Player)
	local charV = victim.Character
	if not charV then
		return
	end
	local humV = charV:FindFirstChildOfClass("Humanoid")
	if not humV or humV.Health <= 0 then
		return
	end

	local now = workspace:GetServerTimeNow()
	local pac = eater:GetAttribute("PacifistUntil")
	if typeof(pac) == "number" and now < pac then
		return
	end

	playerKills[eater] = (playerKills[eater] or 0) + 1
	addPoints(eater, POINTS_PER_PLAYER_EAT)
	playerEaten:FireClient(eater, "eater", victim.Name, POINTS_PER_PLAYER_EAT)
	playerEaten:FireClient(victim, "eaten", eater.Name)
	humV.Health = 0
end

local function tryConsumeOnePlayerPair()
	local list = Players:GetPlayers()
	for i = 1, #list do
		local pa = list[i]
		if playerPoints[pa] == nil then
			continue
		end
		local charA = pa.Character
		if not charA then
			continue
		end
		local humA = charA:FindFirstChildOfClass("Humanoid")
		local rootA = charA:FindFirstChild("HumanoidRootPart")
		if not humA or not rootA or not rootA:IsA("BasePart") or humA.Health <= 0 then
			continue
		end

		for j = i + 1, #list do
			local pb = list[j]
			if playerPoints[pb] == nil then
				continue
			end
			local charB = pb.Character
			if not charB then
				continue
			end
			local humB = charB:FindFirstChildOfClass("Humanoid")
			local rootB = charB:FindFirstChild("HumanoidRootPart")
			if not humB or not rootB or not rootB:IsA("BasePart") or humB.Health <= 0 then
				continue
			end

			local dist = (rootA :: BasePart).Position - (rootB :: BasePart).Position
			if dist.Magnitude >= PLAYER_EAT_RANGE then
				continue
			end

			local levelA = getLevelFromPoints(playerPoints[pa])
			local levelB = getLevelFromPoints(playerPoints[pb])
			if levelA > levelB then
				performEat(pa, pb)
				return
			elseif levelB > levelA then
				performEat(pb, pa)
				return
			end
		end
	end
end

-- Setup player when they join
local function onPlayerAdded(player)
	playerPoints[player] = 0
	playerLevel[player] = 1
	playerKills[player] = 0
	print(player.Name .. " joined. Points: 0")
	pointsUpdate:FireClient(player, 0, 1)

	-- When character spawns
	player.CharacterAdded:Connect(function(character)
		if pendingEvolution[player] then
			task.defer(function()
				addPickShield(player)
			end)
		end

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			handlePlayerDeath(player, character)
		end)

		local rootPart = character:WaitForChild("HumanoidRootPart")

		-- Check for food collision every frame
		RunService.Heartbeat:Connect(function()
			if not character or not character.Parent then return end

			for _, food in ipairs(foodFolder:GetChildren()) do
				if food:IsA("BasePart") then
					local distance = (rootPart.Position - food.Position).Magnitude
					if distance < 5 then
						-- Eat the food
						food:Destroy()
						addPoints(player, POINTS_PER_FOOD)

						-- Respawn food after delay
						task.delay(RESPAWN_DELAY, function()
							spawnFood()
						end)
					end
				end
			end
		end)
	end)
end

-- Cleanup when player leaves
local function onPlayerRemoving(player)
	playerPoints[player] = nil
	playerLevel[player] = nil
	pendingEvolution[player] = nil
	playerAnimal[player] = nil
	playerKills[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

RunService.Heartbeat:Connect(function()
	tryConsumeOnePlayerPair()
end)

animalPicked.OnServerEvent:Connect(function(player: Player, animalName: unknown)
	if typeof(animalName) ~= "string" then
		return
	end
	local pending = pendingEvolution[player]
	if not pending then
		return
	end
	if tick() > pending.expires then
		pendingEvolution[player] = nil
		return
	end
	if not AnimalPools.isNameInChoices(animalName :: string, pending.choices) then
		return
	end
	pendingEvolution[player] = nil

	local character = player.Character
	if character then
		removePickShield(character)
	end

	playerAnimal[player] = animalName :: string

	local now = workspace:GetServerTimeNow()
	player:SetAttribute("PacifistUntil", now + 3)

	if character then
		applyPacifistGlow(character)
	end
end)