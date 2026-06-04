-- Evolve Game Server — bootstrap: DataStore, player lifecycle, subsystem mounts.

print("Server script loaded successfully")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local playerDataStore = DataStoreService:GetDataStore("EvolvePlayerData_v1")

do
	local sss = game:GetService("ServerScriptService")
	for _, inst in ipairs(sss:GetDescendants()) do
		if inst.Name == "FoodSpawner" and (inst:IsA("Script") or inst:IsA("LocalScript")) then
			print("[Server] Destroying legacy FoodSpawner:", inst:GetFullName())
			inst:Destroy()
		end
	end
end

local DEFAULT_DATA = {
	level = 1,
	points = 0,
	kills = 0,
	killTitle = "Fresh Prey",
	coins = 0,
	skins = {},
	totalPlaytime = 0,
	rankedWins = 0,
	rankedWinStreak = 0,
	currentAnimal = "Noob Chicken",
}

print("[Server] init.server.luau starting (Evolve game)")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalPools = require(Shared:WaitForChild("AnimalPools"))

local pointsUpdate = ReplicatedStorage:WaitForChild("PointsUpdate") :: RemoteEvent
local levelUp = ReplicatedStorage:WaitForChild("LevelUp") :: RemoteEvent
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
local getPlayerStats = ReplicatedStorage:WaitForChild("GetPlayerStats") :: RemoteFunction
local getLeaderboard = ReplicatedStorage:WaitForChild("GetLeaderboard") :: RemoteFunction
local useAbility = ReplicatedStorage:WaitForChild("UseAbility") :: RemoteEvent
local abilityFeedback = ReplicatedStorage:WaitForChild("AbilityFeedback") :: RemoteEvent

local Bots = require(script:WaitForChild("Bots"))
local AnimalAppearance = require(script:WaitForChild("AnimalAppearance"))
local ChestSystem = require(script:WaitForChild("ChestSystem"))
local RankedSystem = require(script:WaitForChild("RankedSystem"))
local ProgressionSystem = require(script:WaitForChild("ProgressionSystem"))
local CombatSystem = require(script:WaitForChild("CombatSystem"))
local FoodSystem = require(script:WaitForChild("FoodSystem"))

local MAP_SIZE = 400
local MAP_SURFACE_Y = 0
local DEFAULT_PLAYER_WALK_SPEED = 16
local DEFAULT_PLAYER_JUMP_POWER = 50

local POINTS_PER_FOOD = 1
local POINTS_PER_KILL = 15
local BOT_MELEE_COOLDOWN = 1.5
local RESPAWN_DELAY = 3
local CHEST_COUNT = 5
local CHEST_OPEN_RANGE = 5
local CHEST_OPEN_COOLDOWN_SEC = 2
local CHEST_SAME_PART_DEBOUNCE_SEC = 0.35
local CHEST_RESPAWN_SEC = 60
local CHEST_SIZE = 3
local SKIN_MAX_LEVEL = 5
local COINS_PLAYTIME_INTERVAL_SEC = 60
local COINS_PER_PLAYTIME_BONUS = 10
local COINS_PER_KILL = 5
local COINS_PER_LEVEL_UP = 3
local SHOP_CHEST_COMMON_PRICE = 50
local SHOP_CHEST_RARE_PRICE = 150

local PLAYTIME_MILESTONE_5M = 300
local PLAYTIME_MILESTONE_20M = 1200
local PLAYTIME_MILESTONE_1H = 3600
local PLAYTIME_MILESTONE_5H = 18000
local SURVIVAL_BONUS_3M = 180
local SURVIVAL_BONUS_10M = 600
local CROWN_REEVAL_INTERVAL = 0.4
local SURVIVAL_SYNC_INTERVAL = 1

local RANKED_ROUND_SEC = 900
local RANKED_POINTS_KILL = 10
local RANKED_POINTS_EVOLUTION = 15
local RANKED_SURVIVE_SEC = 30

local ATTACK_RANGE = 8
local ATTACK_HALF_ARC_DEG = 90

local TIER_COMBAT: { [number]: { damage: number, cooldown: number } } = {
	[1] = { damage = 10, cooldown = 1.0 },
	[2] = { damage = 18, cooldown = 0.9 },
	[3] = { damage = 28, cooldown = 0.8 },
	[4] = { damage = 40, cooldown = 0.75 },
	[5] = { damage = 52, cooldown = 0.7 },
	[6] = { damage = 65, cooldown = 0.65 },
	[7] = { damage = 80, cooldown = 0.55 },
}

