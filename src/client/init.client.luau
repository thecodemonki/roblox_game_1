local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUpRemote = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent

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

local activeLevelPopupTween: Tween? = nil
local activeLevelPopup: Instance? = nil

levelUpRemote.OnClientEvent:Connect(function(newLevel: number)
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
end)
