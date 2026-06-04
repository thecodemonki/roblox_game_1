-- Evolve Game Server
-- Phase 1: Food spawning + points system + basic combat

print("Server script loaded successfully")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local Bots = require(script:WaitForChild("Bots"))
local AnimalAppearance = require(script:WaitForChild("AnimalAppearance"))

local EVOLUTION_FF_NAME = "EvolutionPickShield"

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

-- Smallest point total that yields `targetLevel` under getLevelFromPoints.
local function getMinPointsForLevel(targetLevel: number): number
	if targetLevel <= 1 then
		return 0
	end
	for p = 0, 800 do
		if getLevelFromPoints(p) == targetLevel then
			return p
		end
	end
	return 0
end

-- Config
local MAP_SIZE = 400         -- half-width in studs (800x800 play area; matches Forest floor)
local MAP_SURFACE_Y = 0      -- top of Workspace.Ground from MapSetup.server
local DEFAULT_PLAYER_WALK_SPEED = 16
local POINTS_PER_FOOD = 1    -- points per pellet eaten
local POINTS_PER_KILL = 15
local BOT_MELEE_COOLDOWN = 1.5
local RESPAWN_DELAY = 3      -- bot eat → delayed respawn via Bots.spawnFood
local CHEST_COUNT = 5
local CHEST_OPEN_RANGE = 5
local CHEST_OPEN_COOLDOWN_SEC = 2 -- any chest (world or shop) per player
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
local ATTACK_HALF_ARC_DEG = 90 -- 180° total in front

local TIER_COMBAT: { [number]: { damage: number, cooldown: number } } = {
	[1] = { damage = 10, cooldown = 1.0 },
	[2] = { damage = 18, cooldown = 0.9 },
	[3] = { damage = 28, cooldown = 0.8 },
	[4] = { damage = 40, cooldown = 0.75 },
	[5] = { damage = 52, cooldown = 0.7 },
	[6] = { damage = 65, cooldown = 0.65 },
	[7] = { damage = 80, cooldown = 0.55 },
}

-- Kill titles (milestones); playerKills persists through death.
local TITLE_MILESTONES = {
	{ k = 0, title = "Fresh Prey" },
	{ k = 5, title = "Scavenger" },
	{ k = 25, title = "Pack Hunter" },
	{ k = 100, title = "Apex" },
	{ k = 300, title = "Shadow Predator" },
	{ k = 750, title = "Void Hunter" },
	{ k = 2000, title = "Extinction Event", extinction = true },
	{ k = 5000, title = "The Last Predator", lastPredator = true },
}

-- Storage
local playerPoints = {}
local playerLevel = {} -- last synced level (for LevelUp detection)
local pendingEvolution: { [Player]: { choices: { { name: string, ability: string } }, expires: number } } = {}
local playerAnimal: { [Player]: string } = {}
local playerHasVoidApex: { [Player]: boolean } = {}
-- Kill title progress: persists through death (handlePlayerDeath does not reset this).
local playerKills: { [Player]: number } = {}
local playerLastAttack: { [Player]: number } = {}
local playerTitle: { [Player]: string } = {}
local lastBotMeleeTime: { [Model]: number } = {}
-- Skins: per player map skinName -> { level, rarity }
local playerSkins: { [Player]: { [string]: { level: number, rarity: string } } } = {}
local lastPlayerChestOpenTime: { [Player]: number } = {}
local lastChestProximityAttempt: { [BasePart]: number } = {}
local playerCoins: { [Player]: number } = {}
local playerPlaytimeAccumSec: { [Player]: number } = {}
local playerHeartbeatConn: { [Player]: RBXScriptConnection? } = {}
-- Monotonic session seconds (alive only); used for one-time playtime milestone rewards.
local playerSessionPlaytimeTotal: { [Player]: number } = {}
local playerPlaytimeMilestonesDone: { [Player]: { [string]: boolean } } = {}
-- Current life survival streak (seconds); resets on death.
local playerSurvivalSec: { [Player]: number } = {}
local playerLastSurvivalStreakSync: { [Player]: number } = {}

local function voidApexActive(player: Player): boolean
	return playerHasVoidApex[player] == true
end

local function applyStoredAnimalLook(player: Player, character: Model?)
	local ch = character or player.Character
	local name = playerAnimal[player]
	if not ch or not name or playerPoints[player] == nil then
		return
	end
	local lv = getLevelFromPoints(playerPoints[player] or 0)
	AnimalAppearance.applyFullDeferred(ch, name, lv, voidApexActive(player))
end

local function updateAnimalOverheadForPlayer(player: Player)
	local ch = player.Character
	local name = playerAnimal[player]
	if not ch or not name or playerPoints[player] == nil then
		return
	end
	local lv = getLevelFromPoints(playerPoints[player] or 0)
	AnimalAppearance.updateOverheadTextOnly(ch, name, lv)
end

-- Rolling 15-minute ranked rounds (separate score from endless).
local rankedRoundStart = tick()
local lastRankedRoundIndex = 0
local playerRankedPoints: { [Player]: number } = {}
local playerRankedSurvivalAccum: { [Player]: number } = {}
local playerRankedWinStreak: { [Player]: number } = {}

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

