-- Client UI: HUD, menus, minimap, shop, evolution pick, combat toasts.
-- Loaded by init.client.luau to stay under LocalScript local register limits.

export type Deps = {
	player: Player,
	playerGui: PlayerGui,
	Players: Players,
	TweenService: TweenService,
	UserInputService: UserInputService,
	Workspace: Workspace,
	CollectionService: CollectionService,
	RunService: RunService,
	SoundManager: { playSound: (string) -> (), startAmbientLoop: () -> () },
	pointsUpdate: RemoteEvent,
	levelUpRemote: RemoteEvent,
	animalPicked: RemoteEvent,
	animalChanged: RemoteEvent,
	playerDied: RemoteEvent,
	attackRequest: RemoteEvent,
	playerKilled: RemoteEvent,
	titleSync: RemoteEvent,
	titleUnlocked: RemoteEvent,
	extinctionEvent: RemoteEvent,
	lastPredator: RemoteEvent,
	skinReceived: RemoteEvent,
	skinInventorySync: RemoteEvent,
	coinsUpdated: RemoteEvent,
	purchaseChest: RemoteFunction,
	survivalBonus: RemoteEvent,
	survivalStreakSync: RemoteEvent,
	roundEnd: RemoteEvent,
	voidBeastUnlocked: RemoteEvent,
	rankedTimerSync: RemoteEvent,
	playerStartedGame: RemoteEvent,
	getPlayerStatsRemote: RemoteFunction,
	getLeaderboardRemote: RemoteFunction,
	useAbility: RemoteEvent,
	abilityFeedback: RemoteEvent,
	menuState: { mainMenuShown: boolean },
}

local MenuManager = require(script.Parent:WaitForChild("MenuManager"))

local UIManager = {}

function UIManager.start(deps: Deps)
	local player = deps.player
	local playerGui = deps.playerGui
	local Players = deps.Players
	local TweenService = deps.TweenService
	local UserInputService = deps.UserInputService
	local Workspace = deps.Workspace
	local CollectionService = deps.CollectionService
	local RunService = deps.RunService
	local SoundManager = deps.SoundManager
	local pointsUpdate = deps.pointsUpdate
	local levelUpRemote = deps.levelUpRemote
	local animalPicked = deps.animalPicked
	local animalChanged = deps.animalChanged
	local playerDied = deps.playerDied
	local attackRequest = deps.attackRequest
	local playerKilled = deps.playerKilled
	local titleSync = deps.titleSync
	local titleUnlocked = deps.titleUnlocked
	local extinctionEvent = deps.extinctionEvent
	local lastPredator = deps.lastPredator
	local skinReceived = deps.skinReceived
	local skinInventorySync = deps.skinInventorySync
	local coinsUpdated = deps.coinsUpdated
	local purchaseChest = deps.purchaseChest
	local survivalBonus = deps.survivalBonus
	local survivalStreakSync = deps.survivalStreakSync
	local roundEnd = deps.roundEnd
	local voidBeastUnlocked = deps.voidBeastUnlocked
	local rankedTimerSync = deps.rankedTimerSync
	local playerStartedGame = deps.playerStartedGame
	local getPlayerStatsRemote = deps.getPlayerStatsRemote
	local getLeaderboardRemote = deps.getLeaderboardRemote
	local useAbility = deps.useAbility
	local abilityFeedback = deps.abilityFeedback
	local menuState = deps.menuState
	local function isMenuBlocking(): boolean
		return menuState.mainMenuShown
	end

local ABILITY_NAME_BY_ANIMAL: { [string]: string } = {
	["Noob Chicken"] = "Cluck",
	["Rat"] = "Scurry",
	["Fox"] = "Dash",
	["Cobra"] = "Venom Spit",
	["Wolf"] = "Howl",
	["Gorilla"] = "Rock Throw",
	["T-Rex"] = "Stomp",
}

local currentAnimalForAbility = "Noob Chicken"
local abilityCooldownEnd = 0.0
local abilityCooldownTotal = 15.0

local abilityHudGui = Instance.new("ScreenGui")
abilityHudGui.Name = "AbilityHud"
abilityHudGui.ResetOnSpawn = false
abilityHudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
abilityHudGui.DisplayOrder = 25
abilityHudGui.Parent = playerGui

local abilityHudRoot = Instance.new("Frame")
abilityHudRoot.Name = "Root"
abilityHudRoot.AnchorPoint = Vector2.new(0.5, 1)
abilityHudRoot.Position = UDim2.new(0.5, 0, 1, -24)
abilityHudRoot.Size = UDim2.fromOffset(280, 72)
abilityHudRoot.BackgroundTransparency = 1
abilityHudRoot.Parent = abilityHudGui

local abilityNameLabel = Instance.new("TextLabel")
abilityNameLabel.Name = "AbilityName"
abilityNameLabel.Size = UDim2.new(1, 0, 0, 18)
abilityNameLabel.Position = UDim2.new(0, 0, 0, 0)
abilityNameLabel.BackgroundTransparency = 1
abilityNameLabel.Font = Enum.Font.GothamBold
abilityNameLabel.TextSize = 14
abilityNameLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
abilityNameLabel.Text = "Ability"
abilityNameLabel.Parent = abilityHudRoot

