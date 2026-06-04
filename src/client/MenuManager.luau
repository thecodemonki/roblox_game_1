-- Main menu landing: Play/Ranked, stats/leaderboard, shop/skins entry from menu.

export type MenuDeps = {
	menuState: { mainMenuShown: boolean },
	player: Player,
	playerGui: PlayerGui,
	Players: Players,
	TweenService: TweenService,
	playerStartedGame: RemoteEvent,
	getPlayerStatsRemote: RemoteFunction,
	getLeaderboardRemote: RemoteFunction,
	abilityHudGui: ScreenGui,
	shopGui: ScreenGui,
	shopModal: GuiObject,
	skinScreenGui: ScreenGui,
	invPanel: Frame,
	rebuildSkinGrid: () -> (),
	refreshShopBuyButtons: () -> (),
	setInventoryOpen: (boolean) -> (),
	restoreShopSkinOrders: () -> (),
}

local MenuManager = {}

function MenuManager.isBlockingGameplay(menuState: { mainMenuShown: boolean }): boolean
	return menuState.mainMenuShown
end

function MenuManager.start(deps: MenuDeps)
	local menuState = deps.menuState
	local player = deps.player
	local playerGui = deps.playerGui
	local Players = deps.Players
	local TweenService = deps.TweenService
	local playerStartedGame = deps.playerStartedGame
	local getPlayerStatsRemote = deps.getPlayerStatsRemote
	local getLeaderboardRemote = deps.getLeaderboardRemote
	local abilityHudGui = deps.abilityHudGui
	local shopGui = deps.shopGui
	local shopModal = deps.shopModal
	local skinScreenGui = deps.skinScreenGui
	local invPanel = deps.invPanel
	local rebuildSkinGrid = deps.rebuildSkinGrid
	local refreshShopBuyButtons = deps.refreshShopBuyButtons
	local setInventoryOpen = deps.setInventoryOpen
	local restoreShopSkinOrders = deps.restoreShopSkinOrders

	local MAIN_MENU_DISPLAY_ORDER = 120
	local MENU_OVERLAY_SHOP_ORDER = 130

	deps.abilityHudGui.Enabled = false

	local mainMenuGui = Instance.new("ScreenGui")
	mainMenuGui.Name = "MainMenu"
	mainMenuGui.ResetOnSpawn = false
	mainMenuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainMenuGui.DisplayOrder = MAIN_MENU_DISPLAY_ORDER
	mainMenuGui.IgnoreGuiInset = true
	mainMenuGui.Parent = playerGui

	local menuRoot = Instance.new("Frame")
	menuRoot.Name = "Root"
	menuRoot.Size = UDim2.fromScale(1, 1)
	menuRoot.BackgroundTransparency = 1
	menuRoot.BorderSizePixel = 0
	menuRoot.Parent = mainMenuGui

	local dimOverlay = Instance.new("Frame")
	dimOverlay.Name = "Dim"
	dimOverlay.Size = UDim2.fromScale(1, 1)
	dimOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	dimOverlay.BackgroundTransparency = 0.3
	dimOverlay.BorderSizePixel = 0
	dimOverlay.ZIndex = 1
	dimOverlay.Parent = menuRoot

	local particleHolder = Instance.new("Frame")
	particleHolder.Name = "Particles"
	particleHolder.Size = UDim2.fromScale(1, 1)
	particleHolder.BackgroundTransparency = 1
	particleHolder.BorderSizePixel = 0
	particleHolder.ClipsDescendants = true
	particleHolder.ZIndex = 2
	particleHolder.Parent = menuRoot

	for _ = 1, 20 do
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(math.random(4, 10), math.random(4, 10))
		p.BorderSizePixel = 0
		p.BackgroundColor3 = if math.random(1, 2) == 1 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 210, 120)
		p.BackgroundTransparency = 0.4
		p.ZIndex = 2
		p.Parent = particleHolder
		task.spawn(function()
			while p.Parent do
				p.Position = UDim2.new(math.random(5, 95) / 100, 0, 1.05, 0)
				p.BackgroundTransparency = math.random(35, 65) / 100
				local dur = 7 + math.random() * 5
				local tw = TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
					Position = UDim2.new(p.Position.X.Scale, 0, -0.08, 0),
					BackgroundTransparency = 1,
				})
				tw:Play()
				tw.Completed:Wait()
			end
		end)
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Position = UDim2.new(0.5, 0, 0.08, 0)
	titleLabel.Size = UDim2.fromOffset(520, 100)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 80
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = "EVOLVE"
	titleLabel.ZIndex = 5
	titleLabel.Parent = menuRoot

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(230, 190, 80)
	titleStroke.Thickness = 2
	titleStroke.Parent = titleLabel

	local taglineLabel = Instance.new("TextLabel")
	taglineLabel.Name = "Tagline"
	taglineLabel.AnchorPoint = Vector2.new(0.5, 0)
	taglineLabel.Position = UDim2.new(0.5, 0, 0.08, 92)
	taglineLabel.Size = UDim2.fromOffset(640, 36)
	taglineLabel.BackgroundTransparency = 1
	taglineLabel.Font = Enum.Font.GothamMedium
	taglineLabel.TextSize = 20
	taglineLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
	taglineLabel.Text = "Survive the forest. Evolve. Hunt the leaderboard."
	taglineLabel.ZIndex = 5
	taglineLabel.Parent = menuRoot

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "Version"
	versionLabel.AnchorPoint = Vector2.new(0, 1)
	versionLabel.Position = UDim2.new(0, 16, 1, -12)
	versionLabel.Size = UDim2.fromOffset(220, 22)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Font = Enum.Font.GothamMedium
	versionLabel.TextSize = 14
	versionLabel.TextColor3 = Color3.fromRGB(120, 125, 140)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Text = "v0.1.0 BETA"
	versionLabel.ZIndex = 5
	versionLabel.Parent = menuRoot

	local leftCard = Instance.new("Frame")
	leftCard.Name = "LeaderboardCard"
	leftCard.AnchorPoint = Vector2.new(0, 0.5)
	leftCard.Position = UDim2.new(0.03, 0, 0.52, 0)
	leftCard.Size = UDim2.fromOffset(300, 340)
	leftCard.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	leftCard.BackgroundTransparency = 0.15
	leftCard.BorderSizePixel = 0
	leftCard.ZIndex = 4
	leftCard.Parent = menuRoot

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(0, 12)
	leftCorner.Parent = leftCard

	local leftStroke = Instance.new("UIStroke")
	leftStroke.Color = Color3.fromRGB(80, 70, 50)
	leftStroke.Thickness = 1
	leftStroke.Transparency = 0.4
	leftStroke.Parent = leftCard

	local lbHeader = Instance.new("TextLabel")
	lbHeader.Size = UDim2.new(1, -20, 0, 32)
	lbHeader.Position = UDim2.new(0, 10, 0, 10)
	lbHeader.BackgroundTransparency = 1
	lbHeader.Font = Enum.Font.GothamBold
	lbHeader.TextSize = 20
	lbHeader.TextColor3 = Color3.fromRGB(255, 215, 130)
	lbHeader.TextXAlignment = Enum.TextXAlignment.Left
	lbHeader.Text = "TOP HUNTERS"
	lbHeader.ZIndex = 5
	lbHeader.Parent = leftCard

	local lbRowsFrame = Instance.new("Frame")
	lbRowsFrame.Name = "Rows"
	lbRowsFrame.Position = UDim2.new(0, 10, 0, 48)
	lbRowsFrame.Size = UDim2.new(1, -20, 1, -58)
	lbRowsFrame.BackgroundTransparency = 1
	lbRowsFrame.ZIndex = 5
	lbRowsFrame.Parent = leftCard

	local lbLayout = Instance.new("UIListLayout")
	lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lbLayout.Padding = UDim.new(0, 6)
	lbLayout.Parent = lbRowsFrame

	local rightCard = Instance.new("Frame")
	rightCard.Name = "StatsCard"
	rightCard.AnchorPoint = Vector2.new(1, 0.5)
	rightCard.Position = UDim2.new(0.97, 0, 0.52, 0)
	rightCard.Size = UDim2.fromOffset(300, 340)
	rightCard.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	rightCard.BackgroundTransparency = 0.15
	rightCard.BorderSizePixel = 0
	rightCard.ZIndex = 4
	rightCard.Parent = menuRoot

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(0, 12)
	rightCorner.Parent = rightCard

	local rightStroke = Instance.new("UIStroke")
	rightStroke.Color = Color3.fromRGB(80, 70, 50)
	rightStroke.Thickness = 1
	rightStroke.Transparency = 0.4
	rightStroke.Parent = rightCard

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "Avatar"
	avatarImage.Position = UDim2.new(0.5, -54, 0, 14)
	avatarImage.Size = UDim2.fromOffset(108, 108)
	avatarImage.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
	avatarImage.BorderSizePixel = 0
	avatarImage.ZIndex = 5
	avatarImage.Parent = rightCard

	local avatarRound = Instance.new("UICorner")
	avatarRound.CornerRadius = UDim.new(1, 0)
	avatarRound.Parent = avatarImage

	local statsStack = Instance.new("Frame")
	statsStack.Name = "StatsStack"
	statsStack.Position = UDim2.new(0, 12, 0, 132)
	statsStack.Size = UDim2.new(1, -24, 1, -146)
	statsStack.BackgroundTransparency = 1
	statsStack.ZIndex = 5
	statsStack.Parent = rightCard

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 4)
	statsLayout.Parent = statsStack

	local function makeStatRow(): TextLabel
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 15
		row.TextColor3 = Color3.fromRGB(215, 218, 230)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.ZIndex = 5
		row.Parent = statsStack
		return row
	end

	local statNameLabel = makeStatRow()
	local statLevelLabel = makeStatRow()
	local statAnimalLabel = makeStatRow()
	local statTitleLabel = makeStatRow()
	local statKillsLabel = makeStatRow()
	local statCoinsLabel = makeStatRow()
	local statPointsLabel = makeStatRow()

	local centerCol = Instance.new("Frame")
	centerCol.Name = "Buttons"
	centerCol.AnchorPoint = Vector2.new(0.5, 0.5)
	centerCol.Position = UDim2.new(0.5, 0, 0.55, 0)
	centerCol.Size = UDim2.fromOffset(240, 260)
	centerCol.BackgroundTransparency = 1
	centerCol.ZIndex = 5
	centerCol.Parent = menuRoot

	local centerLayout = Instance.new("UIListLayout")
	centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	centerLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	centerLayout.Padding = UDim.new(0, 12)
	centerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	centerLayout.Parent = centerCol

	local function makeMenuButton(text: string, bg: Color3, layoutOrder: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = text
		btn.Size = UDim2.new(1, 0, 0, 48)
		btn.BackgroundColor3 = bg
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 20
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = text
		btn.AutoButtonColor = true
		btn.LayoutOrder = layoutOrder
		btn.ZIndex = 5
		btn.Parent = centerCol
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = btn
		return btn
	end

	local playBtn = makeMenuButton("PLAY", Color3.fromRGB(46, 160, 75), 1)
	local rankedBtn = makeMenuButton("RANKED", Color3.fromRGB(175, 135, 55), 2)
	local shopMenuBtn = makeMenuButton("SHOP", Color3.fromRGB(36, 38, 50), 3)
	local skinsMenuBtn = makeMenuButton("SKINS", Color3.fromRGB(36, 38, 50), 4)

	local shopBtnStroke = Instance.new("UIStroke")
	shopBtnStroke.Color = Color3.fromRGB(230, 190, 80)
	shopBtnStroke.Thickness = 1.5
	shopBtnStroke.Parent = shopMenuBtn

	local skinsBtnStroke = Instance.new("UIStroke")
	skinsBtnStroke.Color = Color3.fromRGB(230, 190, 80)
	skinsBtnStroke.Thickness = 1.5
	skinsBtnStroke.Parent = skinsMenuBtn

	local playBtnScale = Instance.new("UIScale")
	playBtnScale.Scale = 1
	playBtnScale.Parent = playBtn

	local function refreshStatsPanel()
		if not menuState.mainMenuShown then
			return
		end
		local ok, data = pcall(function()
			return getPlayerStatsRemote:InvokeServer()
		end)
		if not ok or typeof(data) ~= "table" then
			return
		end
		statNameLabel.Text = player.DisplayName
		statLevelLabel.Text = string.format("Level: %s", tostring((data :: any).level or "—"))
		statAnimalLabel.Text = string.format("Animal: %s", tostring((data :: any).animal or "—"))
		statTitleLabel.Text = string.format("Title: %s", tostring((data :: any).killTitle or "—"))
		statKillsLabel.Text = string.format("Kills: %s", tostring((data :: any).kills or 0))
		statCoinsLabel.Text = string.format("Coins: %s", tostring((data :: any).coins or 0))
		statPointsLabel.Text = string.format("Points: %s", tostring((data :: any).points or 0))
	end

	local function refreshLeaderboard()
		if not menuState.mainMenuShown then
			return
		end
		local ok, rows = pcall(function()
			return getLeaderboardRemote:InvokeServer()
		end)
		if not ok or typeof(rows) ~= "table" then
			return
		end
		for _, c in lbRowsFrame:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local rank = 1
		for _, row in ipairs(rows :: { any }) do
			if typeof(row) == "table" then
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 24)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextSize = 14
				lbl.TextColor3 = Color3.fromRGB(210, 214, 228)
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextTruncate = Enum.TextTruncate.AtEnd
				lbl.ZIndex = 5
				lbl.Text = string.format(
					"%d. %s  ·  %s  ·  %d",
					rank,
					tostring((row :: any).name or "?"),
					tostring((row :: any).killTitle or ""),
					tonumber((row :: any).kills) or 0
				)
				lbl.Parent = lbRowsFrame
				rank += 1
			end
		end
	end

	task.spawn(function()
		local thumbOk, url = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if thumbOk and typeof(url) == "string" then
			avatarImage.Image = url
		else
			avatarImage.Image = ""
		end
	end)

	task.defer(function()
		refreshStatsPanel()
		refreshLeaderboard()
	end)

	task.spawn(function()
		while mainMenuGui.Parent do
			task.wait(10)
			if not mainMenuGui.Enabled then
				break
			end
			refreshLeaderboard()
		end
	end)

	playBtn.MouseEnter:Connect(function()
		TweenService:Create(playBtnScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
	playBtn.MouseLeave:Connect(function()
		TweenService:Create(playBtnScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	local function startGameFromMenu(rankedMode: boolean)
		if not menuState.mainMenuShown then
			return
		end
		playerStartedGame:FireServer(rankedMode)
		menuState.mainMenuShown = false

		local flashGui = Instance.new("ScreenGui")
		flashGui.Name = "MainMenuTransition"
		flashGui.ResetOnSpawn = false
		flashGui.IgnoreGuiInset = true
		flashGui.DisplayOrder = 200
		flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		flashGui.Parent = playerGui

		local blackF = Instance.new("Frame")
		blackF.Size = UDim2.fromScale(1, 1)
		blackF.BackgroundColor3 = Color3.new(0, 0, 0)
		blackF.BackgroundTransparency = 1
		blackF.BorderSizePixel = 0
		blackF.ZIndex = 1
		blackF.Parent = flashGui

		local whiteF = Instance.new("Frame")
		whiteF.Size = UDim2.fromScale(1, 1)
		whiteF.BackgroundColor3 = Color3.new(1, 1, 1)
		whiteF.BackgroundTransparency = 1
		whiteF.BorderSizePixel = 0
		whiteF.ZIndex = 2
		whiteF.Parent = flashGui

		task.spawn(function()
			local wIn = TweenService:Create(whiteF, TweenInfo.new(0.07), { BackgroundTransparency = 0 })
			wIn:Play()
			wIn.Completed:Wait()
			local wOut = TweenService:Create(whiteF, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
			wOut:Play()
			wOut.Completed:Wait()
			blackF.BackgroundTransparency = 1
			local bIn = TweenService:Create(blackF, TweenInfo.new(0.22), { BackgroundTransparency = 0 })
			bIn:Play()
			bIn.Completed:Wait()
			local bOut = TweenService:Create(blackF, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			bOut:Play()
			bOut.Completed:Wait()
			restoreShopSkinOrders()
			setInventoryOpen(false)
			menuRoot.Visible = false
			dimOverlay.Visible = false
			particleHolder.Visible = false
			mainMenuGui.Enabled = false
			if mainMenuGui.Parent then
				mainMenuGui:Destroy()
			end
			abilityHudGui.Enabled = true
			if flashGui.Parent then
				flashGui:Destroy()
			end
		end)
	end

	playBtn.MouseButton1Click:Connect(function()
		startGameFromMenu(false)
	end)
	rankedBtn.MouseButton1Click:Connect(function()
		startGameFromMenu(true)
	end)
	shopMenuBtn.MouseButton1Click:Connect(function()
		shopGui.DisplayOrder = MENU_OVERLAY_SHOP_ORDER
		shopModal.Visible = true
		refreshShopBuyButtons()
	end)
	skinsMenuBtn.MouseButton1Click:Connect(function()
		skinScreenGui.DisplayOrder = MENU_OVERLAY_SHOP_ORDER
		setInventoryOpen(true)
		rebuildSkinGrid()
	end)

	return {
		refreshStatsPanel = refreshStatsPanel,
	}
end

return MenuManager
