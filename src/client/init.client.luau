local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

local SoundManager = require(script.Parent:WaitForChild("SoundManager"))
SoundManager.startAmbientLoop()

player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 720)
player.CameraMinZoomDistance = math.min(player.CameraMinZoomDistance, 0.5)

local function applyMapCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = math.max(cam.FieldOfView, 74)
	end
end
applyMapCamera()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyMapCamera)
player.CharacterAdded:Connect(function()
	task.defer(applyMapCamera)
end)

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUpRemote = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
local animalPicked = ReplicatedStorage:WaitForChild("AnimalPicked") :: RemoteEvent
local animalChanged = ReplicatedStorage:WaitForChild("AnimalChanged") :: RemoteEvent
local playerDied = ReplicatedStorage:WaitForChild("PlayerDied") :: RemoteEvent
local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest") :: RemoteEvent
local playerKilled = ReplicatedStorage:WaitForChild("PlayerKilled") :: RemoteEvent
local titleSync = ReplicatedStorage:WaitForChild("TitleSync") :: RemoteEvent
local titleUnlocked = ReplicatedStorage:WaitForChild("TitleUnlocked") :: RemoteEvent
local extinctionEvent = ReplicatedStorage:WaitForChild("ExtinctionEvent") :: RemoteEvent
local lastPredator = ReplicatedStorage:WaitForChild("LastPredator") :: RemoteEvent
local skinReceived = ReplicatedStorage:WaitForChild("SkinReceived") :: RemoteEvent
local skinInventorySync = ReplicatedStorage:WaitForChild("SkinInventorySync") :: RemoteEvent
local coinsUpdated = ReplicatedStorage:WaitForChild("CoinsUpdated") :: RemoteEvent
local purchaseChest = ReplicatedStorage:WaitForChild("PurchaseChest") :: RemoteFunction
local survivalBonus = ReplicatedStorage:WaitForChild("SurvivalBonus") :: RemoteEvent
local survivalStreakSync = ReplicatedStorage:WaitForChild("SurvivalStreakSync") :: RemoteEvent
local roundEnd = ReplicatedStorage:WaitForChild("RoundEnd") :: RemoteEvent
local voidBeastUnlocked = ReplicatedStorage:WaitForChild("VoidBeastUnlocked") :: RemoteEvent
local rankedTimerSync = ReplicatedStorage:WaitForChild("RankedTimerSync") :: RemoteEvent
local playerStartedGame = ReplicatedStorage:WaitForChild("PlayerStartedGame") :: RemoteEvent
local getPlayerStatsRemote = ReplicatedStorage:WaitForChild("GetPlayerStats") :: RemoteFunction
local getLeaderboardRemote = ReplicatedStorage:WaitForChild("GetLeaderboard") :: RemoteFunction
local useAbility = ReplicatedStorage:WaitForChild("UseAbility") :: RemoteEvent
local abilityFeedback = ReplicatedStorage:WaitForChild("AbilityFeedback") :: RemoteEvent

local playerGui = player:WaitForChild("PlayerGui")

local UIManager = require(script.Parent:WaitForChild("UIManager"))
UIManager.start({
	player = player,
	playerGui = playerGui,
	Players = Players,
	TweenService = TweenService,
	UserInputService = UserInputService,
	Workspace = Workspace,
	CollectionService = CollectionService,
	RunService = RunService,
	SoundManager = SoundManager,
	pointsUpdate = pointsUpdate,
	levelUpRemote = levelUpRemote,
	animalPicked = animalPicked,
	animalChanged = animalChanged,
	playerDied = playerDied,
	attackRequest = attackRequest,
	playerKilled = playerKilled,
	titleSync = titleSync,
	titleUnlocked = titleUnlocked,
	extinctionEvent = extinctionEvent,
	lastPredator = lastPredator,
	skinReceived = skinReceived,
	skinInventorySync = skinInventorySync,
	coinsUpdated = coinsUpdated,
	purchaseChest = purchaseChest,
	survivalBonus = survivalBonus,
	survivalStreakSync = survivalStreakSync,
	roundEnd = roundEnd,
	voidBeastUnlocked = voidBeastUnlocked,
	rankedTimerSync = rankedTimerSync,
	playerStartedGame = playerStartedGame,
	getPlayerStatsRemote = getPlayerStatsRemote,
	getLeaderboardRemote = getLeaderboardRemote,
	useAbility = useAbility,
	abilityFeedback = abilityFeedback,
})