local function addPickShield(player: Player)
	local character = player.Character
	if not character then
		return
	end
	if character:FindFirstChild(EVOLUTION_FF_NAME) then
		return
	end
	local ff = Instance.new("ForceField")
	ff.Name = EVOLUTION_FF_NAME
	ff.Parent = character
end

local function removePickShield(character: Model)
	local ff = character:FindFirstChild(EVOLUTION_FF_NAME)
	if ff then
		ff:Destroy()
	end
end

local function applyPacifistGlow(character: Model)
	local existing = character:FindFirstChild("EvolutionPacifistGlow")
	if existing then
		existing:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "EvolutionPacifistGlow"
	h.FillColor = Color3.fromRGB(255, 220, 50)
	h.OutlineColor = Color3.fromRGB(255, 200, 0)
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0.3
	h.Parent = character
	task.delay(3, function()
		if h.Parent then
			h:Destroy()
		end
	end)
end

local function flashCombatHit(character: Model)
	local existing = character:FindFirstChild("CombatHitFlash")
	if existing then
		existing:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "CombatHitFlash"
	h.FillColor = Color3.fromRGB(255, 40, 40)
	h.OutlineColor = Color3.fromRGB(180, 0, 0)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 0.2
	h.Parent = character
	task.delay(0.15, function()
		if h.Parent then
			h:Destroy()
		end
	end)
end