local SKINS_COMMON = {
	"Golden Chicken",
	"Brown Rat",
	"Blue Pigeon",
	"White Fox",
}
local SKINS_RARE = {
	"Arctic Wolf",
	"Shadow Rat",
	"Neon Pigeon",
	"Crystal Fox",
}
local SKINS_EPIC = {
	"Ghost Wolf",
	"Flame Fox",
	"Storm Hawk",
	"Void Rat",
}
local SKINS_LEGENDARY = {
	"Void Rex",
	"Shadow Dragon",
	"Inferno Phoenix",
	"Skeleton Rex",
}

local FOOD_MAX_COUNT = 80
local FOOD_SPAWN_INTERVAL_SEC = 1.5
local FOOD_SPAWN_RANGE = 350
local FOOD_SPAWN_Y = 2
local FOOD_INITIAL_SPAWN_COUNT = 10
local FOOD_REPLENISH_AFTER_EAT_SEC = 1.5

local G: any = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	TweenService = TweenService,
	Workspace = workspace,
	AnimalPools = AnimalPools,
	AnimalAppearance = AnimalAppearance,
	Bots = Bots,
	MAP_SIZE = MAP_SIZE,
	MAP_SURFACE_Y = MAP_SURFACE_Y,
	DEFAULT_PLAYER_WALK_SPEED = DEFAULT_PLAYER_WALK_SPEED,
	DEFAULT_PLAYER_JUMP_POWER = DEFAULT_PLAYER_JUMP_POWER,
	POINTS_PER_FOOD = POINTS_PER_FOOD,
	POINTS_PER_KILL = POINTS_PER_KILL,
	BOT_MELEE_COOLDOWN = BOT_MELEE_COOLDOWN,
	CHEST_COUNT = CHEST_COUNT,
	CHEST_OPEN_RANGE = CHEST_OPEN_RANGE,
	CHEST_OPEN_COOLDOWN_SEC = CHEST_OPEN_COOLDOWN_SEC,
	CHEST_SAME_PART_DEBOUNCE_SEC = CHEST_SAME_PART_DEBOUNCE_SEC,
	CHEST_RESPAWN_SEC = CHEST_RESPAWN_SEC,
	CHEST_SIZE = CHEST_SIZE,
	SKIN_MAX_LEVEL = SKIN_MAX_LEVEL,
	COINS_PLAYTIME_INTERVAL_SEC = COINS_PLAYTIME_INTERVAL_SEC,
	COINS_PER_PLAYTIME_BONUS = COINS_PER_PLAYTIME_BONUS,
	COINS_PER_KILL = COINS_PER_KILL,
	COINS_PER_LEVEL_UP = COINS_PER_LEVEL_UP,
	SHOP_CHEST_COMMON_PRICE = SHOP_CHEST_COMMON_PRICE,
	SHOP_CHEST_RARE_PRICE = SHOP_CHEST_RARE_PRICE,
	PLAYTIME_MILESTONE_5M = PLAYTIME_MILESTONE_5M,
	PLAYTIME_MILESTONE_20M = PLAYTIME_MILESTONE_20M,
	PLAYTIME_MILESTONE_1H = PLAYTIME_MILESTONE_1H,
	PLAYTIME_MILESTONE_5H = PLAYTIME_MILESTONE_5H,
	SURVIVAL_BONUS_3M = SURVIVAL_BONUS_3M,
	SURVIVAL_BONUS_10M = SURVIVAL_BONUS_10M,
	CROWN_REEVAL_INTERVAL = CROWN_REEVAL_INTERVAL,
	SURVIVAL_SYNC_INTERVAL = SURVIVAL_SYNC_INTERVAL,
	RANKED_ROUND_SEC = RANKED_ROUND_SEC,
	RANKED_POINTS_KILL = RANKED_POINTS_KILL,
	RANKED_POINTS_EVOLUTION = RANKED_POINTS_EVOLUTION,
	RANKED_SURVIVE_SEC = RANKED_SURVIVE_SEC,
	ATTACK_RANGE = ATTACK_RANGE,
	ATTACK_HALF_ARC_DEG = ATTACK_HALF_ARC_DEG,
	TIER_COMBAT = TIER_COMBAT,
	SKINS_COMMON = SKINS_COMMON,
	SKINS_RARE = SKINS_RARE,
	SKINS_EPIC = SKINS_EPIC,
	SKINS_LEGENDARY = SKINS_LEGENDARY,
	FOOD_MAX_COUNT = FOOD_MAX_COUNT,
	FOOD_SPAWN_INTERVAL_SEC = FOOD_SPAWN_INTERVAL_SEC,
	FOOD_SPAWN_RANGE = FOOD_SPAWN_RANGE,
	FOOD_SPAWN_Y = FOOD_SPAWN_Y,
	FOOD_INITIAL_SPAWN_COUNT = FOOD_INITIAL_SPAWN_COUNT,
	FOOD_REPLENISH_AFTER_EAT_SEC = FOOD_REPLENISH_AFTER_EAT_SEC,
	pointsUpdate = pointsUpdate,
	levelUp = levelUp,
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
	useAbility = useAbility,
	abilityFeedback = abilityFeedback,
	playerPoints = {},
	playerLevel = {},
	pendingEvolution = {},
	playerAnimal = {},
	playerHasVoidApex = {},
	playerKills = {},
	playerLastAttack = {},
	playerTitle = {},
	lastBotMeleeTime = {},
	playerSkins = {},
	lastPlayerChestOpenTime = {},
	lastChestProximityAttempt = {},
	playerCoins = {},
	playerPlaytimeAccumSec = {},
	playerHeartbeatConn = {},
	playerSessionPlaytimeTotal = {},
	playerPlaytimeMilestonesDone = {},
	playerSurvivalSec = {},
	playerLastSurvivalStreakSync = {},
	playerRankedPoints = {},
	playerRankedSurvivalAccum = {},
	playerRankedWinStreak = {},
	playerRankedWins = {},
	playerMenuUnlocked = {},
	playerJoinTime = {},
	playerAbilityNextReadyAt = {},
	playerScurryUntil = {},
	playerPoisonUntil = {},
	playerPoisonTickAccum = {},
}

