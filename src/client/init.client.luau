local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUpRemote = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
local animalPicked = ReplicatedStorage:WaitForChild("AnimalPicked") :: RemoteEvent
local playerDied = ReplicatedStorage:WaitForChild("PlayerDied") :: RemoteEvent
local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest") :: RemoteEvent
local playerKilled = ReplicatedStorage:WaitForChild("PlayerKilled") :: RemoteEvent
local titleSync = ReplicatedStorage:WaitForChild("TitleSync") :: RemoteEvent
local titleUnlocked = ReplicatedStorage:WaitForChild("TitleUnlocked") :: RemoteEvent
local extinctionEvent = ReplicatedStorage:WaitForChild("ExtinctionEvent") :: RemoteEvent
local lastPredator = ReplicatedStorage:WaitForChild("LastPredator") :: RemoteEvent
local skinReceived = ReplicatedStorage:WaitForChild("SkinReceived") :: RemoteEvent
local skinInventorySync = ReplicatedStorage:WaitForChild("SkinInventorySync") :: RemoteEvent

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

local titleHudLabel = Instance.new("TextLabel")
titleHudLabel.Name = "TitleHud"
titleHudLabel.AnchorPoint = Vector2.new(1, 0)
titleHudLabel.Position = UDim2.new(1, -12, 0, 50)
titleHudLabel.Size = UDim2.fromOffset(300, 22)
titleHudLabel.BackgroundTransparency = 1
titleHudLabel.Font = Enum.Font.GothamMedium
titleHudLabel.Text = "Fresh Prey"
titleHudLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
titleHudLabel.TextSize = 16
titleHudLabel.TextXAlignment = Enum.TextXAlignment.Right
titleHudLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = label

-- Health bar (Humanoid health replicates locally)
local healthGui = Instance.new("ScreenGui")
healthGui.Name = "HealthHud"
healthGui.ResetOnSpawn = false
healthGui.DisplayOrder = 15
healthGui.Parent = playerGui

local hpBack = Instance.new("Frame")
hpBack.Name = "HpBack"
hpBack.AnchorPoint = Vector2.new(0.5, 1)
hpBack.Position = UDim2.new(0.5, 0, 1, -28)
hpBack.Size = UDim2.fromOffset(260, 24)
hpBack.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
hpBack.BackgroundTransparency = 0.2
hpBack.BorderSizePixel = 0
hpBack.Parent = healthGui

local hpBackCorner = Instance.new("UICorner")
hpBackCorner.CornerRadius = UDim.new(0, 8)
hpBackCorner.Parent = hpBack

local hpFill = Instance.new("Frame")
hpFill.Name = "HpFill"
hpFill.Size = UDim2.fromScale(1, 1)
hpFill.BackgroundColor3 = Color3.fromRGB(70, 210, 120)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBack

local hpFillCorner = Instance.new("UICorner")
hpFillCorner.CornerRadius = UDim.new(0, 8)
hpFillCorner.Parent = hpFill

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpText"
hpLabel.Size = UDim2.fromScale(1, 1)
hpLabel.BackgroundTransparency = 1
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 14
hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hpLabel.TextStrokeTransparency = 0.5
hpLabel.ZIndex = 2
hpLabel.Parent = hpBack

local function updateHealthBar(humanoid: Humanoid)
	local maxH = humanoid.MaxHealth
	local h = humanoid.Health
	local pct = if maxH > 0 then math.clamp(h / maxH, 0, 1) else 0
	hpFill.Size = UDim2.new(pct, 0, 1, 0)
	hpLabel.Text = string.format("%d / %d", math.floor(h + 0.5), math.floor(maxH + 0.5))
end

local function bindHumanoidHealth(humanoid: Humanoid)
	updateHealthBar(humanoid)
	humanoid.HealthChanged:Connect(function()
		updateHealthBar(humanoid)
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealthBar(humanoid)
	end)
end

