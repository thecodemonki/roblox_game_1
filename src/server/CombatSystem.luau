-- Melee cone, abilities, projectiles, bot damage hooks, attack/useAbility remotes.

local CombatSystem = {}

local G: any = nil

local abilityProjFolder: Folder

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

local function getCombatStatsForPlayer(player: Player): (number, number)
	local level = G.getLevelFromPoints(G.playerPoints[player] or 0)
	local tier = G.AnimalPools.getTierForLevel(level)
	local row = G.TIER_COMBAT[tier] or G.TIER_COMBAT[3]
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
	if dist > G.ATTACK_RANGE then
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
	return ang <= G.ATTACK_HALF_ARC_DEG
end

local function getNearestPlayerRoot(fromPos: Vector3, maxDist: number): (Player?, BasePart?)
	local bestP: Player? = nil
	local bestR: BasePart? = nil
	local bestD = maxDist + 1
	for _, plr in G.Players:GetPlayers() do
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

local function getAbilityCooldownSecondsForTier(tier: number): number
	if tier <= 1 then
		return 15
	elseif tier == 2 then
		return 12
	elseif tier == 3 then
		return 10
	elseif tier == 4 then
		return 8
	else
		return 6
	end
end

local function fireAbilityFeedback(player: Player, ok: boolean, abilityName: string, cooldownTotal: number, remainingOnFail: number)
	G.abilityFeedback:FireClient(player, ok, abilityName, cooldownTotal, remainingOnFail)
end

local function knockbackFlat(root: BasePart, fromPos: Vector3, strength: number)
	local away = root.Position - fromPos
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, 1)
	end
	local mass = root.AssemblyMass
	if mass < 1 then
		mass = 1
	end
	root:ApplyImpulse(flat.Unit * strength * mass)
end

local function tryDamagePlayerHumanoid(attacker: Player?, victim: Player, damage: number): boolean
	local ch = victim.Character
	if not ch then
		return false
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local rootP = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not rootP or hum.Health <= 0 then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local pac = victim:GetAttribute("PacifistUntil")
	if typeof(pac) == "number" and now < pac then
		return false
	end
	local newHealth = hum.Health - damage
	flashCombatHit(ch)
	showFloatingDamage(rootP, damage)
	if newHealth <= 0 then
		if attacker and attacker ~= victim and G.playerPoints[attacker] ~= nil then
			CombatSystem.onPlayerKill(attacker, victim)
		end
		hum.Health = 0
		return true
	else
		hum.Health = newHealth
		return false
	end
end

local function damageBotFromPlayer(attacker: Player, botModel: Model, damage: number)
	local humB = botModel:FindFirstChildOfClass("Humanoid")
	local rootB = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humB or not rootB or humB.Health <= 0 then
		return
	end
	local newHealth = humB.Health - damage
	flashCombatHit(botModel)
	showFloatingDamage(rootB, damage)
	if newHealth <= 0 then
		local dn = botModel:GetAttribute("DisplayBotName")
		local displayName = if typeof(dn) == "string" then dn :: string else botModel.Name
		CombatSystem.grantBotKill(attacker, displayName)
		humB.Health = 0
	else
		humB.Health = newHealth
	end
end