local abilityBarBg = Instance.new("Frame")
abilityBarBg.Name = "CooldownBarBg"
abilityBarBg.Size = UDim2.new(1, 0, 0, 14)
abilityBarBg.Position = UDim2.new(0, 0, 0, 22)
abilityBarBg.BackgroundColor3 = Color3.fromRGB(55, 58, 72)
abilityBarBg.BorderSizePixel = 0
abilityBarBg.Parent = abilityHudRoot

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = abilityBarBg

local abilityBarFill = Instance.new("Frame")
abilityBarFill.Name = "Fill"
abilityBarFill.Size = UDim2.new(1, 0, 1, 0)
abilityBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
abilityBarFill.BorderSizePixel = 0
abilityBarFill.Parent = abilityBarBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = abilityBarFill

local abilityMobileBtn = Instance.new("TextButton")
abilityMobileBtn.Name = "AbilityMobileButton"
abilityMobileBtn.AnchorPoint = Vector2.new(0.5, 1)
abilityMobileBtn.Position = UDim2.new(0.5, 0, 1, -100)
abilityMobileBtn.Size = UDim2.fromOffset(56, 56)
abilityMobileBtn.BackgroundColor3 = Color3.fromRGB(48, 52, 70)
abilityMobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
abilityMobileBtn.Font = Enum.Font.GothamBold
abilityMobileBtn.TextSize = 11
abilityMobileBtn.Text = "Q"
abilityMobileBtn.AutoButtonColor = true
abilityMobileBtn.Visible = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
abilityMobileBtn.Parent = abilityHudGui

local mobCorner = Instance.new("UICorner")
mobCorner.CornerRadius = UDim.new(1, 0)
mobCorner.Parent = abilityMobileBtn

local function refreshAbilityHudTitle()
	local n = ABILITY_NAME_BY_ANIMAL[currentAnimalForAbility]
	abilityNameLabel.Text = if n then n else "Ability"
	if abilityMobileBtn.Visible then
		abilityMobileBtn.Text = if n then string.sub(n, 1, 6) else "Q"
	end
end

local abilityPopup = Instance.new("TextLabel")
abilityPopup.Name = "AbilityPopup"
abilityPopup.AnchorPoint = Vector2.new(0.5, 0.5)
abilityPopup.Position = UDim2.new(0.5, 0, 0.42, 0)
abilityPopup.Size = UDim2.fromOffset(400, 48)
abilityPopup.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
abilityPopup.BackgroundTransparency = 0.2
abilityPopup.Font = Enum.Font.GothamBlack
abilityPopup.TextSize = 22
abilityPopup.TextColor3 = Color3.fromRGB(255, 220, 120)
abilityPopup.Text = ""
abilityPopup.Visible = false
abilityPopup.ZIndex = 10
abilityPopup.Parent = abilityHudGui

local popStroke = Instance.new("UIStroke")
popStroke.Thickness = 2
popStroke.Color = Color3.fromRGB(200, 160, 80)
popStroke.Parent = abilityPopup

local popCorner = Instance.new("UICorner")
popCorner.CornerRadius = UDim.new(0, 10)
popCorner.Parent = abilityPopup

local function showAbilityPopup(text: string)
	abilityPopup.Text = text
	abilityPopup.Visible = true
	task.delay(1.1, function()
		abilityPopup.Visible = false
	end)
end

RunService.RenderStepped:Connect(function()
	local now = tick()
	local ready = now >= abilityCooldownEnd
	if ready then
		abilityBarFill.Size = UDim2.new(1, 0, 1, 0)
		abilityBarBg.BackgroundColor3 = Color3.fromRGB(55, 58, 72)
		abilityBarFill.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
	else
		local rem = abilityCooldownEnd - now
		local p = if abilityCooldownTotal > 0 then math.clamp(1 - rem / abilityCooldownTotal, 0, 1) else 1
		abilityBarFill.Size = UDim2.new(p, 0, 1, 0)
		abilityBarBg.BackgroundColor3 = Color3.fromRGB(42, 44, 54)
		abilityBarFill.BackgroundColor3 = Color3.fromRGB(100, 105, 120)
	end
end)

abilityFeedback.OnClientEvent:Connect(function(ok: unknown, abilityName: unknown, cooldownTotal: unknown, remainingFail: unknown)
	local okB = ok == true
	local nameStr = if typeof(abilityName) == "string" then abilityName :: string else ""
	local cdNum = if typeof(cooldownTotal) == "number" then cooldownTotal :: number else 15
	local remNum = if typeof(remainingFail) == "number" then remainingFail :: number else 0
	if okB and nameStr ~= "" then
		abilityCooldownTotal = cdNum
		abilityCooldownEnd = tick() + cdNum
		showAbilityPopup(nameStr)
	elseif remNum > 0 then
		abilityCooldownTotal = cdNum
		abilityCooldownEnd = tick() + remNum
	elseif nameStr == "No ability" then
		showAbilityPopup("No ability")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if isMenuBlocking() then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		useAbility:FireServer()
	end
end)