local function onLocalCharacterAdded(character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	bindHumanoidHealth(hum)
end

if player.Character then
	task.defer(onLocalCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onLocalCharacterAdded)

-- --- Skins: catalog + chest popup + inventory UI ---
type SkinEntry = { name: string, rarity: string, level: number }
local skinCatalog: { SkinEntry } = {}

local function rarityColor(rarity: string): Color3
	if rarity == "Common" then
		return Color3.fromRGB(160, 160, 170)
	elseif rarity == "Rare" then
		return Color3.fromRGB(70, 140, 255)
	elseif rarity == "Epic" then
		return Color3.fromRGB(175, 85, 255)
	elseif rarity == "Legendary" then
		return Color3.fromRGB(255, 205, 90)
	end
	return Color3.fromRGB(180, 180, 190)
end

local skinScreenGui = Instance.new("ScreenGui")
skinScreenGui.Name = "SkinUi"
skinScreenGui.ResetOnSpawn = false
skinScreenGui.DisplayOrder = 35
skinScreenGui.IgnoreGuiInset = false
skinScreenGui.Parent = playerGui

local invOpen = false

local invPanel = Instance.new("Frame")
invPanel.Name = "SkinInventoryPanel"
invPanel.AnchorPoint = Vector2.new(0, 1)
invPanel.Position = UDim2.new(0, 12, 1, -54)
invPanel.Size = UDim2.fromOffset(360, 300)
invPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
invPanel.BackgroundTransparency = 0.12
invPanel.BorderSizePixel = 0
invPanel.Visible = false
invPanel.Parent = skinScreenGui

local invPanelCorner = Instance.new("UICorner")
invPanelCorner.CornerRadius = UDim.new(0, 10)
invPanelCorner.Parent = invPanel

local invTitle = Instance.new("TextLabel")
invTitle.Name = "Title"
invTitle.Size = UDim2.new(1, -16, 0, 28)
invTitle.Position = UDim2.new(0, 8, 0, 8)
invTitle.BackgroundTransparency = 1
invTitle.Font = Enum.Font.GothamBold
invTitle.TextSize = 18
invTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.Text = "Your skins"
invTitle.Parent = invPanel

local invScroll = Instance.new("ScrollingFrame")
invScroll.Name = "Scroll"
invScroll.Size = UDim2.new(1, -16, 1, -44)
invScroll.Position = UDim2.new(0, 8, 0, 36)
invScroll.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
invScroll.BackgroundTransparency = 0.35
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 6
invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.Parent = invPanel

local invScrollCorner = Instance.new("UICorner")
invScrollCorner.CornerRadius = UDim.new(0, 8)
invScrollCorner.Parent = invScroll

local invList = Instance.new("UIListLayout")
invList.Padding = UDim.new(0, 6)
invList.SortOrder = Enum.SortOrder.LayoutOrder
invList.Parent = invScroll

local invButton = Instance.new("TextButton")
invButton.Name = "SkinInventoryButton"
invButton.AnchorPoint = Vector2.new(0, 1)
invButton.Position = UDim2.new(0, 12, 1, -12)
invButton.Size = UDim2.fromOffset(120, 36)
invButton.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
invButton.TextColor3 = Color3.fromRGB(230, 230, 240)
invButton.Font = Enum.Font.GothamBold
invButton.TextSize = 16
invButton.Text = "Skins"
invButton.AutoButtonColor = true
invButton.Parent = skinScreenGui

local invBtnCorner = Instance.new("UICorner")
invBtnCorner.CornerRadius = UDim.new(0, 8)
invBtnCorner.Parent = invButton

local function clearSkinCells()
	for _, child in invScroll:GetChildren() do
		if child:IsA("Frame") and child.Name == "SkinCell" then
			child:Destroy()
		end
	end
end

local function rebuildSkinGrid()
	clearSkinCells()
	for _, row in skinCatalog do
		local cell = Instance.new("Frame")
		cell.Name = "SkinCell"
		cell.Size = UDim2.new(1, -8, 0, 44)
		cell.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
		cell.BorderSizePixel = 0
		cell.Parent = invScroll

		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 6)
		cc.Parent = cell

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -12, 0, 22)
		nameLbl.Position = UDim2.new(0, 8, 0, 4)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 14
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.TextColor3 = rarityColor(row.rarity)
		nameLbl.Text = row.name
		nameLbl.Parent = cell

		local metaLbl = Instance.new("TextLabel")
		metaLbl.Size = UDim2.new(1, -12, 0, 18)
		metaLbl.Position = UDim2.new(0, 8, 0, 24)
		metaLbl.BackgroundTransparency = 1
		metaLbl.Font = Enum.Font.GothamMedium
		metaLbl.TextSize = 12
		metaLbl.TextXAlignment = Enum.TextXAlignment.Left
		metaLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
		metaLbl.Text = string.format("%s  ·  Lv. %d", row.rarity, row.level)
		metaLbl.Parent = cell
	end
end

invButton.MouseButton1Click:Connect(function()
	invOpen = not invOpen
	invPanel.Visible = invOpen
end)

