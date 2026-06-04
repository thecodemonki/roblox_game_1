-- Points, levels, evolution flow, kill titles, survival crown, playtime coin accrual hooks.

local ProgressionSystem = {}

local G: any = nil

local EVOLUTION_FF_NAME = "EvolutionPickShield"

local LEVEL_ANCHORS = {
	{ points = 10, level = 2 },
	{ points = 30, level = 5 },
	{ points = 75, level = 10 },
	{ points = 150, level = 18 },
	{ points = 280, level = 28 },
	{ points = 450, level = 40 },
	{ points = 700, level = 55 },
}

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

local crownLeader: Player? = nil
local lastCrownHeartbeatEval = 0

local function voidApexActive(player: Player): boolean
	return G.playerHasVoidApex[player] == true
end

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

local function titleFromKills(kills: number): string
	local t = "Fresh Prey"
	for _, row in ipairs(TITLE_MILESTONES) do
		if kills >= row.k then
			t = row.title
		end
	end
	return t
end

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
	for _, plr in G.Players:GetPlayers() do
		local ch = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if G.playerPoints[plr] ~= nil and ch and hum and hum.Health > 0 then
			local s = G.playerSurvivalSec[plr] or 0
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
	if t - lastCrownHeartbeatEval < G.CROWN_REEVAL_INTERVAL then
		return
	end
	lastCrownHeartbeatEval = t
	updateSurvivalCrownCore()
end

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

local function checkKillTitles(player: Player, oldKills: number, newKills: number)
	for _, row in ipairs(TITLE_MILESTONES) do
		if row.k > 0 and newKills >= row.k and oldKills < row.k then
			G.titleUnlocked:FireClient(player, row.title)
			if row.extinction then
				G.extinctionEvent:FireAllClients(player.Name)
			end
			if row.lastPredator then
				G.lastPredator:FireAllClients(player.Name)
			end
		end
	end
	local t = titleFromKills(newKills)
	G.playerTitle[player] = t
	G.titleSync:FireClient(player, t)
end

function ProgressionSystem.applyStoredAnimalLook(player: Player, character: Model?)
	local ch = character or player.Character
	local name = G.playerAnimal[player]
	if not ch or not name or G.playerPoints[player] == nil then
		return
	end
	local lv = getLevelFromPoints(G.playerPoints[player] or 0)
	G.AnimalAppearance.applyFullDeferred(ch, name, lv, voidApexActive(player))
end

local function updateAnimalOverheadForPlayer(player: Player)
	local ch = player.Character
	local name = G.playerAnimal[player]
	if not ch or not name or G.playerPoints[player] == nil then
		return
	end
	local lv = getLevelFromPoints(G.playerPoints[player] or 0)
	G.AnimalAppearance.updateOverheadTextOnly(ch, name, lv)
end

function ProgressionSystem.addCoins(player: Player, delta: number)
	if G.playerCoins[player] == nil then
		return
	end
	G.playerCoins[player] = G.playerCoins[player] + delta
	G.coinsUpdated:FireClient(player, G.playerCoins[player])
end

local function syncPointsAndLevel(player: Player)
	local points = G.playerPoints[player]
	if points == nil then
		return
	end
	local newLevel = getLevelFromPoints(points)
	G.pointsUpdate:FireClient(player, points, newLevel)
	local prev = G.playerLevel[player] or 1
	if newLevel > prev then
		G.playerLevel[player] = newLevel
		ProgressionSystem.addCoins(player, G.COINS_PER_LEVEL_UP)
		local choices = G.AnimalPools.sampleChoicesForLevel(newLevel)
		local tierShown = G.AnimalPools.getTierForLevel(newLevel)
		print(string.format("%s leveled up to level %d, showing tier %d animals", player.Name, newLevel, tierShown))
		G.pendingEvolution[player] = {
			choices = choices,
			expires = tick() + 60,
		}
		addPickShield(player)
		G.levelUp:FireClient(player, newLevel, choices)
	else
		G.playerLevel[player] = newLevel
	end
	updateAnimalOverheadForPlayer(player)
end

function ProgressionSystem.addPoints(player: Player, amount: number)
	if G.playerPoints[player] then
		G.playerPoints[player] = G.playerPoints[player] + amount
		print(player.Name .. " has " .. G.playerPoints[player] .. " points")
		syncPointsAndLevel(player)
	end
end

local function checkSurvivalMilestones(player: Player, prevS: number, newS: number)
	if G.playerPoints[player] == nil then
		return
	end
	if prevS < G.SURVIVAL_BONUS_3M and newS >= G.SURVIVAL_BONUS_3M then
		ProgressionSystem.addPoints(player, 10)
		G.survivalBonus:FireClient(player, "3 min survival! +10 points")
	end
	if prevS < G.SURVIVAL_BONUS_10M and newS >= G.SURVIVAL_BONUS_10M then
		ProgressionSystem.addPoints(player, 30)
		ProgressionSystem.addCoins(player, 10)
		G.survivalBonus:FireClient(player, "10 min survival! +30 points +10 coins")
	end
end

function ProgressionSystem.handlePlayerDeath(player: Player, character: Model)
	if G.playerPoints[player] == nil then
		return
	end

	G.playerSurvivalSec[player] = 0
	G.survivalStreakSync:FireClient(player, 0)

	local currentLevel = getLevelFromPoints(G.playerPoints[player])
	local newLevel = math.max(1, currentLevel - 2)
	local newPoints = getMinPointsForLevel(newLevel)
	local defaultAnimal = G.AnimalPools.getDefaultAnimalNameForLevel(newLevel)

	G.pendingEvolution[player] = nil
	removePickShield(character)

	G.playerPoints[player] = newPoints
	G.playerLevel[player] = newLevel
	G.playerAnimal[player] = defaultAnimal

	G.pointsUpdate:FireClient(player, newPoints, newLevel)
	G.playerDied:FireClient(player, newLevel, defaultAnimal)
	updateSurvivalCrownCore()
