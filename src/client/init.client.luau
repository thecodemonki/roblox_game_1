local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUpRemote = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
local animalPicked = ReplicatedStorage:WaitForChild("AnimalPicked") :: RemoteEvent
local playerDied = ReplicatedStorage:WaitForChild("PlayerDied") :: RemoteEvent

local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PointsHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "PointsLabel"
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -12, 0, 12)
label.Size = UDim2.fromOffset(300, 36)
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BackgroundTransparency = 0.45
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.Text = "Points: 0  ·  Lv. 1"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 20
label.TextXAlignment = Enum.TextXAlignment.Right
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = label

pointsUpdate.OnClientEvent:Connect(function(points: number, level: number?)
	local lv = if level ~= nil then level else 1
	label.Text = string.format("Points: %d  ·  Lv. %d", points, lv)
end)

type AnimalChoice = { name: string, ability: string }

local activeLevelPopupTween: Tween? = nil
local activeLevelPopup: Instance? = nil

local pickBlur: BlurEffect? = nil
local pickBlurCameraConn: RBXScriptConnection? = nil

local function clearPickBlur()
	if pickBlurCameraConn then
		pickBlurCameraConn:Disconnect()
		pickBlurCameraConn = nil
	end
	if pickBlur then
		pickBlur:Destroy()
		pickBlur = nil
	end
end

local function mountPickBlur()
	if pickBlur then
		pickBlur:Destroy()
		pickBlur = nil
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local b = Instance.new("BlurEffect")
	b.Size = 24
	b.Parent = cam
	pickBlur = b
end

local function attachPickBlur()
	clearPickBlur()
	mountPickBlur()
	pickBlurCameraConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		mountPickBlur()
	end)
end

local function showLegacyLevelToast(newLevel: number)
	if activeLevelPopupTween then
		activeLevelPopupTween:Cancel()
	end
	if activeLevelPopup then
		activeLevelPopup:Destroy()
		activeLevelPopup = nil
	end

	local popupGui = Instance.new("ScreenGui")
	popupGui.Name = "LevelUpPopup"
	popupGui.ResetOnSpawn = false
	popupGui.DisplayOrder = 100
	popupGui.IgnoreGuiInset = true
	popupGui.Parent = playerGui

	local backdrop = Instance.new("TextLabel")
	backdrop.Name = "LevelUpText"
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.new(0.5, 0, 0.5, 0)
	backdrop.Size = UDim2.fromOffset(700, 120)
	backdrop.BackgroundTransparency = 1
	backdrop.Text = string.format("LEVEL UP! Level %d", newLevel)
	backdrop.Font = Enum.Font.GothamBlack
	backdrop.TextSize = 56
	backdrop.TextColor3 = Color3.fromRGB(255, 220, 80)
	backdrop.TextStrokeTransparency = 0.4
	backdrop.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.TextTransparency = 0
	backdrop.Parent = popupGui

	activeLevelPopup = popupGui

	local tween = TweenService:Create(
		backdrop,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	activeLevelPopupTween = tween

	tween.Completed:Connect(function()
		if popupGui.Parent then
			popupGui:Destroy()
		end
		if activeLevelPopup == popupGui then
			activeLevelPopup = nil
		end
		activeLevelPopupTween = nil
	end)

	tween:Play()
end

local function isChoicesArray(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local t = value :: { unknown }
	if #t < 3 then
		return false
	end
	for i = 1, 3 do
		local row = t[i]
		if typeof(row) ~= "table" then
			return false
		end
		local r = row :: { [string]: unknown }
		if typeof(r.name) ~= "string" or typeof(r.ability) ~= "string" then
			return false
		end
	end
	return true
end

local function showEvolutionPick(newLevel: number, choices: { AnimalChoice })
	attachPickBlur()

	local pickGui = Instance.new("ScreenGui")
	pickGui.Name = "EvolutionPick"
	pickGui.ResetOnSpawn = false
	pickGui.DisplayOrder = 200
	pickGui.IgnoreGuiInset = true
	pickGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pickGui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.Position = UDim2.fromScale(0, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = pickGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.Parent = dim

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -48, 0, 56)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.TextStrokeTransparency = 0.5
	title.Text = string.format("Level %d — Choose your animal", newLevel)
	title.Parent = dim

	local cardsRow = Instance.new("Frame")
	cardsRow.Name = "CardsRow"
	cardsRow.Size = UDim2.new(1, -48, 0, 280)
	cardsRow.BackgroundTransparency = 1
	cardsRow.Parent = dim

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 16)
	rowLayout.Parent = cardsRow

	local picked = false
	local cardButtons: { TextButton } = {}

	local function closePickUi()
		clearPickBlur()
		if pickGui.Parent then
			pickGui:Destroy()
		end
	end

	for i = 1, 3 do
		local animal = choices[i]
		local card = Instance.new("TextButton")
		card.Name = "Card_" .. animal.name
		card.Size = UDim2.new(0, 220, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0
		card.AutoButtonColor = true
		card.Font = Enum.Font.GothamBold
		card.TextSize = 18
		card.TextColor3 = Color3.fromRGB(255, 255, 255)
		card.TextWrapped = true
		card.TextXAlignment = Enum.TextXAlignment.Center
		card.TextYAlignment = Enum.TextYAlignment.Center
		card.Text = string.format("%s\n\n%s", animal.name, animal.ability)
		card.Parent = cardsRow

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardPad = Instance.new("UIPadding")
		cardPad.PaddingTop = UDim.new(0, 12)
		cardPad.PaddingBottom = UDim.new(0, 12)
		cardPad.PaddingLeft = UDim.new(0, 10)
		cardPad.PaddingRight = UDim.new(0, 10)
		cardPad.Parent = card

		table.insert(cardButtons, card)

		card.MouseButton1Click:Connect(function()
			if picked then
				return
			end
			picked = true
			animalPicked:FireServer(animal.name)

			for _, other in cardButtons do
				if other ~= card then
					TweenService:Create(
						other,
						TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 1, TextTransparency = 1 }
					):Play()
				end
			end

			task.delay(0.4, closePickUi)
		end)
	end
end

levelUpRemote.OnClientEvent:Connect(function(newLevel: number, choices: unknown?)
	if typeof(newLevel) ~= "number" then
		return
	end
	if choices ~= nil and isChoicesArray(choices) then
		showEvolutionPick(newLevel, choices :: { AnimalChoice })
	else
		showLegacyLevelToast(newLevel)
	end
end)

playerDied.OnClientEvent:Connect(function(_newLevel: number)
	local evo = playerGui:FindFirstChild("EvolutionPick")
	if evo then
		evo:Destroy()
	end
	clearPickBlur()

	local deathGui = Instance.new("ScreenGui")
	deathGui.Name = "DeathScreen"
	deathGui.ResetOnSpawn = false
	deathGui.DisplayOrder = 250
	deathGui.IgnoreGuiInset = true
	deathGui.Parent = playerGui

	local msg = Instance.new("TextLabel")
	msg.Name = "DeathMessage"
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.fromOffset(900, 100)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 48
	msg.TextColor3 = Color3.fromRGB(220, 40, 40)
	msg.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	msg.TextStrokeTransparency = 0.4
	msg.TextTransparency = 0
	msg.Text = "YOU DIED - Lost 2 Levels"
	msg.Parent = deathGui

	local tween = TweenService:Create(
		msg,
		TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if deathGui.Parent then
			deathGui:Destroy()
		end
	end)
	tween:Play()
end)
