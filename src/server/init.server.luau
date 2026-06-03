-- Evolve Game Server
-- Phase 1: Food spawning + points system + basic combat

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalPools = require(Shared:WaitForChild("AnimalPools"))

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUp = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
local animalPicked = ReplicatedStorage:WaitForChild("AnimalPicked") :: RemoteEvent
local playerDied = ReplicatedStorage:WaitForChild("PlayerDied") :: RemoteEvent
local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest") :: RemoteEvent
local playerKilled = ReplicatedStorage:WaitForChild("PlayerKilled") :: RemoteEvent

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
local POINTS_PER_KILL = 15
local RESPAWN_DELAY = 3      -- seconds before pellet respawns

local ATTACK_RANGE = 8
local ATTACK_HALF_ARC_DEG = 90 -- 180° total in front

local TIER_COMBAT: { [number]: { damage: number, cooldown: number } } = {
	[1] = { damage = 10, cooldown = 1.0 },
	[2] = { damage = 18, cooldown = 0.9 },
	[3] = { damage = 28, cooldown = 0.8 },
}

-- Storage
local playerPoints = {}
local playerLevel = {} -- last synced level (for LevelUp detection)
local pendingEvolution: { [Player]: { choices: { { name: string, ability: string } }, expires: number } } = {}
local playerAnimal: { [Player]: string } = {}
-- Kill title progress: persists through death (handlePlayerDeath does not reset this).
local playerKills: { [Player]: number } = {}
local playerLastAttack: { [Player]: number } = {}

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

local function flashCombatHit(character: Model)
	local existing = character:FindFirstChild("CombatHitFlash")
	if existing then
		existing:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "CombatHitFlash"
	h.FillColor = Color3.fromRGB(255, 40, 40)
	h.OutlineColor = Color3.fromRGB(180, 0, 0)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 0.2
	h.Parent = character
	task.delay(0.15, function()
		if h.Parent then
			h:Destroy()
		end
	end)
end

local function showFloatingDamage(root: BasePart, amount: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageNumber"
	bb.Size = UDim2.fromOffset(80, 40)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = root

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "-" .. tostring(math.floor(amount))
	tl.TextColor3 = Color3.fromRGB(255, 230, 120)
	tl.TextStrokeTransparency = 0.3
	tl.Font = Enum.Font.GothamBlack
	tl.TextSize = 28
	tl.Parent = bb

	task.delay(1.1, function()
		if bb.Parent then
			bb:Destroy()
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

local function getCombatStatsForPlayer(player: Player): (number, number)
	local level = getLevelFromPoints(playerPoints[player] or 0)
	local tier = AnimalPools.getTierForLevel(level)
	local row = TIER_COMBAT[tier] or TIER_COMBAT[3]
	return row.damage, row.cooldown
end

local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function isTargetInMeleeCone(attackerRoot: BasePart, targetPosition: Vector3): boolean
	local delta = targetPosition - attackerRoot.Position
	local dist = delta.Magnitude
	if dist > ATTACK_RANGE then
		return false
	end
	local forward = flatUnit(attackerRoot.CFrame.LookVector)
	if not forward then
		return false
	end
	local toTarget = flatUnit(delta)
	if not toTarget then
		return true
	end
	local dot = math.clamp(forward:Dot(toTarget), -1, 1)
	local ang = math.deg(math.acos(dot))
	return ang <= ATTACK_HALF_ARC_DEG
end

local function onPlayerKill(attacker: Player, victim: Player)
	playerKills[attacker] = (playerKills[attacker] or 0) + 1
	addPoints(attacker, POINTS_PER_KILL)
	playerKilled:FireClient(attacker, "killer", victim.Name, POINTS_PER_KILL)
	playerKilled:FireClient(victim, "victim", attacker.Name)
end

local function tryMeleeAttack(attacker: Player)
	if playerPoints[attacker] == nil then
		return
	end

	local charA = attacker.Character
	if not charA then
		return
	end
	local humA = charA:FindFirstChildOfClass("Humanoid")
	local rootA = charA:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humA or not rootA or humA.Health <= 0 then
		return
	end

	local now = workspace:GetServerTimeNow()
	local pac = attacker:GetAttribute("PacifistUntil")
	if typeof(pac) == "number" and now < pac then
		return
	end

	local damage, cooldown = getCombatStatsForPlayer(attacker)
	local last = playerLastAttack[attacker] or 0
	if tick() - last < cooldown then
		return
	end
	playerLastAttack[attacker] = tick()

	for _, other in Players:GetPlayers() do
		if other == attacker then
			continue
		end
		if playerPoints[other] == nil then
			continue
		end
		local charB = other.Character
		if not charB then
			continue
		end
		local humB = charB:FindFirstChildOfClass("Humanoid")
		local rootB = charB:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humB or not rootB or humB.Health <= 0 then
			continue
		end

		if not isTargetInMeleeCone(rootA, rootB.Position) then
			continue
		end

		local newHealth = humB.Health - damage
		flashCombatHit(charB)
		showFloatingDamage(rootB, damage)

		if newHealth <= 0 then
			onPlayerKill(attacker, other)
			humB.Health = 0
		else
			humB.Health = newHealth
		end
	end
end

-- Setup player when they join
local function onPlayerAdded(player)
	playerPoints[player] = 0
	playerLevel[player] = 1
	playerKills[player] = 0
	playerLastAttack[player] = 0
	print(player.Name .. " joined. Points: 0")
	pointsUpdate:FireClient(player, 0, 1)

	-- When character spawns
	player.CharacterAdded:Connect(function(character)
		if pendingEvolution[player] then
			task.defer(function()
				addPickShield(player)
			end)
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.FallDamageEnabled = false

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
	playerLastAttack[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

attackRequest.OnServerEvent:Connect(function(player: Player)
	tryMeleeAttack(player)
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