local function showFloatingDamage(root: BasePart, amount: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageNumber"
	bb.Size = UDim2.fromOffset(80, 40)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = root

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "-" .. tostring(math.floor(amount))
	tl.TextColor3 = Color3.fromRGB(255, 230, 120)
	tl.TextStrokeTransparency = 0.3
	tl.Font = Enum.Font.GothamBlack
	tl.TextSize = 28
	tl.Parent = bb

	task.delay(1.1, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

-- Food folder + steady spawning (single script; no separate FoodSpawner).
local FOOD_FOLDER_NAME = "Food"
local FOOD_MAX_COUNT = 80
local FOOD_SPAWN_INTERVAL_SEC = 1.5
local FOOD_SPAWN_RANGE = 350
local FOOD_SIZE = 2.5
local FOOD_SPAWN_Y = 2
local FOOD_INITIAL_SPAWN_COUNT = 10
local FOOD_REPLENISH_AFTER_EAT_SEC = 1.5

local foodFolder = workspace:FindFirstChild(FOOD_FOLDER_NAME)
if not foodFolder then
	foodFolder = Instance.new("Folder")
	foodFolder.Name = FOOD_FOLDER_NAME
	foodFolder.Parent = workspace
end
if not foodFolder:IsA("Folder") then
	error("[Food] Workspace." .. FOOD_FOLDER_NAME .. " must be a Folder")
end
foodFolder = foodFolder :: Folder

local function spawnFoodPellet()
	if #foodFolder:GetChildren() >= FOOD_MAX_COUNT then
		return
	end
	local pellet = Instance.new("Part")
	pellet.Name = "FoodPellet"
	pellet.Shape = Enum.PartType.Ball
	pellet.Size = Vector3.new(FOOD_SIZE, FOOD_SIZE, FOOD_SIZE)
	pellet.Position = Vector3.new(
		math.random(-FOOD_SPAWN_RANGE, FOOD_SPAWN_RANGE),
		FOOD_SPAWN_Y,
		math.random(-FOOD_SPAWN_RANGE, FOOD_SPAWN_RANGE)
	)
	pellet.Anchored = true
	pellet.CanCollide = false
	pellet.Transparency = 0
	pellet.Color = Color3.fromRGB(255, 200, 50)
	pellet.Material = Enum.Material.Neon
	pellet:SetAttribute("FoodPickup", true)
	pellet.Parent = foodFolder
end

for _ = 1, FOOD_INITIAL_SPAWN_COUNT do
	spawnFoodPellet()
end

task.spawn(function()
	while true do
		spawnFoodPellet()
		task.wait(FOOD_SPAWN_INTERVAL_SEC)
	end
end)

print("[Server] Food folder: " .. foodFolder:GetFullName() .. " (" .. tostring(#foodFolder:GetChildren()) .. " pellets after initial spawn)")

-- Chests (glowing gold) + skin drops
local chestFolder = Instance.new("Folder")
chestFolder.Name = "Chests"
chestFolder.Parent = workspace

local chestSlots: { BasePart? } = {}

local function randomChestPosition(): Vector3
	return Vector3.new(
		math.random(-MAP_SIZE, MAP_SIZE),
		MAP_SURFACE_Y + CHEST_SIZE / 2,
		math.random(-MAP_SIZE, MAP_SIZE)
	)
end

local function buildChestPart(): BasePart
	local p = Instance.new("Part")
	p.Name = "TreasureChest"
	p.Size = Vector3.new(CHEST_SIZE, CHEST_SIZE, CHEST_SIZE)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 210, 55)
	p:SetAttribute("Available", true)
	local light = Instance.new("PointLight")
	light.Name = "ChestGlow"
	light.Color = p.Color
	light.Brightness = 1.8
	light.Range = 24
	light.Parent = p
	return p
end

local function spawnChestAtSlot(slotIndex: number)
	local old = chestSlots[slotIndex]
	if old and old.Parent then
		old:Destroy()
	end
	local p = buildChestPart()
	p.Position = randomChestPosition()
	p.Parent = chestFolder
	chestSlots[slotIndex] = p
end

for slot = 1, CHEST_COUNT do
	spawnChestAtSlot(slot)
end

-- World chest + shop "Common" chest: 60% / 25% / 12% / 3%
local function rollRandomSkinWorld(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 60 then
		rarity = "Common"
		pool = SKINS_COMMON
	elseif r <= 85 then
		rarity = "Rare"
		pool = SKINS_RARE
	elseif r <= 97 then
		rarity = "Epic"
		pool = SKINS_EPIC
	else
		rarity = "Legendary"
		pool = SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

-- Shop "Rare" chest: 20% / 50% / 25% / 5%
local function rollRandomSkinShopRare(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 20 then
		rarity = "Common"
		pool = SKINS_COMMON
	elseif r <= 70 then
		rarity = "Rare"
		pool = SKINS_RARE
	elseif r <= 95 then
		rarity = "Epic"
		pool = SKINS_EPIC
	else
		rarity = "Legendary"
		pool = SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

-- Playtime 1h reward: favor Epic (Common 10%, Rare 20%, Epic 55%, Legendary 15%)
local function rollPlaytimeEpicChest(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 10 then
		rarity = "Common"
		pool = SKINS_COMMON
	elseif r <= 30 then
		rarity = "Rare"
		pool = SKINS_RARE
	elseif r <= 85 then
		rarity = "Epic"
		pool = SKINS_EPIC
	else
		rarity = "Legendary"
		pool = SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

local function getSkinListSerializable(player: Player): { { name: string, rarity: string, level: number } }
	local inv = playerSkins[player]
	local out: { { name: string, rarity: string, level: number } } = {}
	if not inv then
		return out
	end
	for skinName, entry in pairs(inv) do
		table.insert(out, {
			name = skinName,
			rarity = entry.rarity,
			level = entry.level,
		})
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

local function syncSkinInventory(player: Player)
	if playerSkins[player] ~= nil then
		skinInventorySync:FireClient(player, getSkinListSerializable(player))
	end
end

-- kind: "new" | "level_up" | "duplicate_max"
local function grantSkinFromRoll(player: Player, skinName: string, rolledRarity: string)
	local inv = playerSkins[player]
	if not inv then
		return
	end
	local existing = inv[skinName]
	local rarity: string
	local level: number
	local kind: string
	if existing then
		rarity = existing.rarity
		if existing.level < SKIN_MAX_LEVEL then
			existing.level = existing.level + 1
			level = existing.level
			kind = "level_up"
		else
			level = existing.level
			kind = "duplicate_max"
		end
	else
		inv[skinName] = { level = 1, rarity = rolledRarity }
		rarity = rolledRarity
		level = 1
		kind = "new"
	end
	skinReceived:FireClient(player, skinName, rarity, level, kind)
	syncSkinInventory(player)
end

local function grantRandomSkinFromChest(player: Player)
	local skinName, rolledRarity = rollRandomSkinWorld()
	grantSkinFromRoll(player, skinName, rolledRarity)
end

local function tryOpenNearbyChest(player: Player, rootPos: Vector3)
	local now = tick()
	if now - (lastPlayerChestOpenTime[player] or 0) < CHEST_OPEN_COOLDOWN_SEC then
		return
	end
	for slot = 1, CHEST_COUNT do
		local ch = chestSlots[slot]
		if ch and ch.Parent and ch:GetAttribute("Available") == true then
			if now - (lastChestProximityAttempt[ch] or 0) < CHEST_SAME_PART_DEBOUNCE_SEC then
				continue
			end
			if (ch.Position - rootPos).Magnitude <= CHEST_OPEN_RANGE then
				lastChestProximityAttempt[ch] = now
				lastPlayerChestOpenTime[player] = now
				ch:SetAttribute("Available", false)
				ch:Destroy()
				chestSlots[slot] = nil
				grantRandomSkinFromChest(player)
				task.delay(CHEST_RESPAWN_SEC, function()
					if chestFolder.Parent then
						spawnChestAtSlot(slot)
					end
				end)
				return
			end
		end
	end
end

local crownLeader: Player? = nil
local lastCrownHeartbeatEval = 0

local function destroyCrownOnCharacter(character: Model)
	for _, d in character:GetDescendants() do
		if d.Name == "SurvivalCrown" and d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
end

local function attachCrownToCharacter(character: Model)
	destroyCrownOnCharacter(character)
	local head = character:FindFirstChild("Head") :: BasePart?
	local adornee = head or character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "SurvivalCrown"
	bb.Size = UDim2.fromOffset(72, 56)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = adornee
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "\u{1F451}"
	tl.TextScaled = true
	tl.Parent = bb
end

local function pickSurvivalLeaderPlayer(): Player?
	local bestP: Player? = nil
	local bestS = -1
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if playerPoints[plr] ~= nil and ch and hum and hum.Health > 0 then
			local s = playerSurvivalSec[plr] or 0
			if s > bestS then
				bestS = s
				bestP = plr
			elseif s == bestS and s > 0 then
				if bestP == nil or plr.UserId < bestP.UserId then
					bestP = plr
				end
			end
		end
	end
	if bestS <= 0 then
		return nil
	end
	return bestP
end

local function updateSurvivalCrownCore()
	local newLeader = pickSurvivalLeaderPlayer()
	if newLeader == crownLeader then
		if newLeader then
			local ch = newLeader.Character
			if ch and not ch:FindFirstChild("SurvivalCrown", true) then
				attachCrownToCharacter(ch)
			end
		end
		return
	end
	if crownLeader then
		local oldCh = crownLeader.Character
		if oldCh then
			destroyCrownOnCharacter(oldCh)
		end
	end
	crownLeader = newLeader
	if crownLeader then
		local ch = crownLeader.Character
		if ch then
			attachCrownToCharacter(ch)
		end
	end
end

local function updateSurvivalCrownThrottled()
	local t = tick()
	if t - lastCrownHeartbeatEval < CROWN_REEVAL_INTERVAL then
		return
	end
	lastCrownHeartbeatEval = t
	updateSurvivalCrownCore()
end

local function handlePlayerDeath(player: Player, character: Model)
	if playerPoints[player] == nil then
		return
	end

	playerSurvivalSec[player] = 0
	survivalStreakSync:FireClient(player, 0)

	local currentLevel = getLevelFromPoints(playerPoints[player])
	local newLevel = math.max(1, currentLevel - 2)
	local newPoints = getMinPointsForLevel(newLevel)
	local defaultAnimal = AnimalPools.getDefaultAnimalNameForLevel(newLevel)

	pendingEvolution[player] = nil
	removePickShield(character)

	playerPoints[player] = newPoints
	playerLevel[player] = newLevel
	playerAnimal[player] = defaultAnimal

	pointsUpdate:FireClient(player, newPoints, newLevel)
	playerDied:FireClient(player, newLevel, defaultAnimal)
	updateSurvivalCrownCore()
end

local function addCoins(player: Player, delta: number)
	if playerCoins[player] == nil then
		return
	end
	playerCoins[player] = playerCoins[player] + delta
	coinsUpdated:FireClient(player, playerCoins[player])
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
		addCoins(player, COINS_PER_LEVEL_UP)
		local choices = AnimalPools.sampleChoicesForLevel(newLevel)
		local tierShown = AnimalPools.getTierForLevel(newLevel)
		print(string.format("%s leveled up to level %d, showing tier %d animals", player.Name, newLevel, tierShown))
		pendingEvolution[player] = {
			choices = choices,
			expires = tick() + 60,
		}
		addPickShield(player)
		levelUp:FireClient(player, newLevel, choices)
	else
		playerLevel[player] = newLevel
	end
	updateAnimalOverheadForPlayer(player)
end

-- Give points to player
local function addPoints(player, amount)
	if playerPoints[player] then
		playerPoints[player] = playerPoints[player] + amount
		print(player.Name .. " has " .. playerPoints[player] .. " points")
		syncPointsAndLevel(player)
	end
end

local function checkPlaytimeMilestones(player: Player, oldT: number, newT: number)
	local m = playerPlaytimeMilestonesDone[player]
	if not m then
		return
	end
	if not m["5m"] and oldT < PLAYTIME_MILESTONE_5M and newT >= PLAYTIME_MILESTONE_5M then
		m["5m"] = true
		local sn, rr = rollRandomSkinWorld()
		grantSkinFromRoll(player, sn, rr)
	end
	if not m["20m"] and oldT < PLAYTIME_MILESTONE_20M and newT >= PLAYTIME_MILESTONE_20M then
		m["20m"] = true
		local sn, rr = rollRandomSkinShopRare()
		grantSkinFromRoll(player, sn, rr)
		addCoins(player, 25)
	end
	if not m["1h"] and oldT < PLAYTIME_MILESTONE_1H and newT >= PLAYTIME_MILESTONE_1H then
		m["1h"] = true
		local sn, rr = rollPlaytimeEpicChest()
		grantSkinFromRoll(player, sn, rr)
	end
	if not m["5h"] and oldT < PLAYTIME_MILESTONE_5H and newT >= PLAYTIME_MILESTONE_5H then
		m["5h"] = true
		local sn = SKINS_RARE[math.random(1, #SKINS_RARE)]
		grantSkinFromRoll(player, sn, "Rare")
	end
end

local function checkSurvivalMilestones(player: Player, prevS: number, newS: number)
	if playerPoints[player] == nil then
		return
	end
	if prevS < SURVIVAL_BONUS_3M and newS >= SURVIVAL_BONUS_3M then
		addPoints(player, 10)
		survivalBonus:FireClient(player, "3 min survival! +10 points")
	end
	if prevS < SURVIVAL_BONUS_10M and newS >= SURVIVAL_BONUS_10M then
		addPoints(player, 30)
		addCoins(player, 10)
		survivalBonus:FireClient(player, "10 min survival! +30 points +10 coins")
	end
end

local function addRankedPoints(player: Player, delta: number)
	if playerRankedPoints[player] == nil or delta == 0 then
		return
	end
	playerRankedPoints[player] = (playerRankedPoints[player] :: number) + delta
end

local function getRankedTimeRemainingSec(): number
	local elapsed = (tick() - rankedRoundStart) % RANKED_ROUND_SEC
	return math.max(0, math.floor(RANKED_ROUND_SEC - elapsed))
end

local function endRankedRound()
	local rows: { { p: Player, score: number } } = {}
	for _, plr in Players:GetPlayers() do
		if playerRankedPoints[plr] ~= nil then
			table.insert(rows, { p = plr, score = playerRankedPoints[plr] :: number })
		end
	end
	table.sort(rows, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.p.UserId < b.p.UserId
	end)

	local payload: { { place: number, name: string, score: number, reward: string } } = {}

	for i = 1, math.min(3, #rows) do
		local r = rows[i]
		local rewardLabel: string
		if i == 1 then
			rewardLabel = "Epic chest + 50 coins"
			local sn, rr = rollPlaytimeEpicChest()
			grantSkinFromRoll(r.p, sn, rr)
			addCoins(r.p, 50)
		elseif i == 2 then
			rewardLabel = "Rare chest + 25 coins"
			local sn, rr = rollRandomSkinShopRare()
			grantSkinFromRoll(r.p, sn, rr)
			addCoins(r.p, 25)
		else
			rewardLabel = "Common chest + 10 coins"
			local sn, rr = rollRandomSkinWorld()
			grantSkinFromRoll(r.p, sn, rr)
			addCoins(r.p, 10)
		end
		table.insert(payload, {
			place = i,
			name = r.p.Name,
			score = r.score,
			reward = rewardLabel,
		})
	end

	for _, plr in Players:GetPlayers() do
		if playerRankedWinStreak[plr] == nil then
			continue
		end
		if #rows >= 1 and plr == rows[1].p then
			local w = (playerRankedWinStreak[plr] :: number) + 1
			playerRankedWinStreak[plr] = w
			if w >= 3 then
				voidBeastUnlocked:FireClient(plr)
				playerHasVoidApex[plr] = true
				applyStoredAnimalLook(plr)
				playerRankedWinStreak[plr] = 0
			end
		else
			playerRankedWinStreak[plr] = 0
		end
	end

	roundEnd:FireAllClients(payload)

	for _, plr in Players:GetPlayers() do
		if playerRankedPoints[plr] ~= nil then
			playerRankedPoints[plr] = 0
			playerRankedSurvivalAccum[plr] = 0
		end
	end
end

local function getCombatStatsForPlayer(player: Player): (number, number)
	local level = getLevelFromPoints(playerPoints[player] or 0)
	local tier = AnimalPools.getTierForLevel(level)
	local row = TIER_COMBAT[tier] or TIER_COMBAT[3]
	return row.damage, row.cooldown
end

local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function isTargetInMeleeCone(attackerRoot: BasePart, targetPosition: Vector3): boolean
	local delta = targetPosition - attackerRoot.Position
	local dist = delta.Magnitude
	if dist > ATTACK_RANGE then
		return false
	end
	local forward = flatUnit(attackerRoot.CFrame.LookVector)
	if not forward then
		return false
	end
	local toTarget = flatUnit(delta)
	if not toTarget then
		return true
	end
	local dot = math.clamp(forward:Dot(toTarget), -1, 1)
	local ang = math.deg(math.acos(dot))
	return ang <= ATTACK_HALF_ARC_DEG
end

local function titleFromKills(kills: number): string
	local t = "Fresh Prey"
	for _, row in ipairs(TITLE_MILESTONES) do
		if kills >= row.k then
			t = row.title
		end
	end
	return t
end

local function checkKillTitles(player: Player, oldKills: number, newKills: number)
	for _, row in ipairs(TITLE_MILESTONES) do
		if row.k > 0 and newKills >= row.k and oldKills < row.k then
			titleUnlocked:FireClient(player, row.title)
			if row.extinction then
				extinctionEvent:FireAllClients(player.Name)
			end
			if row.lastPredator then
				lastPredator:FireAllClients(player.Name)
			end
		end
	end
	local t = titleFromKills(newKills)
	playerTitle[player] = t
	titleSync:FireClient(player, t)
end

local function getNearestPlayerRoot(fromPos: Vector3, maxDist: number): (Player?, BasePart?)
	local bestP: Player? = nil
	local bestR: BasePart? = nil
	local bestD = maxDist + 1
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		if ch then
			local r = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			local h = ch:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local d = (r.Position - fromPos).Magnitude
				if d <= maxDist and d < bestD then
					bestD = d
					bestP = plr
					bestR = r
				end
			end
		end
	end
	return bestP, bestR
end

local function damagePlayerFromBot(_botModel: Model, target: Player, damage: number)
	local ch = target.Character
	if not ch then
		return
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local rootP = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not rootP or hum.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local pac = target:GetAttribute("PacifistUntil")
	if typeof(pac) == "number" and now < pac then
		return
	end
	local newHealth = hum.Health - damage
	flashCombatHit(ch)
	showFloatingDamage(rootP, damage)
	if newHealth <= 0 then
		hum.Health = 0
	else
		hum.Health = newHealth
	end
end

local function tryBotMelee(botModel: Model, damage: number)
	local tnow = tick()
	local last = lastBotMeleeTime[botModel] or 0
	if tnow - last < BOT_MELEE_COOLDOWN then
		return
	end
	lastBotMeleeTime[botModel] = tnow

	local humB = botModel:FindFirstChildOfClass("Humanoid")
	local rootB = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humB or not rootB or humB.Health <= 0 then
		return
	end

	for _, plr in Players:GetPlayers() do
		if playerPoints[plr] == nil then
			continue
		end
		local ch = plr.Character
		if not ch then
			continue
		end
		local humP = ch:FindFirstChildOfClass("Humanoid")
		local rootP = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humP or not rootP or humP.Health <= 0 then
			continue
		end
		if not isTargetInMeleeCone(rootB, rootP.Position) then
			continue
		end
		damagePlayerFromBot(botModel, plr, damage)
	end
end

local function grantBotKill(attacker: Player, botDisplayName: string)
	local oldK = playerKills[attacker] or 0
	playerKills[attacker] = oldK + 1
	addPoints(attacker, POINTS_PER_KILL)
	playerKilled:FireClient(attacker, "killer", botDisplayName, POINTS_PER_KILL)
	checkKillTitles(attacker, oldK, playerKills[attacker] :: number)
	addCoins(attacker, COINS_PER_KILL)
	addRankedPoints(attacker, RANKED_POINTS_KILL)
end

local function onPlayerKill(attacker: Player, victim: Player)
	local oldK = playerKills[attacker] or 0
	playerKills[attacker] = oldK + 1
	addPoints(attacker, POINTS_PER_KILL)
	playerKilled:FireClient(attacker, "killer", victim.Name, POINTS_PER_KILL)
	playerKilled:FireClient(victim, "victim", attacker.Name)
	checkKillTitles(attacker, oldK, playerKills[attacker] :: number)
	addCoins(attacker, COINS_PER_KILL)
	addRankedPoints(attacker, RANKED_POINTS_KILL)
end

local function tryMeleeAttack(attacker: Player)
	if playerPoints[attacker] == nil then
		return
	end

	local charA = attacker.Character
	if not charA then
		return
	end
	local humA = charA:FindFirstChildOfClass("Humanoid")
	local rootA = charA:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humA or not rootA or humA.Health <= 0 then
		return
	end

	local now = workspace:GetServerTimeNow()
	local pac = attacker:GetAttribute("PacifistUntil")
	if typeof(pac) == "number" and now < pac then
		return
	end

	local damage, cooldown = getCombatStatsForPlayer(attacker)
	local last = playerLastAttack[attacker] or 0
	if tick() - last < cooldown then
		return
	end
	playerLastAttack[attacker] = tick()

	for _, other in Players:GetPlayers() do
		if other == attacker then
			continue
		end
		if playerPoints[other] == nil then
			continue
		end
		local charB = other.Character
		if not charB then
			continue
		end
		local humB = charB:FindFirstChildOfClass("Humanoid")
		local rootB = charB:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humB or not rootB or humB.Health <= 0 then
			continue
		end

		if not isTargetInMeleeCone(rootA, rootB.Position) then
			continue
		end

		local newHealth = humB.Health - damage
		flashCombatHit(charB)
		showFloatingDamage(rootB, damage)

		if newHealth <= 0 then
			onPlayerKill(attacker, other)
			humB.Health = 0
		else
			humB.Health = newHealth
		end
	end

	for _, botModel in ipairs(Bots.iterBotModels()) do
		local humB = botModel:FindFirstChildOfClass("Humanoid")
		local rootB = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humB or not rootB or humB.Health <= 0 then
			continue
		end
		if not isTargetInMeleeCone(rootA, rootB.Position) then
			continue
		end

		Bots.setLastAttacker(botModel, attacker)

		local newHealth = humB.Health - damage
		flashCombatHit(botModel)
		showFloatingDamage(rootB, damage)

		if newHealth <= 0 then
			local dn = botModel:GetAttribute("DisplayBotName")
			local displayName = if typeof(dn) == "string" then dn :: string else botModel.Name
			grantBotKill(attacker, displayName)
			humB.Health = 0
		else
			humB.Health = newHealth
		end
	end
end

-- Setup player when they join
local function onPlayerAdded(player)
	playerPoints[player] = 0
	playerLevel[player] = 1
	playerKills[player] = 0
	playerLastAttack[player] = 0
	playerTitle[player] = titleFromKills(0)
	playerSkins[player] = {}
	playerCoins[player] = 0
	playerPlaytimeAccumSec[player] = 0
	playerSessionPlaytimeTotal[player] = 0
	playerPlaytimeMilestonesDone[player] = {}
	playerSurvivalSec[player] = 0
	playerLastSurvivalStreakSync[player] = 0
	playerRankedPoints[player] = 0
	playerRankedSurvivalAccum[player] = 0
	playerRankedWinStreak[player] = 0
	print(player.Name .. " joined. Points: 0")
	playerHasVoidApex[player] = false
	pointsUpdate:FireClient(player, 0, 1)
	titleSync:FireClient(player, playerTitle[player] :: string)
	syncSkinInventory(player)
	coinsUpdated:FireClient(player, 0)
	survivalStreakSync:FireClient(player, 0)
	rankedTimerSync:FireClient(player, getRankedTimeRemainingSec())

	-- When character spawns
	player.CharacterAdded:Connect(function(character)
		if pendingEvolution[player] then
			task.defer(function()
				addPickShield(player)
			end)
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = 100
		humanoid.Health = 100

		humanoid.Died:Connect(function()
			handlePlayerDeath(player, character)
		end)

		local rootPart = character:WaitForChild("HumanoidRootPart")

		task.defer(function()
			updateSurvivalCrownCore()
		end)

		local oldHb = playerHeartbeatConn[player]
		if oldHb then
			oldHb:Disconnect()
			playerHeartbeatConn[player] = nil
		end

		-- Food, world chests, playtime coins (one loop per active character)
		playerHeartbeatConn[player] = RunService.Heartbeat:Connect(function(dt: number)
			if not character or not character.Parent then
				return
			end

			local acc = (playerPlaytimeAccumSec[player] or 0) + dt
			while acc >= COINS_PLAYTIME_INTERVAL_SEC do
				acc = acc - COINS_PLAYTIME_INTERVAL_SEC
				addCoins(player, COINS_PER_PLAYTIME_BONUS)
			end
			playerPlaytimeAccumSec[player] = acc

			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local oldSess = playerSessionPlaytimeTotal[player] or 0
				local newSess = oldSess + dt
				playerSessionPlaytimeTotal[player] = newSess
				checkPlaytimeMilestones(player, oldSess, newSess)

				local prevSurv = playerSurvivalSec[player] or 0
				local newSurv = prevSurv + dt
				playerSurvivalSec[player] = newSurv
				checkSurvivalMilestones(player, prevSurv, newSurv)

				local nowTick = tick()
				if nowTick - (playerLastSurvivalStreakSync[player] or 0) >= SURVIVAL_SYNC_INTERVAL then
					playerLastSurvivalStreakSync[player] = nowTick
					survivalStreakSync:FireClient(player, math.floor(newSurv))
				end

				local rAcc = (playerRankedSurvivalAccum[player] or 0) + dt
				while rAcc >= RANKED_SURVIVE_SEC do
					rAcc = rAcc - RANKED_SURVIVE_SEC
					addRankedPoints(player, 1)
				end
				playerRankedSurvivalAccum[player] = rAcc

				hum.WalkSpeed = DEFAULT_PLAYER_WALK_SPEED

				updateSurvivalCrownThrottled()
			end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				tryOpenNearbyChest(player, (hrp :: BasePart).Position)
			else
				tryOpenNearbyChest(player, rootPart.Position)
			end
		end)

		task.defer(function()
			applyStoredAnimalLook(player, character)
		end)
	end)
end

-- Cleanup when player leaves
local function onPlayerRemoving(player)
	playerPoints[player] = nil
	playerLevel[player] = nil
	pendingEvolution[player] = nil
	playerAnimal[player] = nil
	playerHasVoidApex[player] = nil
	playerKills[player] = nil
	playerLastAttack[player] = nil
	playerTitle[player] = nil
	playerSkins[player] = nil
	lastPlayerChestOpenTime[player] = nil
	playerCoins[player] = nil
	playerPlaytimeAccumSec[player] = nil
	playerSessionPlaytimeTotal[player] = nil
	playerPlaytimeMilestonesDone[player] = nil
	playerSurvivalSec[player] = nil
	playerLastSurvivalStreakSync[player] = nil
	playerRankedPoints[player] = nil
	playerRankedSurvivalAccum[player] = nil
	playerRankedWinStreak[player] = nil
	if crownLeader == player then
		local ch = player.Character
		if ch then
			destroyCrownOnCharacter(ch)
		end
		crownLeader = nil
	end
	updateSurvivalCrownCore()
	local hb = playerHeartbeatConn[player]
	if hb then
		hb:Disconnect()
	end
	playerHeartbeatConn[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

attackRequest.OnServerEvent:Connect(function(player: Player)
	tryMeleeAttack(player)
end)

animalPicked.OnServerEvent:Connect(function(player: Player, animalName: unknown)
	if typeof(animalName) ~= "string" then
		return
	end
	local pending = pendingEvolution[player]
	if not pending then
		return
	end
	if tick() > pending.expires then
		pendingEvolution[player] = nil
		return
	end
	if not AnimalPools.isNameInChoices(animalName :: string, pending.choices) then
		return
	end
	local lv = getLevelFromPoints(playerPoints[player] or 0)
	if not AnimalPools.isAnimalAllowedAtLevel(animalName :: string, lv) then
		return
	end
	pendingEvolution[player] = nil

	local character = player.Character
	if character then
		removePickShield(character)
	end

	playerAnimal[player] = animalName :: string

	local now = workspace:GetServerTimeNow()
	player:SetAttribute("PacifistUntil", now + 3)

	if character then
		applyPacifistGlow(character)
	end

	addRankedPoints(player, RANKED_POINTS_EVOLUTION)
	applyStoredAnimalLook(player)
end)

animalChanged.OnServerEvent:Connect(function(player: Player, animalName: unknown)
	if typeof(animalName) ~= "string" then
		return
	end
	if playerAnimal[player] ~= animalName :: string then
		return
	end
	applyStoredAnimalLook(player)
end)

purchaseChest.OnServerInvoke = function(player: Player, chestKind: unknown): boolean
	if typeof(chestKind) ~= "string" then
		return false
	end
	local k = chestKind :: string
	if k ~= "Common" and k ~= "Rare" then
		return false
	end
	if playerCoins[player] == nil or playerSkins[player] == nil then
		return false
	end
	if tick() - (lastPlayerChestOpenTime[player] or 0) < CHEST_OPEN_COOLDOWN_SEC then
		return false
	end
	local price = if k == "Rare" then SHOP_CHEST_RARE_PRICE else SHOP_CHEST_COMMON_PRICE
	if playerCoins[player] < price then
		return false
	end
	playerCoins[player] = playerCoins[player] - price
	coinsUpdated:FireClient(player, playerCoins[player])
	lastPlayerChestOpenTime[player] = tick()

	local skinName: string
	local rolledRarity: string
	if k == "Rare" then
		skinName, rolledRarity = rollRandomSkinShopRare()
	else
		skinName, rolledRarity = rollRandomSkinWorld()
	end

	task.defer(function()
		task.wait(0.42)
		if player.Parent and playerSkins[player] then
			grantSkinFromRoll(player, skinName, rolledRarity)
		end
	end)
	return true
end

lastRankedRoundIndex = math.floor((tick() - rankedRoundStart) / RANKED_ROUND_SEC)
task.spawn(function()
	rankedTimerSync:FireAllClients(getRankedTimeRemainingSec())
	while true do
		task.wait(1)
		local idx = math.floor((tick() - rankedRoundStart) / RANKED_ROUND_SEC)
		while lastRankedRoundIndex < idx do
			endRankedRound()
			lastRankedRoundIndex = lastRankedRoundIndex + 1
		end
		rankedTimerSync:FireAllClients(getRankedTimeRemainingSec())
	end
end)

Bots.setup({
	foodFolder = foodFolder,
	mapHalf = MAP_SIZE,
	foodRespawnDelay = RESPAWN_DELAY,
	spawnFood = spawnFoodPellet,
	getNearestPlayerRoot = getNearestPlayerRoot,
	damagePlayerFromBot = damagePlayerFromBot,
	tryBotMelee = tryBotMelee,
	onBotUnregistered = function(m: Model)
		lastBotMeleeTime[m] = nil
	end,
})

task.defer(function()
	Bots.ensureComposition()
end)

RunService.Heartbeat:Connect(function(dt: number)
	Bots.onHeartbeat(dt)
end)

-- Food eating: throttled server tick (not every frame), separate from per-player character Heartbeat.
local foodEatAccum = 0.0
RunService.Heartbeat:Connect(function(dt: number)
	foodEatAccum += dt
	while foodEatAccum >= 0.1 do
		foodEatAccum -= 0.1
		local foodsFolder = workspace:FindFirstChild("Food")
		if not foodsFolder or not foodsFolder:IsA("Folder") then
			continue
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local rootPart = char and char:FindFirstChild("HumanoidRootPart")
			if not rootPart or not rootPart:IsA("BasePart") then
				continue
			end
			local root = rootPart :: BasePart
			for _, food in ipairs(foodsFolder:GetChildren()) do
				if food:IsA("BasePart") and food:GetAttribute("FoodPickup") == true and food.Parent ~= nil then
					local distance = (root.Position - food.Position).Magnitude
					if distance < 5 then
						food:Destroy()
						if playerPoints[player] ~= nil then
							addPoints(player, POINTS_PER_FOOD)
							local total = playerPoints[player] :: number
							local lv = getLevelFromPoints(total)
							pointsUpdate:FireClient(player, total, lv)
							print("Player ate food, points: " .. tostring(total))
							task.delay(FOOD_REPLENISH_AFTER_EAT_SEC, spawnFoodPellet)
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(12)
		Bots.ensureComposition()
	end
end)