local function showSkinChestPopup(skinName: string, rarity: string, level: number, kind: string)
	local col = rarityColor(rarity)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkinChestPopup"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 220
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.Size = UDim2.fromOffset(520, 140)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local main = Instance.new("TextLabel")
	main.Size = UDim2.fromScale(1, 1)
	main.BackgroundTransparency = 1
	main.Font = Enum.Font.GothamBlack
	main.TextSize = 26
	main.TextWrapped = true
	main.TextColor3 = col
	main.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	main.TextStrokeTransparency = 0.45
	main.TextXAlignment = Enum.TextXAlignment.Center
	main.TextYAlignment = Enum.TextYAlignment.Center

	if kind == "level_up" then
		main.Text = string.format("Skin Leveled Up!\n%s → Level %d", skinName, level)
	elseif kind == "duplicate_max" then
		main.Text = string.format("Already max level\n%s (Level %d)", skinName, level)
	else
		main.Text = string.format("%s\n%s", skinName, rarity)
	end
	main.Parent = holder

	local tween = TweenService:Create(
		main,
		TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tween:Play()
end

skinReceived.OnClientEvent:Connect(function(skinName: unknown, rarity: unknown, level: unknown, kind: unknown)
	if typeof(skinName) ~= "string" or typeof(rarity) ~= "string" or typeof(level) ~= "number" then
		return
	end
	local k = if typeof(kind) == "string" then kind :: string else "new"
	showSkinChestPopup(skinName :: string, rarity :: string, level :: number, k)
end)

skinInventorySync.OnClientEvent:Connect(function(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local nextCat: { SkinEntry } = {}
	for _, row in ipairs(payload :: { any }) do
		if typeof(row) == "table" then
			local t = row :: { [string]: any }
			local n = t.name
			local r = t.rarity
			local lv = t.level
			if typeof(n) == "string" and typeof(r) == "string" and typeof(lv) == "number" then
				table.insert(nextCat, {
					name = n :: string,
					rarity = r :: string,
					level = lv :: number,
				})
			end
		end
	end
	table.sort(nextCat, function(a, b)
		return a.name < b.name
	end)
	skinCatalog = nextCat
	rebuildSkinGrid()
end)

pointsUpdate.OnClientEvent:Connect(function(points: number, level: number?)
	local lv = if level ~= nil then level else 1
	label.Text = string.format("Points: %d  ·  Lv. %d", points, lv)
end)

titleSync.OnClientEvent:Connect(function(title: unknown)
	if typeof(title) == "string" then
		titleHudLabel.Text = title :: string
	end
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

local function showTimedCombatMessage(text: string, textColor: Color3, duration: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatMessage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 220
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local msg = Instance.new("TextLabel")
	msg.Name = "CombatText"
	msg.AnchorPoint = Vector2.new(0.5, 0.35)
	msg.Position = UDim2.new(0.5, 0, 0.35, 0)
	msg.Size = UDim2.fromOffset(900, 80)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 36
	msg.TextColor3 = textColor
	msg.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	msg.TextStrokeTransparency = 0.45
	msg.TextTransparency = 0
	msg.Text = text
	msg.Parent = gui

	local tween = TweenService:Create(
		msg,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tween:Play()
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

playerKilled.OnClientEvent:Connect(function(role: unknown, otherName: unknown, pointsAwarded: unknown?)
	if role == "killer" and typeof(otherName) == "string" and typeof(pointsAwarded) == "number" then
		showTimedCombatMessage(
			string.format("You killed %s! +%d points", otherName :: string, pointsAwarded :: number),
			Color3.fromRGB(60, 220, 100),
			2
		)
	elseif role == "victim" and typeof(otherName) == "string" then
		showTimedCombatMessage(
			string.format("You were killed by %s!", otherName :: string),
			Color3.fromRGB(220, 45, 45),
			2
		)
	end
end)

local function showTitleUnlockedPopup(titleName: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TitleUnlockedPopup"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 320
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local msg = Instance.new("TextLabel")
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.fromOffset(920, 100)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 40
	msg.TextColor3 = Color3.fromRGB(255, 215, 100)
	msg.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	msg.TextStrokeTransparency = 0.35
	msg.Text = "Title Unlocked: " .. titleName
	msg.Parent = gui

	local tween = TweenService:Create(
		msg,
		TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tween:Play()
end

local function showExtinctionAnnounce(who: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtinctionAnnounce"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 400
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "RedFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
	flash.BackgroundTransparency = 0.65
	flash.BorderSizePixel = 0
	flash.Parent = gui

	TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	local msg = Instance.new("TextLabel")
	msg.AnchorPoint = Vector2.new(0.5, 0.45)
	msg.Position = UDim2.new(0.5, 0, 0.45, 0)
	msg.Size = UDim2.fromOffset(950, 120)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 34
	msg.TextWrapped = true
	msg.TextColor3 = Color3.fromRGB(255, 90, 90)
	msg.TextStrokeTransparency = 0.4
	msg.Text = string.format("%s is an Extinction Event — run.", who)
	msg.Parent = gui

	local tw = TweenService:Create(
		msg,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tw.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tw:Play()
end

local function showLastPredatorAnnounce(who: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LastPredatorAnnounce"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 410
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "GoldFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 210, 80)
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.Parent = gui

	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	local msg = Instance.new("TextLabel")
	msg.AnchorPoint = Vector2.new(0.5, 0.45)
	msg.Position = UDim2.new(0.5, 0, 0.45, 0)
	msg.Size = UDim2.fromOffset(950, 120)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 36
	msg.TextWrapped = true
	msg.TextColor3 = Color3.fromRGB(255, 220, 120)
	msg.TextStrokeTransparency = 0.35
	msg.Text = string.format("%s is The Last Predator", who)
	msg.Parent = gui

	local tw = TweenService:Create(
		msg,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tw.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tw:Play()
end

titleUnlocked.OnClientEvent:Connect(function(titleName: unknown)
	if typeof(titleName) == "string" then
		showTitleUnlockedPopup(titleName :: string)
	end
end)

extinctionEvent.OnClientEvent:Connect(function(who: unknown)
	if typeof(who) == "string" then
		showExtinctionAnnounce(who :: string)
	end
end)

lastPredator.OnClientEvent:Connect(function(who: unknown)
	if typeof(who) == "string" then
		showLastPredatorAnnounce(who :: string)
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		attackRequest:FireServer()
	end
end)
