-- Food spawning, spin animation, and global eat detection.

local FoodSystem = {}

local G: any = nil
local foodEatAccum = 0.0
local eatConn: RBXScriptConnection? = nil

local function foodNewPart(name: string, shape: Enum.PartType, size: Vector3, brickColor: BrickColor): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.BrickColor = brickColor
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function foodWeld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function attachFoodSpin(model: Model, basePivot: CFrame)
	model:PivotTo(basePivot)
	local spin = Instance.new("NumberValue")
	spin.Name = "SpinY"
	spin.Value = 0
	spin.Parent = model
	local tween = G.TweenService:Create(
		spin,
		TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Value = 360 }
	)
	local conn = spin:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent == nil then
			return
		end
		model:PivotTo(basePivot * CFrame.Angles(0, math.rad(spin.Value), 0))
	end)
	tween:Play()
	model.Destroying:Connect(function()
		conn:Disconnect()
		tween:Cancel()
	end)
end

local function buildFoodApple(): Model
	local model = Instance.new("Model")
	model.Name = "FoodApple"
	local sphere = foodNewPart("Apple", Enum.PartType.Ball, Vector3.new(2.5, 2.5, 2.5), BrickColor.new("Bright red"))
	sphere.Material = Enum.Material.Neon
	local stem = foodNewPart("Stem", Enum.PartType.Cylinder, Vector3.new(0.3, 0.8, 0.3), BrickColor.new("Reddish brown"))
	stem.CFrame = sphere.CFrame * CFrame.new(0, 1.25 + 0.4, 0)
	sphere.Parent = model
	stem.Parent = model
	model.PrimaryPart = sphere
	foodWeld(sphere, stem)
	model:SetAttribute("FoodPickup", true)
	return model
end

local function buildFoodBanana(): Model
	local model = Instance.new("Model")
	model.Name = "FoodBanana"
	local body = foodNewPart("Banana", Enum.PartType.Cylinder, Vector3.new(1, 2.5, 1), BrickColor.new("Bright yellow"))
	body.Material = Enum.Material.Neon
	body.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(30), 0, 0)
	local tip = foodNewPart("BananaTip", Enum.PartType.Block, Vector3.new(0.4, 0.4, 0.4), BrickColor.new("Reddish brown"))
	tip.CFrame = body.CFrame * CFrame.new(0, -1.25 - 0.2, 0)
	body.Parent = model
	tip.Parent = model
	model.PrimaryPart = body
	foodWeld(body, tip)
	model:SetAttribute("FoodPickup", true)
	return model
end

local function buildFoodMeat(): Model
	local model = Instance.new("Model")
	model.Name = "FoodMeat"
	local meat = foodNewPart("Meat", Enum.PartType.Block, Vector3.new(2.5, 1.5, 2.5), BrickColor.new("Bright red"))
	meat.Material = Enum.Material.Neon
	local stripe1 = foodNewPart("Stripe1", Enum.PartType.Block, Vector3.new(2.6, 0.3, 0.6), BrickColor.new("White"))
	local stripe2 = foodNewPart("Stripe2", Enum.PartType.Block, Vector3.new(2.6, 0.3, 0.6), BrickColor.new("White"))
	stripe1.CFrame = meat.CFrame * CFrame.new(0, 0.75 + 0.15, 0.4)
	stripe2.CFrame = meat.CFrame * CFrame.new(0, 0.75 + 0.15, -0.4)
	meat.Parent = model
	stripe1.Parent = model
	stripe2.Parent = model
	model.PrimaryPart = meat
	foodWeld(meat, stripe1)
	foodWeld(meat, stripe2)
	model:SetAttribute("FoodPickup", true)
	return model
end

local function buildFoodMushroom(): Model
	local model = Instance.new("Model")
	model.Name = "FoodMushroom"
	local stem = foodNewPart("Stem", Enum.PartType.Cylinder, Vector3.new(1, 1.5, 1), BrickColor.new("White"))
	stem.Material = Enum.Material.Neon
	local cap = foodNewPart("Cap", Enum.PartType.Cylinder, Vector3.new(3, 0.8, 3), BrickColor.new("Reddish brown"))
	cap.CFrame = stem.CFrame * CFrame.new(0, 0.75 + 0.4, 0)
	stem.Parent = model
	cap.Parent = model
	model.PrimaryPart = stem
	foodWeld(stem, cap)
	model:SetAttribute("FoodPickup", true)
	return model
end

