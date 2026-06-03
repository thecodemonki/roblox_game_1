-- Evolve Game Server
-- Phase 1: Food spawning + points system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUp = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent

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

-- Config
local FOOD_COUNT = 50        -- how many pellets on map at once
local FOOD_SIZE = 2          -- size of each pellet
local MAP_SIZE = 200         -- how big the map is
local POINTS_PER_FOOD = 1    -- points per pellet eaten
local RESPAWN_DELAY = 3      -- seconds before pellet respawns

-- Storage
local playerPoints = {}
local playerLevel = {} -- last synced level (for LevelUp detection)

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
		levelUp:FireClient(player, newLevel)
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

-- Setup player when they join
local function onPlayerAdded(player)
	playerPoints[player] = 0
	playerLevel[player] = 1
	print(player.Name .. " joined. Points: 0")
	pointsUpdate:FireClient(player, 0, 1)

	-- When character spawns
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
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
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)