abilityMobileBtn.MouseButton1Click:Connect(function()
	if isMenuBlocking() then
		return
	end
	useAbility:FireServer()
end)

refreshAbilityHudTitle()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PointsHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local topHudRow = Instance.new("Frame")
topHudRow.Name = "TopHudRow"
topHudRow.AnchorPoint = Vector2.new(1, 0)
topHudRow.Position = UDim2.new(1, -12, 0, 12)
topHudRow.Size = UDim2.fromOffset(460, 36)
topHudRow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
topHudRow.BackgroundTransparency = 0.45
topHudRow.BorderSizePixel = 0
topHudRow.Parent = screenGui

local topHudLayout = Instance.new("UIListLayout")
topHudLayout.FillDirection = Enum.FillDirection.Horizontal
topHudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
topHudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topHudLayout.Padding = UDim.new(0, 10)
topHudLayout.SortOrder = Enum.SortOrder.LayoutOrder
topHudLayout.Parent = topHudRow

local label = Instance.new("TextLabel")
label.Name = "PointsLabel"
label.Size = UDim2.new(0, 260, 1, 0)
label.BackgroundTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.Text = "Points: 0  ·  Lv. 1"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 20
label.TextXAlignment = Enum.TextXAlignment.Right
label.LayoutOrder = 1
label.Parent = topHudRow

local coinIcon = Instance.new("Frame")
coinIcon.Name = "CoinIcon"
coinIcon.Size = UDim2.fromOffset(18, 18)
coinIcon.BackgroundColor3 = Color3.fromRGB(255, 215, 60)
coinIcon.BorderSizePixel = 0
coinIcon.LayoutOrder = 2
coinIcon.Parent = topHudRow

local coinIconRound = Instance.new("UICorner")
coinIconRound.CornerRadius = UDim.new(1, 0)
coinIconRound.Parent = coinIcon

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(0, 72, 1, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.Text = "0"
coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
coinsLabel.TextSize = 20
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.LayoutOrder = 3
coinsLabel.Parent = topHudRow

local currentCoins = 0

local function setHudPointsLine(points: number, level: number)
	label.Text = string.format("Points: %d  ·  Lv. %d", points, level)
end

local function setHudCoins(coins: number)
	currentCoins = coins
	coinsLabel.Text = tostring(coins)
end

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
corner.Parent = topHudRow

local padding = Instance.new("UIPadding")
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = topHudRow

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

local rankedGui = Instance.new("ScreenGui")
rankedGui.Name = "RankedHud"
rankedGui.ResetOnSpawn = false
rankedGui.DisplayOrder = 18
rankedGui.IgnoreGuiInset = false
rankedGui.Parent = playerGui

local rankedTimerLabel = Instance.new("TextLabel")
rankedTimerLabel.Name = "RankedCountdown"
rankedTimerLabel.AnchorPoint = Vector2.new(0, 0)
rankedTimerLabel.Position = UDim2.new(0, 12, 0, 10)
rankedTimerLabel.Size = UDim2.fromOffset(200, 28)
rankedTimerLabel.BackgroundTransparency = 1
rankedTimerLabel.Font = Enum.Font.GothamBlack
rankedTimerLabel.TextSize = 20
rankedTimerLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
rankedTimerLabel.TextXAlignment = Enum.TextXAlignment.Left
rankedTimerLabel.Text = "Ranked: 15:00"
rankedTimerLabel.Parent = rankedGui

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
	hum.Died:Connect(function()
		SoundManager.playSound("death")
	end)
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
local menuRefreshStats: (() -> ())? = nil

local invPanel = Instance.new("Frame")
invPanel.Name = "SkinInventoryPanel"
invPanel.AnchorPoint = Vector2.new(0, 1)
invPanel.Position = UDim2.new(0, 12, 1, -100)
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

local survivalStreakLabel = Instance.new("TextLabel")
survivalStreakLabel.Name = "SurvivalStreakHud"
survivalStreakLabel.AnchorPoint = Vector2.new(0, 1)
survivalStreakLabel.Position = UDim2.new(0, 12, 1, -52)
survivalStreakLabel.Size = UDim2.fromOffset(220, 22)
survivalStreakLabel.BackgroundTransparency = 1
survivalStreakLabel.Font = Enum.Font.GothamBold
survivalStreakLabel.TextSize = 15
survivalStreakLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
survivalStreakLabel.TextXAlignment = Enum.TextXAlignment.Left
survivalStreakLabel.Text = "Alive: 0m 0s"
survivalStreakLabel.Parent = skinScreenGui

local function formatAliveTime(totalSec: number): string
	local m = math.floor(totalSec / 60)
	local s = math.floor(totalSec % 60)
	return string.format("Alive: %dm %ds", m, s)
end

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
	if invOpen and menuState.mainMenuShown then
		skinScreenGui.DisplayOrder = 130
	elseif not invOpen then
		skinScreenGui.DisplayOrder = 35
	end
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
	if not suppressSkinChestSfx then
		SoundManager.playSound("chestOpen")
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
	if menuRefreshStats and menuState.mainMenuShown then
		menuRefreshStats()
	end
end)

