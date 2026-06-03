-- Evolve Game Server
-- Phase 1: Food spawning + points system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent

-- Config
local FOOD_COUNT = 50        -- how many pellets on map at once
local FOOD_SIZE = 2          -- size of each pellet
local MAP_SIZE = 200         -- how big the map is
local POINTS_PER_FOOD = 1    -- points per pellet eaten
local RESPAWN_DELAY = 3      -- seconds before pellet respawns

-- Storage
local playerPoints = {}

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

-- Give points to player
local function addPoints(player, amount)
	if playerPoints[player] then
		playerPoints[player] = playerPoints[player] + amount
		print(player.Name .. " has " .. playerPoints[player] .. " points")
		pointsUpdate:FireClient(player, playerPoints[player])
	end
end

-- Setup player when they join
local function onPlayerAdded(player)
	playerPoints[player] = 0
	print(player.Name .. " joined. Points: 0")
	pointsUpdate:FireClient(player, 0)

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
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)