ChestSystem.mount(G)
RankedSystem.mount(G)
ProgressionSystem.mount(G)
CombatSystem.mount(G)
FoodSystem.mount(G)

local function applyMenuMovementUnlock(plr: Player)
	local ch = plr.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.WalkSpeed = DEFAULT_PLAYER_WALK_SPEED
		hum.JumpPower = DEFAULT_PLAYER_JUMP_POWER
	end
end

local function datastoreKeyForPlayer(player: Player): string
	return "u_" .. tostring(player.UserId)
end

local function cloneSkinInventory(raw: any): { [string]: { level: number, rarity: string } }
	local out: { [string]: { level: number, rarity: string } } = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for skinName, entry in pairs(raw :: { [any]: any }) do
		if typeof(skinName) == "string" and typeof(entry) == "table" then
			local e = entry :: { [string]: any }
			local lv = e.level
			local rr = e.rarity
			if typeof(lv) == "number" and typeof(rr) == "string" then
				out[skinName] = {
					level = math.clamp(math.floor(lv), 1, SKIN_MAX_LEVEL),
					rarity = rr,
				}
			end
		end
	end
	return out
end

local function cloneMilestones(raw: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for k, v in pairs(raw :: { [any]: any }) do
		if typeof(k) == "string" and v == true then
			out[k] = true
		end
	end
	return out
end

local function mergeProfileFromStore(raw: any): { [string]: any }
	local merged: { [string]: any } = {
		level = DEFAULT_DATA.level,
		points = DEFAULT_DATA.points,
		kills = DEFAULT_DATA.kills,
		killTitle = DEFAULT_DATA.killTitle,
		coins = DEFAULT_DATA.coins,
		skins = {},
		totalPlaytime = DEFAULT_DATA.totalPlaytime,
		rankedWins = DEFAULT_DATA.rankedWins,
		rankedWinStreak = DEFAULT_DATA.rankedWinStreak,
		currentAnimal = DEFAULT_DATA.currentAnimal,
		voidApex = false,
		playtimeMilestones = {},
	}
	local storedTitle: string? = nil
	if typeof(raw) == "table" then
		local t = raw :: { [string]: any }
		if typeof(t.kills) == "number" and t.kills == t.kills and t.kills >= 0 then
			merged.kills = math.min(math.floor(t.kills), 100_000)
		end
		if typeof(t.coins) == "number" and t.coins == t.coins and t.coins >= 0 then
			merged.coins = math.min(math.floor(t.coins), 10_000_000)
		end
		if typeof(t.totalPlaytime) == "number" and t.totalPlaytime == t.totalPlaytime and t.totalPlaytime >= 0 then
			merged.totalPlaytime = math.min(t.totalPlaytime, 1e8)
		end
		if typeof(t.rankedWinStreak) == "number" and t.rankedWinStreak == t.rankedWinStreak and t.rankedWinStreak >= 0 then
			merged.rankedWinStreak = math.min(math.floor(t.rankedWinStreak), 10_000)
		end
		if typeof(t.killTitle) == "string" and t.killTitle ~= "" then
			storedTitle = t.killTitle :: string
		end
		merged.skins = cloneSkinInventory(t.skins)
	end
	merged.points = 0
	merged.level = G.getLevelFromPoints(0)
	merged.rankedWins = 0
	merged.currentAnimal = AnimalPools.getDefaultAnimalNameForLevel(merged.level :: number)
	merged.voidApex = false
	merged.playtimeMilestones = {}
	merged.killTitle = if storedTitle then storedTitle :: string else G.titleFromKills(merged.kills :: number)
	return merged
end

local function loadData(player: Player)
	local key = datastoreKeyForPlayer(player)
	local ok, raw = pcall(function()
		return playerDataStore:GetAsync(key)
	end)
	local hadStored = ok and typeof(raw) == "table"
	if not ok then
		warn("[DataStore] GetAsync failed for " .. player.Name .. ": ", raw)
	end
	local data = mergeProfileFromStore(if hadStored then raw else nil)

	G.playerPoints[player] = data.points
	G.playerLevel[player] = data.level
	G.playerKills[player] = data.kills
	G.playerTitle[player] = data.killTitle
	G.playerCoins[player] = data.coins
	G.playerSkins[player] = cloneSkinInventory(data.skins)
	G.playerSessionPlaytimeTotal[player] = data.totalPlaytime
	G.playerRankedWins[player] = data.rankedWins
	G.playerRankedWinStreak[player] = data.rankedWinStreak
	G.playerAnimal[player] = data.currentAnimal
	G.playerHasVoidApex[player] = data.voidApex == true
	G.playerPlaytimeMilestonesDone[player] = cloneMilestones(data.playtimeMilestones)

	G.playerLastAttack[player] = 0
	G.playerPlaytimeAccumSec[player] = 0
	G.playerSurvivalSec[player] = 0
	G.playerLastSurvivalStreakSync[player] = 0
	G.playerRankedPoints[player] = 0
	G.playerRankedSurvivalAccum[player] = 0
	G.pendingEvolution[player] = nil

	if hadStored then
		print("Loaded data for " .. player.Name)
	elseif ok then
		print("New player " .. player.Name .. ", using defaults")
	else
		print("New player " .. player.Name .. ", using defaults (load failed)")
	end

	G.playerMenuUnlocked[player] = false
	G.playerJoinTime[player] = tick()
	task.delay(30, function()
		if not player.Parent then
			return
		end
		if G.playerMenuUnlocked[player] == true then
			return
		end
		G.playerMenuUnlocked[player] = true
		applyMenuMovementUnlock(player)
	end)
end

local function saveData(player: Player)
	if G.playerPoints[player] == nil then
		return
	end
	local key = datastoreKeyForPlayer(player)
	local blob: { [string]: any } = {
		kills = G.playerKills[player] or 0,
		killTitle = G.playerTitle[player] or G.titleFromKills(G.playerKills[player] or 0),
		coins = G.playerCoins[player] or 0,
		skins = cloneSkinInventory(G.playerSkins[player] or {}),
		totalPlaytime = G.playerSessionPlaytimeTotal[player] or 0,
		rankedWinStreak = G.playerRankedWinStreak[player] or 0,
	}
	local ok, err = pcall(function()
		playerDataStore:SetAsync(key, blob)
	end)
	if ok then
		print("Saved data for " .. player.Name)
	else
		warn("[DataStore] SetAsync failed for " .. player.Name .. ": ", err)
	end
end

local function onPlayerAdded(player: Player)
	loadData(player)

	local pts = G.playerPoints[player] or 0
	local lv = G.playerLevel[player] or 1
	print(player.Name .. " joined. Points: " .. tostring(pts))
	pointsUpdate:FireClient(player, pts, lv)
	titleSync:FireClient(player, G.playerTitle[player] :: string)
	ChestSystem.syncSkinInventory(player)
	coinsUpdated:FireClient(player, G.playerCoins[player] or 0)
	survivalStreakSync:FireClient(player, 0)
	rankedTimerSync:FireClient(player, RankedSystem.getRankedTimeRemainingSec())

	local function onCharacterAdded(character: Model)
		ProgressionSystem.onCharacterAdded(player, character)

		local rootPart = character:WaitForChild("HumanoidRootPart")

		local oldHb = G.playerHeartbeatConn[player]
		if oldHb then
			oldHb:Disconnect()
			G.playerHeartbeatConn[player] = nil
		end

		G.playerHeartbeatConn[player] = RunService.Heartbeat:Connect(function(dt: number)
			if not character or not character.Parent then
				return
			end

			local hum = character:FindFirstChildOfClass("Humanoid")
			if not hum then
				return
			end

			ProgressionSystem.characterHeartbeatStep(player, character, hum, dt)

			local nowT = tick()
			if hum.Health > 0 then
				CombatSystem.characterPoisonStep(player, character, hum, nowT, dt)
				ProgressionSystem.menuMovementStep(player, hum, nowT)
			end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				G.tryOpenNearbyChest(player, (hrp :: BasePart).Position)
			else
				G.tryOpenNearbyChest(player, rootPart.Position)
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.defer(onCharacterAdded, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	saveData(player)
	G.playerPoints[player] = nil
	G.playerLevel[player] = nil
	G.pendingEvolution[player] = nil
	G.playerAnimal[player] = nil
	G.playerHasVoidApex[player] = nil
	G.playerKills[player] = nil
	G.playerLastAttack[player] = nil
	G.playerTitle[player] = nil
	G.playerSkins[player] = nil
	G.lastPlayerChestOpenTime[player] = nil
	G.playerCoins[player] = nil
	G.playerPlaytimeAccumSec[player] = nil
	G.playerSessionPlaytimeTotal[player] = nil
	G.playerPlaytimeMilestonesDone[player] = nil
	G.playerSurvivalSec[player] = nil
	G.playerLastSurvivalStreakSync[player] = nil
	G.playerRankedPoints[player] = nil
	G.playerRankedSurvivalAccum[player] = nil
	G.playerRankedWinStreak[player] = nil
	G.playerRankedWins[player] = nil
	ProgressionSystem.onPlayerRemovingCrown(player)
	local hb = G.playerHeartbeatConn[player]
	if hb then
		hb:Disconnect()
	end
	G.playerHeartbeatConn[player] = nil
	G.playerMenuUnlocked[player] = nil
	G.playerJoinTime[player] = nil
	G.playerAbilityNextReadyAt[player] = nil
	G.playerScurryUntil[player] = nil
	G.playerPoisonUntil[player] = nil
	G.playerPoisonTickAccum[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

task.spawn(function()
	while true do
		task.wait(300)
		for _, plr in ipairs(Players:GetPlayers()) do
			saveData(plr)
		end
	end
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		saveData(plr)
	end
	task.wait(2)
end)

playerStartedGame.OnServerEvent:Connect(function(player: Player, rankedMode: unknown?)
	if not player.Parent then
		return
	end
	if G.playerPoints[player] == nil then
		G.playerPoints[player] = 0
	end
	if G.playerLevel[player] == nil then
		G.playerLevel[player] = 1
	end
	G.playerMenuUnlocked[player] = true
	player:SetAttribute("MenuRankedChoice", rankedMode == true)
	applyMenuMovementUnlock(player)
end)

getPlayerStats.OnServerInvoke = function(player: Player)
	if G.playerPoints[player] == nil then
		return {}
	end
	local pts = G.playerPoints[player] or 0
	return {
		level = G.getLevelFromPoints(pts),
		animal = G.playerAnimal[player] or "—",
		killTitle = G.playerTitle[player] or G.titleFromKills(G.playerKills[player] or 0),
		kills = G.playerKills[player] or 0,
		coins = G.playerCoins[player] or 0,
		points = pts,
	}
end

getLeaderboard.OnServerInvoke = function(_player: Player)
	local rows: { { userId: number, name: string, killTitle: string, kills: number } } = {}
	for _, plr in Players:GetPlayers() do
		if G.playerKills[plr] ~= nil then
			table.insert(rows, {
				userId = plr.UserId,
				name = plr.Name,
				killTitle = G.playerTitle[plr] or G.titleFromKills(G.playerKills[plr] or 0),
				kills = G.playerKills[plr] or 0,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.userId < b.userId
	end)
	local out = {}
	for i = 1, math.min(5, #rows) do
		out[i] = rows[i]
	end
	return out
end

Bots.setup({
	foodFolder = G.foodFolder,
	mapHalf = MAP_SIZE,
	foodRespawnDelay = RESPAWN_DELAY,
	spawnFood = FoodSystem.spawnFoodPellet,
	getNearestPlayerRoot = G.getNearestPlayerRoot,
	damagePlayerFromBot = G.damagePlayerFromBot,
	tryBotMelee = G.tryBotMelee,
	onBotUnregistered = function(m: Model)
		G.lastBotMeleeTime[m] = nil
	end,
})

task.defer(function()
	Bots.ensureComposition()
end)

RunService.Heartbeat:Connect(function(dt: number)
	Bots.onHeartbeat(dt)
end)

task.spawn(function()
	while true do
		task.wait(12)
		Bots.ensureComposition()
	end
end)