survivalStreakSync.OnClientEvent:Connect(function(sec: unknown)
	if typeof(sec) ~= "number" then
		return
	end
	local n = math.max(0, math.floor(sec :: number))
	survivalStreakLabel.Text = formatAliveTime(n)
end)

local function showSurvivalBonusPopup(message: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivalBonusToast"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 230
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local tl = Instance.new("TextLabel")
	tl.AnchorPoint = Vector2.new(0, 0)
	tl.Position = UDim2.new(0, 12, 0, 58)
	tl.Size = UDim2.fromOffset(440, 48)
	tl.BackgroundColor3 = Color3.fromRGB(18, 36, 26)
	tl.BackgroundTransparency = 0.2
	tl.BorderSizePixel = 0
	tl.Text = message
	tl.TextColor3 = Color3.fromRGB(90, 255, 130)
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = 17
	tl.TextWrapped = true
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.TextYAlignment = Enum.TextYAlignment.Center
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = tl
	tl.Parent = gui

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 8)
	cr.Parent = tl

	local tween = TweenService:Create(
		tl,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1, TextTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	tween:Play()
end

survivalBonus.OnClientEvent:Connect(function(msg: unknown)
	if typeof(msg) == "string" then
		showSurvivalBonusPopup(msg :: string)
	end
end)

local function formatRankedCountdown(totalSec: number): string
	local m = math.floor(totalSec / 60)
	local s = totalSec % 60
	return string.format("Ranked: %d:%02d", m, s)
end

rankedTimerSync.OnClientEvent:Connect(function(sec: unknown)
	if typeof(sec) ~= "number" then
		return
	end
	local n = math.max(0, math.floor(sec :: number))
	rankedTimerLabel.Text = formatRankedCountdown(n)
end)

local function showRoundResultsPanel(rows: { any })
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundEndPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 245
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.fromOffset(520, 360)
	panel.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 14)
	pc.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Text = "RANKED ROUND — RESULTS"
	title.Parent = panel

	local y = 64
	for _, row in ipairs(rows) do
		if typeof(row) == "table" then
			local t = row :: { [string]: any }
			local place = t.place
			local name = t.name
			local score = t.score
			local reward = t.reward
			if typeof(place) == "number" and typeof(name) == "string" and typeof(score) == "number" and typeof(reward) == "string" then
				local line = Instance.new("TextLabel")
				line.Size = UDim2.new(1, -32, 0, 72)
				line.Position = UDim2.new(0, 16, 0, y)
				line.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
				line.BackgroundTransparency = 0.2
				line.BorderSizePixel = 0
				line.Font = Enum.Font.GothamBold
				line.TextSize = 16
				line.TextColor3 = Color3.fromRGB(240, 240, 248)
				line.TextWrapped = true
				line.TextXAlignment = Enum.TextXAlignment.Left
				line.TextYAlignment = Enum.TextYAlignment.Top
				line.Text = string.format(
					"#%d  %s\nScore: %d   ·   %s",
					place :: number,
					name :: string,
					score :: number,
					reward :: string
				)
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 12)
				pad.PaddingTop = UDim.new(0, 8)
				pad.Parent = line
				line.Parent = panel
				local lc = Instance.new("UICorner")
				lc.CornerRadius = UDim.new(0, 8)
				lc.Parent = line
				y = y + 80
			end
		end
	end

	local foot = Instance.new("TextLabel")
	foot.Size = UDim2.new(1, -24, 0, 28)
	foot.Position = UDim2.new(0, 12, 1, -40)
	foot.BackgroundTransparency = 1
	foot.Font = Enum.Font.GothamMedium
	foot.TextSize = 14
	foot.TextColor3 = Color3.fromRGB(180, 180, 190)
	foot.Text = "Next round starts now — closing in 5 seconds"
	foot.TextXAlignment = Enum.TextXAlignment.Center
	foot.Parent = panel

	task.delay(5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

roundEnd.OnClientEvent:Connect(function(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	showRoundResultsPanel(payload :: { any })
end)

local function showVoidBeastUnlock()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidBeastFlash"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 260
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.fromRGB(5, 0, 12)
	black.BackgroundTransparency = 0.15
	black.BorderSizePixel = 0
	black.Parent = gui

	local purple = Instance.new("Frame")
	purple.Size = UDim2.fromScale(1, 1)
	purple.BackgroundColor3 = Color3.fromRGB(120, 40, 200)
	purple.BackgroundTransparency = 0.55
	purple.BorderSizePixel = 0
	purple.Parent = gui

	local msg = Instance.new("TextLabel")
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.fromOffset(900, 120)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 36
	msg.TextWrapped = true
	msg.TextColor3 = Color3.fromRGB(220, 160, 255)
	msg.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	msg.TextStrokeTransparency = 0.35
	msg.Text = "THE VOID BEAST AWAKENS - Secret animal unlocked"
	msg.Parent = gui

	TweenService:Create(purple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(black, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(msg, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(5.1, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

voidBeastUnlocked.OnClientEvent:Connect(function()
	showVoidBeastUnlock()
end)

-- Bush proximity: subtle full-screen tint while HRP is inside tagged Forest bushes.
local FOREST_BUSH_TAG = "ForestBush"
local bushTintGui = Instance.new("ScreenGui")
bushTintGui.Name = "BushTint"
bushTintGui.ResetOnSpawn = false
bushTintGui.DisplayOrder = 9
bushTintGui.IgnoreGuiInset = true
bushTintGui.Parent = playerGui

local bushTintFrame = Instance.new("Frame")
bushTintFrame.Name = "Tint"
bushTintFrame.Size = UDim2.fromScale(1, 1)
bushTintFrame.BackgroundColor3 = Color3.fromRGB(12, 28, 18)
bushTintFrame.BackgroundTransparency = 1
bushTintFrame.BorderSizePixel = 0
bushTintFrame.Active = false
bushTintFrame.Parent = bushTintGui

local function pointInBushEllipsoid(world: Vector3, bush: BasePart): boolean
	local d = world - bush.Position
	local h = bush.Size * 0.5
	if h.X < 0.05 or h.Y < 0.05 or h.Z < 0.05 then
		return false
	end
	local nx = d.X / h.X
	local ny = d.Y / h.Y
	local nz = d.Z / h.Z
	return nx * nx + ny * ny + nz * nz <= 1.08
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local tint = 1
	if hrp and hrp:IsA("BasePart") then
		local pos = (hrp :: BasePart).Position
		for _, inst in ipairs(CollectionService:GetTagged(FOREST_BUSH_TAG)) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) and pointInBushEllipsoid(pos, inst) then
				tint = 0.52
				break
			end
		end
	end
	bushTintFrame.BackgroundTransparency = tint
end)

-- --- Minimap (bottom right; M to toggle) ---
local MINIMAP_STUDS = 800
local MINIMAP_PX = 150
local MINIMAP_SCALE = MINIMAP_PX / MINIMAP_STUDS

local minimapGui = Instance.new("ScreenGui")
minimapGui.Name = "MinimapHud"
minimapGui.ResetOnSpawn = false
minimapGui.DisplayOrder = 16
minimapGui.IgnoreGuiInset = true
minimapGui.Enabled = true
minimapGui.Parent = playerGui

local minimapStack = Instance.new("Frame")
minimapStack.Name = "MinimapStack"
minimapStack.AnchorPoint = Vector2.new(1, 1)
minimapStack.Position = UDim2.new(1, -14, 1, -14)
minimapStack.Size = UDim2.fromOffset(150, 188)
minimapStack.BackgroundTransparency = 1
minimapStack.BorderSizePixel = 0
minimapStack.Parent = minimapGui

local minimapList = Instance.new("UIListLayout")
minimapList.FillDirection = Enum.FillDirection.Vertical
minimapList.HorizontalAlignment = Enum.HorizontalAlignment.Center
minimapList.VerticalAlignment = Enum.VerticalAlignment.Top
minimapList.Padding = UDim.new(0, 4)
minimapList.SortOrder = Enum.SortOrder.LayoutOrder
minimapList.Parent = minimapStack

local mapTitleLabel = Instance.new("TextLabel")
mapTitleLabel.Name = "MapTitle"
mapTitleLabel.LayoutOrder = 1
mapTitleLabel.Size = UDim2.new(1, 0, 0, 14)
mapTitleLabel.BackgroundTransparency = 1
mapTitleLabel.Font = Enum.Font.GothamBlack
mapTitleLabel.TextSize = 11
mapTitleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
mapTitleLabel.Text = "MAP"
mapTitleLabel.TextXAlignment = Enum.TextXAlignment.Center
mapTitleLabel.Parent = minimapStack

local minimapContainer = Instance.new("Frame")
minimapContainer.Name = "Minimap"
minimapContainer.LayoutOrder = 2
minimapContainer.Size = UDim2.fromOffset(MINIMAP_PX, MINIMAP_PX)
minimapContainer.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
minimapContainer.BackgroundTransparency = 0.42
minimapContainer.BorderSizePixel = 0
minimapContainer.ClipsDescendants = true
minimapContainer.Parent = minimapStack

local minimapCorner = Instance.new("UICorner")
minimapCorner.CornerRadius = UDim.new(0, 10)
minimapCorner.Parent = minimapContainer

local minimapAnimalLabel = Instance.new("TextLabel")
minimapAnimalLabel.Name = "AnimalName"
minimapAnimalLabel.LayoutOrder = 3
minimapAnimalLabel.Size = UDim2.new(1, 0, 0, 16)
minimapAnimalLabel.BackgroundTransparency = 1
minimapAnimalLabel.Font = Enum.Font.GothamMedium
minimapAnimalLabel.TextSize = 11
minimapAnimalLabel.TextColor3 = Color3.fromRGB(190, 195, 210)
minimapAnimalLabel.Text = "—"
minimapAnimalLabel.TextTruncate = Enum.TextTruncate.AtEnd
minimapAnimalLabel.TextXAlignment = Enum.TextXAlignment.Center
minimapAnimalLabel.Parent = minimapStack

local function minimapWorldDeltaToPixel(dx: number, dz: number): (number, number)
	local half = MINIMAP_PX / 2
	local px = half + dx * MINIMAP_SCALE
	local py = half - dz * MINIMAP_SCALE
	return px, py
end

local function minimapAddDot(parent: Instance, px: number, py: number, color: Color3, z: number)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Position = UDim2.fromOffset(px, py)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = z
	dot.Parent = parent
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
end

local function minimapUpdateDots()
	for _, child in minimapContainer:GetChildren() do
		if child:IsA("Frame") and child.Name == "Dot" then
			child:Destroy()
		end
	end

	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local pPos = (hrp :: BasePart).Position

	minimapAddDot(minimapContainer, MINIMAP_PX / 2, MINIMAP_PX / 2, Color3.fromRGB(255, 255, 255), 10)

	for _, plr in Players:GetPlayers() do
		if plr ~= player then
			local ch = plr.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local q = (r :: BasePart).Position
				local px, py = minimapWorldDeltaToPixel(q.X - pPos.X, q.Z - pPos.Z)
				minimapAddDot(minimapContainer, px, py, Color3.fromRGB(255, 60, 60), 5)
			end
		end
	end

	local botsFolder = Workspace:FindFirstChild("Bots")
	if botsFolder and botsFolder:IsA("Folder") then
		for _, m in botsFolder:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("EvolveBot") == true then
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					local q = (r :: BasePart).Position
					local px, py = minimapWorldDeltaToPixel(q.X - pPos.X, q.Z - pPos.Z)
					minimapAddDot(minimapContainer, px, py, Color3.fromRGB(255, 160, 50), 5)
				end
			end
		end
	end

	local chestsFolder = Workspace:FindFirstChild("Chests")
	if chestsFolder and chestsFolder:IsA("Folder") then
		for _, p in chestsFolder:GetChildren() do
			if p:IsA("BasePart") then
				local q = p.Position
				local px, py = minimapWorldDeltaToPixel(q.X - pPos.X, q.Z - pPos.Z)
				minimapAddDot(minimapContainer, px, py, Color3.fromRGB(255, 220, 70), 4)
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		minimapGui.Enabled = not minimapGui.Enabled
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		if minimapGui.Enabled then
			minimapUpdateDots()
		end
	end
end)
task.defer(minimapUpdateDots)

-- --- Shop (chest purchases) ---
local SHOP_COMMON_PRICE = 50
local SHOP_RARE_PRICE = 150

local shopGui = Instance.new("ScreenGui")
shopGui.Name = "ShopGui"
shopGui.ResetOnSpawn = false
shopGui.DisplayOrder = 45
shopGui.Parent = playerGui

local shopModal = Instance.new("Frame")
shopModal.Name = "ShopModal"
shopModal.Size = UDim2.fromScale(1, 1)
shopModal.BackgroundTransparency = 1
shopModal.Visible = false
shopModal.Parent = shopGui

local shopDim = Instance.new("TextButton")
shopDim.Name = "Dim"
shopDim.Size = UDim2.fromScale(1, 1)
shopDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shopDim.BackgroundTransparency = 0.45
shopDim.Text = ""
shopDim.AutoButtonColor = false
shopDim.ZIndex = 1
shopDim.Parent = shopModal

local shopPanel = Instance.new("Frame")
shopPanel.Name = "Panel"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
shopPanel.Size = UDim2.fromOffset(560, 440)
shopPanel.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
shopPanel.BorderSizePixel = 0
shopPanel.ZIndex = 2
shopPanel.Parent = shopModal

local shopPanelCorner = Instance.new("UICorner")
shopPanelCorner.CornerRadius = UDim.new(0, 12)
shopPanelCorner.Parent = shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, -100, 0, 36)
shopTitle.Position = UDim2.new(0, 16, 0, 12)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.TextSize = 22
shopTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "Skin chest shop"
shopTitle.Parent = shopPanel

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.fromOffset(36, 36)
shopClose.Position = UDim2.new(1, -44, 0, 10)
shopClose.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
shopClose.TextColor3 = Color3.fromRGB(255, 255, 255)
shopClose.Font = Enum.Font.GothamBold
shopClose.TextSize = 20
shopClose.Text = "X"
shopClose.AutoButtonColor = true
shopClose.ZIndex = 3
shopClose.Parent = shopPanel

local shopCloseCorner = Instance.new("UICorner")
shopCloseCorner.CornerRadius = UDim.new(0, 8)
shopCloseCorner.Parent = shopClose

local shopCardsRow = Instance.new("Frame")
shopCardsRow.Name = "CardsRow"
shopCardsRow.AnchorPoint = Vector2.new(0.5, 0)
shopCardsRow.Position = UDim2.new(0.5, 0, 0, 56)
shopCardsRow.Size = UDim2.new(1, -24, 1, -68)
shopCardsRow.BackgroundTransparency = 1
shopCardsRow.Parent = shopPanel

local cardsLayout = Instance.new("UIListLayout")
cardsLayout.FillDirection = Enum.FillDirection.Horizontal
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
cardsLayout.Padding = UDim.new(0, 16)
cardsLayout.Parent = shopCardsRow

local function makeChestCard(
	parent: Instance,
	titleText: string,
	price: number,
	oddsText: string,
	layoutOrder: number
): TextButton
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 248, 0, 340)
	card.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 0, 28)
	t.Position = UDim2.new(0, 8, 0, 10)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 17
	t.TextColor3 = Color3.fromRGB(240, 240, 250)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = titleText
	t.Parent = card

	local p = Instance.new("TextLabel")
	p.Size = UDim2.new(1, -16, 0, 24)
	p.Position = UDim2.new(0, 8, 0, 40)
	p.BackgroundTransparency = 1
	p.Font = Enum.Font.GothamBold
	p.TextSize = 16
	p.TextColor3 = Color3.fromRGB(255, 210, 90)
	p.TextXAlignment = Enum.TextXAlignment.Left
	p.Text = string.format("%d coins", price)
	p.Parent = card

	local odds = Instance.new("TextLabel")
	odds.Size = UDim2.new(1, -16, 0, 200)
	odds.Position = UDim2.new(0, 8, 0, 72)
	odds.BackgroundTransparency = 1
	odds.Font = Enum.Font.GothamMedium
	odds.TextSize = 14
	odds.TextColor3 = Color3.fromRGB(190, 190, 200)
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextYAlignment = Enum.TextYAlignment.Top
	odds.TextWrapped = true
	odds.Text = oddsText
	odds.Parent = card

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(1, -20, 0, 40)
	buy.Position = UDim2.new(0, 10, 1, -50)
	buy.BackgroundColor3 = Color3.fromRGB(70, 160, 95)
	buy.TextColor3 = Color3.fromRGB(255, 255, 255)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 16
	buy.Text = "Buy"
	buy.AutoButtonColor = true
	buy.Parent = card

	local buyC = Instance.new("UICorner")
	buyC.CornerRadius = UDim.new(0, 8)
	buyC.Parent = buy

	return buy