local function buildFoodBerry(): Model
	local model = Instance.new("Model")
	model.Name = "FoodBerry"
	local berry = foodNewPart("Berry", Enum.PartType.Ball, Vector3.new(2, 2, 2), BrickColor.new("Bright violet"))
	berry.Material = Enum.Material.Neon
	local leaf = foodNewPart("Leaf", Enum.PartType.Block, Vector3.new(0.8, 0.3, 0.8), BrickColor.new("Bright green"))
	leaf.CFrame = berry.CFrame * CFrame.new(0, 1 + 0.15, 0)
	berry.Parent = model
	leaf.Parent = model
	model.PrimaryPart = berry
	foodWeld(berry, leaf)
	model:SetAttribute("FoodPickup", true)
	return model
end

function FoodSystem.spawnFoodPellet()
	if not G or not G.foodFolder then
		return
	end
	local foodFolder = G.foodFolder :: Folder
	if #foodFolder:GetChildren() >= G.FOOD_MAX_COUNT then
		return
	end
	local spawnPos = Vector3.new(
		math.random(-G.FOOD_SPAWN_RANGE, G.FOOD_SPAWN_RANGE),
		G.FOOD_SPAWN_Y,
		math.random(-G.FOOD_SPAWN_RANGE, G.FOOD_SPAWN_RANGE)
	)
	local kind = math.random(1, 5)
	local model: Model
	if kind == 1 then
		model = buildFoodApple()
	elseif kind == 2 then
		model = buildFoodBanana()
	elseif kind == 3 then
		model = buildFoodMeat()
	elseif kind == 4 then
		model = buildFoodMushroom()
	else
		model = buildFoodBerry()
	end
	model.Parent = foodFolder
	model:PivotTo(CFrame.new(spawnPos))
	local basePivot = model:GetPivot()
	attachFoodSpin(model, basePivot)
end

function FoodSystem.mount(game: any)
	if _G.__EvolveFoodSystemAt ~= nil then
		warn("[FoodSystem] Duplicate mount blocked (already active since os.clock=", _G.__EvolveFoodSystemAt, ")")
		return
	end
	_G.__EvolveFoodSystemAt = os.clock()
	G = game

	local FOOD_FOLDER_NAME = "Food"
	local foodFolder = workspace:FindFirstChild(FOOD_FOLDER_NAME)
	if not foodFolder then
		foodFolder = Instance.new("Folder")
		foodFolder.Name = FOOD_FOLDER_NAME
		foodFolder.Parent = workspace
	end
	if not foodFolder:IsA("Folder") then
		error("[Food] Workspace." .. FOOD_FOLDER_NAME .. " must be a Folder")
	end
	game.foodFolder = foodFolder :: Folder
	G.foodFolder = game.foodFolder

	for _ = 1, G.FOOD_INITIAL_SPAWN_COUNT do
		FoodSystem.spawnFoodPellet()
	end

	task.spawn(function()
		while true do
			FoodSystem.spawnFoodPellet()
			task.wait(G.FOOD_SPAWN_INTERVAL_SEC)
		end
	end)

	print(
		"[Server] Food folder: "
			.. foodFolder:GetFullName()
			.. " ("
			.. tostring(#foodFolder:GetChildren())
			.. " food items after initial spawn)"
	)

	eatConn = G.RunService.Heartbeat:Connect(function(dt: number)
		foodEatAccum += dt
		while foodEatAccum >= 0.1 do
			foodEatAccum -= 0.1
			local foodsFolder = workspace:FindFirstChild("Food")
			if not foodsFolder or not foodsFolder:IsA("Folder") then
				continue
			end
			for _, player in ipairs(G.Players:GetPlayers()) do
				local char = player.Character
				local rootPart = char and char:FindFirstChild("HumanoidRootPart")
				if not rootPart or not rootPart:IsA("BasePart") then
					continue
				end
				local root = rootPart :: BasePart
				for _, food in ipairs(foodsFolder:GetChildren()) do
					if food:IsA("Model") and food:GetAttribute("FoodPickup") == true and food.Parent ~= nil then
						local primary = food.PrimaryPart
						if not primary then
							continue
						end
						local distance = (root.Position - primary.Position).Magnitude
						if distance < 5 then
							food:Destroy()
							if G.playerPoints[player] ~= nil then
								G.addPoints(player, G.POINTS_PER_FOOD)
								local total = G.playerPoints[player] :: number
								local lv = G.getLevelFromPoints(total)
								G.pointsUpdate:FireClient(player, total, lv)
								print("Player ate food, points: " .. tostring(total))
								task.delay(G.FOOD_REPLENISH_AFTER_EAT_SEC, FoodSystem.spawnFoodPellet)
							end
						end
					end
				end
			end
		end
	end)

	G.spawnFoodPellet = FoodSystem.spawnFoodPellet
end

return FoodSystem