end

function ProgressionSystem.characterHeartbeatStep(player: Player, character: Model, hum: Humanoid, dt: number)
	local acc = (G.playerPlaytimeAccumSec[player] or 0) + dt
	while acc >= G.COINS_PLAYTIME_INTERVAL_SEC do
		acc = acc - G.COINS_PLAYTIME_INTERVAL_SEC
		ProgressionSystem.addCoins(player, G.COINS_PER_PLAYTIME_BONUS)
	end
	G.playerPlaytimeAccumSec[player] = acc

	if hum.Health > 0 then
		local oldSess = G.playerSessionPlaytimeTotal[player] or 0
		local newSess = oldSess + dt
		G.playerSessionPlaytimeTotal[player] = newSess
		G.checkPlaytimeMilestones(player, oldSess, newSess)

		local prevSurv = G.playerSurvivalSec[player] or 0
		local newSurv = prevSurv + dt
		G.playerSurvivalSec[player] = newSurv
		checkSurvivalMilestones(player, prevSurv, newSurv)

		local nowTick = tick()
		if nowTick - (G.playerLastSurvivalStreakSync[player] or 0) >= G.SURVIVAL_SYNC_INTERVAL then
			G.playerLastSurvivalStreakSync[player] = nowTick
			G.survivalStreakSync:FireClient(player, math.floor(newSurv))
		end

		local rAcc = (G.playerRankedSurvivalAccum[player] or 0) + dt
		while rAcc >= G.RANKED_SURVIVE_SEC do
			rAcc = rAcc - G.RANKED_SURVIVE_SEC
			G.addRankedPoints(player, 1)
		end
		G.playerRankedSurvivalAccum[player] = rAcc

		updateSurvivalCrownThrottled()
	end
end

function ProgressionSystem.menuMovementStep(player: Player, hum: Humanoid, nowT: number)
	if G.playerMenuUnlocked[player] == true then
		local scurryT = G.playerScurryUntil[player]
		if scurryT and nowT < scurryT then
			hum.WalkSpeed = G.DEFAULT_PLAYER_WALK_SPEED * 2
		else
			if scurryT and nowT >= scurryT then
				G.playerScurryUntil[player] = nil
			end
			hum.WalkSpeed = G.DEFAULT_PLAYER_WALK_SPEED
		end
		hum.JumpPower = G.DEFAULT_PLAYER_JUMP_POWER
	else
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
end

function ProgressionSystem.onCharacterAdded(player: Player, character: Model)
	if G.pendingEvolution[player] then
		task.defer(function()
			addPickShield(player)
		end)
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = 100
	humanoid.Health = 100

	humanoid.Died:Connect(function()
		ProgressionSystem.handlePlayerDeath(player, character)
	end)

	character:WaitForChild("HumanoidRootPart")

	task.defer(function()
		updateSurvivalCrownCore()
	end)

	task.defer(function()
		ProgressionSystem.applyStoredAnimalLook(player, character)
	end)
end

function ProgressionSystem.mount(game: any)
	G = game
	G.getLevelFromPoints = getLevelFromPoints
	G.getMinPointsForLevel = getMinPointsForLevel
	G.titleFromKills = titleFromKills
	G.addPoints = ProgressionSystem.addPoints
	G.addCoins = ProgressionSystem.addCoins
	G.applyStoredAnimalLook = ProgressionSystem.applyStoredAnimalLook
	G.updateSurvivalCrownCore = updateSurvivalCrownCore
	G.addPickShield = addPickShield
	G.removePickShield = removePickShield
	G.applyPacifistGlow = applyPacifistGlow
	G.checkKillTitles = checkKillTitles

	G.animalPicked.OnServerEvent:Connect(function(player: Player, animalName: unknown)
		if typeof(animalName) ~= "string" then
			return
		end
		local pending = G.pendingEvolution[player]
		if not pending then
			return
		end
		if tick() > pending.expires then
			G.pendingEvolution[player] = nil
			return
		end
		if not G.AnimalPools.isNameInChoices(animalName :: string, pending.choices) then
			return
		end
		local lv = getLevelFromPoints(G.playerPoints[player] or 0)
		if not G.AnimalPools.isAnimalAllowedAtLevel(animalName :: string, lv) then
			return
		end
		G.pendingEvolution[player] = nil

		local ch = player.Character
		if ch then
			removePickShield(ch)
		end

		G.playerAnimal[player] = animalName :: string

		local now = workspace:GetServerTimeNow()
		player:SetAttribute("PacifistUntil", now + 3)

		if ch then
			applyPacifistGlow(ch)
		end

		G.addRankedPoints(player, G.RANKED_POINTS_EVOLUTION)
		ProgressionSystem.applyStoredAnimalLook(player)
	end)

	G.animalChanged.OnServerEvent:Connect(function(player: Player, animalName: unknown)
		if typeof(animalName) ~= "string" then
			return
		end
		if G.playerAnimal[player] ~= animalName :: string then
			return
		end
		ProgressionSystem.applyStoredAnimalLook(player)
	end)
end

function ProgressionSystem.onPlayerRemovingCrown(player: Player)
	if crownLeader == player then
		local ch = player.Character
		if ch then
			destroyCrownOnCharacter(ch)
		end
		crownLeader = nil
	end
	updateSurvivalCrownCore()
end

return ProgressionSystem