end

local oddsCommon = "Drop rates:\nCommon 60%\nRare 25%\nEpic 12%\nLegendary 3%"
local oddsRare = "Drop rates:\nCommon 20%\nRare 50%\nEpic 25%\nLegendary 5%"

local commonBuyBtn = makeChestCard(shopCardsRow, "Common chest", SHOP_COMMON_PRICE, oddsCommon, 1)
local rareBuyBtn = makeChestCard(shopCardsRow, "Rare chest", SHOP_RARE_PRICE, oddsRare, 2)

local function refreshShopBuyButtons()
	local c = currentCoins
	if c < SHOP_COMMON_PRICE then
		commonBuyBtn.Text = "Not enough coins"
		commonBuyBtn.AutoButtonColor = false
		commonBuyBtn.Active = false
		commonBuyBtn.BackgroundColor3 = Color3.fromRGB(72, 72, 80)
		commonBuyBtn.TextColor3 = Color3.fromRGB(170, 170, 178)
	else
		commonBuyBtn.Text = "Buy"
		commonBuyBtn.AutoButtonColor = true
		commonBuyBtn.Active = true
		commonBuyBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 95)
		commonBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if c < SHOP_RARE_PRICE then
		rareBuyBtn.Text = "Not enough coins"
		rareBuyBtn.AutoButtonColor = false
		rareBuyBtn.Active = false
		rareBuyBtn.BackgroundColor3 = Color3.fromRGB(72, 72, 80)
		rareBuyBtn.TextColor3 = Color3.fromRGB(170, 170, 178)
	else
		rareBuyBtn.Text = "Buy"
		rareBuyBtn.AutoButtonColor = true
		rareBuyBtn.Active = true
		rareBuyBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 95)
		rareBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function playShopChestOpenAnim()
	local g = Instance.new("ScreenGui")
	g.Name = "ShopChestFlash"
	g.ResetOnSpawn = false
	g.DisplayOrder = 215
	g.IgnoreGuiInset = true
	g.Parent = playerGui
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 210, 70)
	flash.BackgroundTransparency = 0.25
	flash.BorderSizePixel = 0
	flash.Parent = g
	TweenService:Create(flash, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.55, function()
		if g.Parent then
			g:Destroy()
		end
	end)