local function abilityCluck(caster: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local origin = root.Position
	for _, plr in G.Players:GetPlayers() do
		if plr == caster or G.playerPoints[plr] == nil then
			continue
		end
		local ch = plr.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (r.Position - origin).Magnitude <= 10 then
			knockbackFlat(r, origin, 18)
		end
	end
end

local function abilityScurry(player: Player)
	G.playerScurryUntil[player] = tick() + 3
end

local function abilityFoxDash(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local newPos = root.Position + flat * 20
	newPos = Vector3.new(
		math.clamp(newPos.X, -G.MAP_SIZE, G.MAP_SIZE),
		root.Position.Y,
		math.clamp(newPos.Z, -G.MAP_SIZE, G.MAP_SIZE)
	)
	root.CFrame = CFrame.new(newPos, newPos + flat)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function spawnPoisonProjectile(caster: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local dir = root.CFrame.LookVector
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local p = Instance.new("Part")
	p.Name = "VenomSpit"
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(80, 200, 90)
	p.CanCollide = false
	p.CanQuery = true
	p.Massless = false
	p.Anchored = false
	p.Position = root.Position + Vector3.new(0, 2, 0) + flat * 2
	p.Parent = abilityProjFolder
	p.AssemblyLinearVelocity = flat * 95

	local hit = false
	local conn: RBXScriptConnection? = nil
	local function cleanup()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if p.Parent then
			p:Destroy()
		end
	end
	conn = p.Touched:Connect(function(other: BasePart)
		if hit or not p.Parent then
			return
		end
		local model = other:FindFirstAncestorOfClass("Model")
		if not model or model == character then
			return
		end
		local plr = G.Players:GetPlayerFromCharacter(model)
		if not plr or plr == caster or G.playerPoints[plr] == nil then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		hit = true
		G.playerPoisonUntil[plr] = tick() + 5
		G.playerPoisonTickAccum[plr] = 0
		cleanup()
	end)
	task.delay(5, cleanup)
end

local function spawnRockProjectile(caster: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local dir = root.CFrame.LookVector
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local p = Instance.new("Part")
	p.Name = "RockThrow"
	p.Size = Vector3.new(2.2, 2.2, 2.2)
	p.Material = Enum.Material.Slate
	p.Color = Color3.fromRGB(90, 88, 85)
	p.CanCollide = false
	p.CanQuery = true
	p.Anchored = false
	p.Position = root.Position + Vector3.new(0, 3, 0) + flat * 3
	p.Parent = abilityProjFolder
	p.AssemblyLinearVelocity = flat * 55

	local hit = false
	local conn: RBXScriptConnection? = nil
	local function cleanup()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if p.Parent then
			p:Destroy()
		end
	end
	conn = p.Touched:Connect(function(other: BasePart)
		if hit or not p.Parent then
			return
		end
		local model = other:FindFirstAncestorOfClass("Model")
		if not model or model == character then
			return
		end
		local plr = G.Players:GetPlayerFromCharacter(model)
		if plr and G.playerPoints[plr] ~= nil then
			hit = true
			tryDamagePlayerHumanoid(caster, plr, 40)
			cleanup()
			return
		end
		if model:GetAttribute("EvolveBot") == true then
			hit = true
			damageBotFromPlayer(caster, model, 40)
			cleanup()
		end
	end)
	task.delay(6, cleanup)
end

local function abilityWolfHowl(caster: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local tEnd = tick() + 5
	for _, botModel in ipairs(G.Bots.iterBotModels()) do
		local br = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if br and (br.Position - root.Position).Magnitude <= 30 then
			botModel:SetAttribute("AbilityFleeUntil", tEnd)
			botModel:SetAttribute("AbilityFleeSourceUserId", caster.UserId)
		end
	end
end

local function abilityTRexStomp(caster: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local origin = root.Position
	for _, plr in G.Players:GetPlayers() do
		if plr == caster or G.playerPoints[plr] == nil then
			continue
		end
		local ch = plr.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (r.Position - origin).Magnitude <= 15 then
			tryDamagePlayerHumanoid(caster, plr, 50)
			if r.Parent then
				knockbackFlat(r, origin, 45)
			end
		end
	end
	for _, botModel in ipairs(G.Bots.iterBotModels()) do
		local br = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humB = botModel:FindFirstChildOfClass("Humanoid")
		if br and humB and humB.Health > 0 and (br.Position - origin).Magnitude <= 15 then
			damageBotFromPlayer(caster, botModel, 50)
			if br.Parent then
				knockbackFlat(br, origin, 45)
			end
		end
	end
end

local function tryExecutePlayerAbility(player: Player): (boolean, string, number, number)
	local animal = G.playerAnimal[player]
	local cdDefault = 15
	if not animal or typeof(animal) ~= "string" then
		return false, "No ability", cdDefault, 0
	end
	local character = player.Character
	if not character then
		return false, "No ability", cdDefault, 0
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false, "No ability", cdDefault, 0
	end

	local tier = G.AnimalPools.getTierForAnimalName(animal :: string)
	local cd = if tier then getAbilityCooldownSecondsForTier(tier) else cdDefault
	local now = tick()
	local nextAt = G.playerAbilityNextReadyAt[player] or 0
	if now < nextAt then
		return false, "", cd, nextAt - now
	end

	local name = animal :: string
	local displayName = "Ability"
	if name == "Noob Chicken" then
		displayName = "Cluck"
		abilityCluck(player, character)
	elseif name == "Rat" then
		displayName = "Scurry"
		abilityScurry(player)
	elseif name == "Fox" then
		displayName = "Dash"
		abilityFoxDash(character)
	elseif name == "Cobra" then
		displayName = "Venom Spit"
		spawnPoisonProjectile(player, character)
	elseif name == "Wolf" then
		displayName = "Howl"
		abilityWolfHowl(player, character)
	elseif name == "Gorilla" then
		displayName = "Rock Throw"
		spawnRockProjectile(player, character)
	elseif name == "T-Rex" then
		displayName = "Stomp"
		abilityTRexStomp(player, character)
	else
		return false, "No ability", cd, 0
	end

	G.playerAbilityNextReadyAt[player] = now + cd
	return true, displayName, cd, 0
end

function CombatSystem.damagePlayerFromBot(_botModel: Model, target: Player, damage: number)
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

function CombatSystem.tryBotMelee(botModel: Model, damage: number)
	local tnow = tick()
	local last = G.lastBotMeleeTime[botModel] or 0
	if tnow - last < G.BOT_MELEE_COOLDOWN then
		return
	end
	G.lastBotMeleeTime[botModel] = tnow

	local humB = botModel:FindFirstChildOfClass("Humanoid")
	local rootB = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humB or not rootB or humB.Health <= 0 then
		return
	end

	for _, plr in G.Players:GetPlayers() do
		if G.playerPoints[plr] == nil then
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
		CombatSystem.damagePlayerFromBot(botModel, plr, damage)
	end
end

function CombatSystem.grantBotKill(attacker: Player, botDisplayName: string)
	local oldK = G.playerKills[attacker] or 0
	G.playerKills[attacker] = oldK + 1
	G.addPoints(attacker, G.POINTS_PER_KILL)
	G.playerKilled:FireClient(attacker, "killer", botDisplayName, G.POINTS_PER_KILL)
	G.checkKillTitles(attacker, oldK, G.playerKills[attacker] :: number)
	G.addCoins(attacker, G.COINS_PER_KILL)
	G.addRankedPoints(attacker, G.RANKED_POINTS_KILL)
end

function CombatSystem.onPlayerKill(attacker: Player, victim: Player)
	local oldK = G.playerKills[attacker] or 0
	G.playerKills[attacker] = oldK + 1
	G.addPoints(attacker, G.POINTS_PER_KILL)
	G.playerKilled:FireClient(attacker, "killer", victim.Name, G.POINTS_PER_KILL)
	G.playerKilled:FireClient(victim, "victim", attacker.Name)
	G.checkKillTitles(attacker, oldK, G.playerKills[attacker] :: number)
	G.addCoins(attacker, G.COINS_PER_KILL)
	G.addRankedPoints(attacker, G.RANKED_POINTS_KILL)
end

function CombatSystem.tryMeleeAttack(attacker: Player)
	if G.playerPoints[attacker] == nil then
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
	local last = G.playerLastAttack[attacker] or 0
	if tick() - last < cooldown then
		return
	end
	G.playerLastAttack[attacker] = tick()

	for _, other in G.Players:GetPlayers() do
		if other == attacker then
			continue
		end
		if G.playerPoints[other] == nil then
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
			CombatSystem.onPlayerKill(attacker, other)
			humB.Health = 0
		else
			humB.Health = newHealth
		end
	end

	for _, botModel in ipairs(G.Bots.iterBotModels()) do
		local humB = botModel:FindFirstChildOfClass("Humanoid")
		local rootB = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humB or not rootB or humB.Health <= 0 then
			continue
		end
		if not isTargetInMeleeCone(rootA, rootB.Position) then
			continue
		end

		G.Bots.setLastAttacker(botModel, attacker)

		local newHealth = humB.Health - damage
		flashCombatHit(botModel)
		showFloatingDamage(rootB, damage)

		if newHealth <= 0 then
			local dn = botModel:GetAttribute("DisplayBotName")
			local displayName = if typeof(dn) == "string" then dn :: string else botModel.Name
			CombatSystem.grantBotKill(attacker, displayName)
			humB.Health = 0
		else
			humB.Health = newHealth
		end
	end
end

function CombatSystem.characterPoisonStep(player: Player, character: Model, hum: Humanoid, nowT: number, dt: number)
	local poisonUntil = G.playerPoisonUntil[player]
	if poisonUntil and nowT < poisonUntil then
		local acc = (G.playerPoisonTickAccum[player] or 0) + dt
		while acc >= 1 do
			acc = acc - 1
			if hum.Health > 0 then
				local nh = hum.Health - 5
				flashCombatHit(character)
				local rp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rp then
					showFloatingDamage(rp, 5)
				end
				hum.Health = math.max(0, nh)
			end
		end
		G.playerPoisonTickAccum[player] = acc
	elseif poisonUntil and nowT >= poisonUntil then
		G.playerPoisonUntil[player] = nil
		G.playerPoisonTickAccum[player] = nil
	end
end

function CombatSystem.mount(game: any)
	G = game

	local folder = workspace:FindFirstChild("AbilityProjectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AbilityProjectiles"
		folder.Parent = workspace
	end
	abilityProjFolder = folder :: Folder

	G.getNearestPlayerRoot = getNearestPlayerRoot
	G.damagePlayerFromBot = CombatSystem.damagePlayerFromBot
	G.tryBotMelee = CombatSystem.tryBotMelee

	G.attackRequest.OnServerEvent:Connect(function(player: Player)
		CombatSystem.tryMeleeAttack(player)
	end)

	G.useAbility.OnServerEvent:Connect(function(player: Player)
		if G.playerPoints[player] == nil or G.playerMenuUnlocked[player] ~= true then
			fireAbilityFeedback(player, false, "", 0, 0)
			return
		end
		local ok, abName, cdTotal, remaining = tryExecutePlayerAbility(player)
		if ok then
			fireAbilityFeedback(player, true, abName, cdTotal, 0)
		else
			if abName == "No ability" then
				fireAbilityFeedback(player, false, abName, cdTotal, 0)
			else
				fireAbilityFeedback(player, false, "", cdTotal, remaining)
			end
		end
	end)
end

return CombatSystem