end

local function closeShop()
	shopModal.Visible = false
	shopGui.DisplayOrder = 45
end

shopDim.MouseButton1Click:Connect(closeShop)
shopClose.MouseButton1Click:Connect(closeShop)

local shopOpenBtn = Instance.new("TextButton")
shopOpenBtn.Name = "ShopOpenButton"
shopOpenBtn.AnchorPoint = Vector2.new(1, 1)
shopOpenBtn.Position = UDim2.new(1, -12, 1, -12)
shopOpenBtn.Size = UDim2.fromOffset(120, 36)
shopOpenBtn.BackgroundColor3 = Color3.fromRGB(55, 48, 72)
shopOpenBtn.TextColor3 = Color3.fromRGB(255, 220, 140)
shopOpenBtn.Font = Enum.Font.GothamBold
shopOpenBtn.TextSize = 16
shopOpenBtn.Text = "Shop"
shopOpenBtn.AutoButtonColor = true
shopOpenBtn.Parent = shopGui

local shopOpenCorner = Instance.new("UICorner")
shopOpenCorner.CornerRadius = UDim.new(0, 8)
shopOpenCorner.Parent = shopOpenBtn

shopOpenBtn.MouseButton1Click:Connect(function()
	if menuState.mainMenuShown then
		shopGui.DisplayOrder = 130
	end
	shopModal.Visible = true
	refreshShopBuyButtons()
end)

-- Avoid double chest SFX when shop purchase triggers skinReceived shortly after.
local suppressSkinChestSfx = false

local function tryPurchaseChest(kind: string)
	local ok = purchaseChest:InvokeServer(kind)
	if typeof(ok) == "boolean" and ok then
		suppressSkinChestSfx = true
		SoundManager.playSound("chestOpen")
		task.delay(0.85, function()
			suppressSkinChestSfx = false
		end)
		playShopChestOpenAnim()
	end
	refreshShopBuyButtons()
end

commonBuyBtn.MouseButton1Click:Connect(function()
	if commonBuyBtn.Active and currentCoins >= SHOP_COMMON_PRICE then
		tryPurchaseChest("Common")
	end
end)

rareBuyBtn.MouseButton1Click:Connect(function()
	if rareBuyBtn.Active and currentCoins >= SHOP_RARE_PRICE then
		tryPurchaseChest("Rare")
	end
end)

local function restoreShopSkinOrdersFromMenu()
	shopGui.DisplayOrder = 45
	skinScreenGui.DisplayOrder = 35
end

local function setInventoryOpen(v: boolean)
	invOpen = v
	invPanel.Visible = v
end

local menuApi = MenuManager.start({
	menuState = menuState,
	player = player,
	playerGui = playerGui,
	Players = Players,
	TweenService = TweenService,
	playerStartedGame = playerStartedGame,
	getPlayerStatsRemote = getPlayerStatsRemote,
	getLeaderboardRemote = getLeaderboardRemote,
	abilityHudGui = abilityHudGui,
	shopGui = shopGui,
	shopModal = shopModal,
	skinScreenGui = skinScreenGui,
	invPanel = invPanel,
	rebuildSkinGrid = rebuildSkinGrid,
	refreshShopBuyButtons = refreshShopBuyButtons,
	setInventoryOpen = setInventoryOpen,
	restoreShopSkinOrders = restoreShopSkinOrdersFromMenu,
})
menuRefreshStats = menuApi.refreshStatsPanel


local lastHudPoints: number? = nil
pointsUpdate.OnClientEvent:Connect(function(points: number, level: number?)
	local prev = lastHudPoints
	lastHudPoints = points
	if prev ~= nil and points == prev + 1 then
		SoundManager.playSound("eat")
	end
	local lv = if level ~= nil then level else 1
	setHudPointsLine(points, lv)
	if menuRefreshStats and menuState.mainMenuShown then
		menuRefreshStats()
	end
end)

coinsUpdated.OnClientEvent:Connect(function(coins: unknown)
	if typeof(coins) == "number" then
		setHudCoins(coins :: number)
	end
	if shopModal.Visible then
		refreshShopBuyButtons()
	end
	if menuRefreshStats and menuState.mainMenuShown then
		menuRefreshStats()
	end
end)

titleSync.OnClientEvent:Connect(function(title: unknown)
	if typeof(title) == "string" then
		titleHudLabel.Text = title :: string
	end
	if menuRefreshStats and menuState.mainMenuShown then
		menuRefreshStats()
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
	for _, child in playerGui:GetChildren() do
		if child.Name == "EvolutionPick" then
			child:Destroy()
		end
	end
	clearPickBlur()

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

		card.MouseButton1Click:Connect(function()
			if picked then
				return
			end
			picked = true
			minimapAnimalLabel.Text = animal.name
			currentAnimalForAbility = animal.name
			refreshAbilityHudTitle()
			animalPicked:FireServer(animal.name)
			task.defer(function()
				animalChanged:FireServer(animal.name)
			end)
			closePickUi()
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
	SoundManager.playSound("levelUp")
	if choices ~= nil and isChoicesArray(choices) then
		showEvolutionPick(newLevel, choices :: { AnimalChoice })
	else
		showLegacyLevelToast(newLevel)
	end
end)

playerDied.OnClientEvent:Connect(function(_newLevel: number, defaultAnimal: unknown?)
	survivalStreakLabel.Text = formatAliveTime(0)
	local evo = playerGui:FindFirstChild("EvolutionPick")
	if evo then
		evo:Destroy()
	end
	clearPickBlur()
	if typeof(defaultAnimal) == "string" then
		minimapAnimalLabel.Text = defaultAnimal :: string
		currentAnimalForAbility = defaultAnimal :: string
		refreshAbilityHudTitle()
	end
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
		SoundManager.playSound("kill")
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
		SoundManager.playSound("titleUnlock")
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
	if isMenuBlocking() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		SoundManager.playSound("attack")
		attackRequest:FireServer()
	end
end)
end

return UIManager
