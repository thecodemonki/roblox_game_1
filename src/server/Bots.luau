-- NPC bots: Pathfinding movement, composition 5 Prey / 3 Neutral / 2 Hunter.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

export type BotKind = "Prey" | "Neutral" | "Hunter"

export type BotConfig = {
	foodFolder: Folder,
	mapHalf: number,
	foodRespawnDelay: number,
	spawnFood: (() -> ())?,
	getNearestPlayerRoot: (fromPos: Vector3, maxDist: number) -> (Player?, BasePart?),
	damagePlayerFromBot: (botModel: Model, target: Player, damage: number) -> (),
	tryBotMelee: (botModel: Model, damage: number) -> (),
	onBotUnregistered: ((Model) -> ())?,
}

local BOT_NAMES = {
	"ChickenLord99",
	"RatKing42",
	"AngryPigeon",
	"ClumsyFox",
	"SlipperyEel",
	"NobodyRat",
	"WanderingGoose",
	"LazyBear",
	"SnoozyWolf",
	"CluelessHawk",
	"TiredCroc",
	"SleepyShark",
	"GrumpyGoat",
	"BouncingBunny",
	"WobblyWalrus",
	"ConfusedCamel",
	"NervousNewt",
	"PanickedPenguin",
	"ShyShrimp",
	"BoldBadger",
}

local PREY_COUNT = 5
local NEUTRAL_COUNT = 3
local HUNTER_COUNT = 2

local FLEE_RANGE = 20
local HUNTER_CHASE_RANGE = 30
local NEUTRAL_AGGRO_RANGE = 80
local PATH_THINK_INTERVAL = 0.35
local BOT_MELEE_COOLDOWN = 1.5

local DAMAGE_BY_KIND: { [string]: number } = {
	Prey = 5,
	Neutral = 15,
	Hunter = 25,
}

local cfg: BotConfig? = nil
local botFolder: Folder? = nil
local registry: { [Model]: { kind: BotKind, displayName: string, nextThink: number, waypoints: { Vector3 }, wpIndex: number } } = {}

local pathParams = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	WaypointSpacing = 4,
}

local function pickUniqueBotName(): string
	local used: { [string]: boolean } = {}
	for _, p in Players:GetPlayers() do
		used[p.Name] = true
		used[p.DisplayName] = true
	end
	for model in pairs(registry) do
		local n = model:GetAttribute("DisplayBotName")
		if typeof(n) == "string" then
			used[n :: string] = true
		end
	end
	for _ = 1, 40 do
		local pick = BOT_NAMES[math.random(1, #BOT_NAMES)]
		if not used[pick] then
			return pick
		end
	end
	return "Bot" .. tostring(math.random(100000, 999999))
end

local function randomGroundGoal(mapHalf: number): Vector3
	-- Slightly above flat ground (Forest floor top Y=0).
	return Vector3.new(
		math.random(-mapHalf, mapHalf),
		3,
		math.random(-mapHalf, mapHalf)
	)
end

local function computePathWaypoints(startPos: Vector3, goal: Vector3): { Vector3 }
	local path = PathfindingService:CreatePath(pathParams)
	local ok, err = pcall(function()
		path:ComputeAsync(startPos, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return { goal }
	end
	local wps = path:GetWaypoints()
	local out: { Vector3 } = {}
	for _, wp in ipairs(wps) do
		table.insert(out, wp.Position)
	end
	if #out == 0 then
		return { goal }
	end
	return out
end

local function getRecord(model: Model)
	return registry[model]
end

local function unregister(model: Model)
	registry[model] = nil
end

local function eatNearbyFood(root: BasePart, c: BotConfig)
	if not c.foodFolder then
		return
	end
	for _, child in c.foodFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("FoodPickup") == true then
			if (child.Position - root.Position).Magnitude < 5 then
				child:Destroy()
				if c.spawnFood then
					task.delay(c.foodRespawnDelay, c.spawnFood)
				end
				return
			end
		end
	end
end

local function tickOneBot(model: Model, rec, dt: number, c: BotConfig)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return
	end

	rec.nextThink = rec.nextThink - dt
	if rec.nextThink > 0 then
		return
	end
	rec.nextThink = PATH_THINK_INTERVAL

	local pos = root.Position

	local fleeUntil = model:GetAttribute("AbilityFleeUntil")
	if typeof(fleeUntil) == "number" and tick() < (fleeUntil :: number) then
		local uid = model:GetAttribute("AbilityFleeSourceUserId")
		local fleeFrom: Vector3? = nil
		if typeof(uid) == "number" then
			local plr = Players:GetPlayerByUserId(uid :: number)
			local ch = plr and plr.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				fleeFrom = r.Position
			end
		end
		local goalFlee: Vector3
		if fleeFrom then
			local away = pos - fleeFrom
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude > 0.1 then
				goalFlee = pos + flat.Unit * 35
			else
				goalFlee = pos + Vector3.new(1, 0, 0).Unit * 35
			end
		else
			goalFlee = randomGroundGoal(c.mapHalf)
		end
		goalFlee = Vector3.new(
			math.clamp(goalFlee.X, -c.mapHalf, c.mapHalf),
			goalFlee.Y,
			math.clamp(goalFlee.Z, -c.mapHalf, c.mapHalf)
		)
		rec.waypoints = computePathWaypoints(pos, goalFlee)
		rec.wpIndex = 1
		if #rec.waypoints > 0 then
			local targetWp = rec.waypoints[math.min(2, #rec.waypoints)]
			hum:MoveTo(targetWp)
		end
		local dmg = DAMAGE_BY_KIND[rec.kind] or 5
		c.tryBotMelee(model, dmg)
		return
	end

	local nearestRootFlee = select(2, c.getNearestPlayerRoot(pos, FLEE_RANGE))
	local nearestRootHunter = select(2, c.getNearestPlayerRoot(pos, HUNTER_CHASE_RANGE))

	local goal: Vector3? = nil

	if rec.kind == "Prey" then
		if nearestRootFlee and (nearestRootFlee.Position - pos).Magnitude <= FLEE_RANGE then
			local away = (pos - nearestRootFlee.Position)
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude > 0.1 then
				goal = pos + flat.Unit * 28
			end
		end
		if not goal then
			goal = randomGroundGoal(c.mapHalf)
		end
	elseif rec.kind == "Hunter" then
		if nearestRootHunter and (nearestRootHunter.Position - pos).Magnitude <= HUNTER_CHASE_RANGE then
			goal = nearestRootHunter.Position
		else
			goal = randomGroundGoal(c.mapHalf)
		end
	else
		-- Neutral: chase last attacker if still valid
		local uid = model:GetAttribute("LastAttackerUserId")
		if typeof(uid) == "number" then
			local p = Players:GetPlayerByUserId(uid :: number)
			if p and p.Character then
				local r = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local h = p.Character:FindFirstChildOfClass("Humanoid")
				if r and h and h.Health > 0 and (r.Position - pos).Magnitude <= NEUTRAL_AGGRO_RANGE then
					goal = r.Position
				end
			end
		end
		if not goal then
			eatNearbyFood(root, c)
			goal = randomGroundGoal(c.mapHalf)
		end
	end

	goal = Vector3.new(
		math.clamp((goal :: Vector3).X, -c.mapHalf, c.mapHalf),
		(goal :: Vector3).Y,
		math.clamp((goal :: Vector3).Z, -c.mapHalf, c.mapHalf)
	)

	rec.waypoints = computePathWaypoints(pos, goal :: Vector3)
	rec.wpIndex = 1

	if #rec.waypoints > 0 then
		local targetWp = rec.waypoints[math.min(2, #rec.waypoints)]
		hum:MoveTo(targetWp)
	end

	local dmg = DAMAGE_BY_KIND[rec.kind] or 5
	c.tryBotMelee(model, dmg)
end

local M = {}

function M.setup(c: BotConfig)
	cfg = c
	botFolder = Workspace:FindFirstChild("Bots") :: Folder?
	if not botFolder then
		botFolder = Instance.new("Folder")
		botFolder.Name = "Bots"
		botFolder.Parent = Workspace
	end
end

function M.spawnBot(kind: BotKind)
	local c = cfg
	if not c or not botFolder then
		return
	end

	local name = pickUniqueBotName()
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("EvolveBot", true)
	model:SetAttribute("BotKind", kind)
	model:SetAttribute("DisplayBotName", name)

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 5, 1)
	hrp.Anchored = false
	hrp.CanCollide = true
	hrp.Position = randomGroundGoal(c.mapHalf)
	hrp.Parent = model

	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.DisplayName = name
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = 18
	hum.JumpPower = 35
	hum.Parent = model

	model.PrimaryPart = hrp

	registry[model] = {
		kind = kind,
		displayName = name,
		nextThink = 0,
		waypoints = {},
		wpIndex = 1,
	}

	model.Parent = botFolder

	local kindSaved: BotKind = kind
	hum.Died:Connect(function()
		if cfg and cfg.onBotUnregistered then
			cfg.onBotUnregistered(model)
		end
		unregister(model)
		model:Destroy()
		local delaySec = math.random(30, 60)
		task.delay(delaySec, function()
			if cfg and botFolder and botFolder.Parent then
				M.spawnBot(kindSaved)
			end
		end)
	end)
end

local function countKind(kind: string): number
	local n = 0
	for m in pairs(registry) do
		if m.Parent and m:GetAttribute("BotKind") == kind then
			n = n + 1
		end
	end
	return n
end

function M.ensureComposition()
	if not cfg or not botFolder then
		return
	end
	while countKind("Prey") < PREY_COUNT do
		M.spawnBot("Prey")
	end
	while countKind("Neutral") < NEUTRAL_COUNT do
		M.spawnBot("Neutral")
	end
	while countKind("Hunter") < HUNTER_COUNT do
		M.spawnBot("Hunter")
	end
end

local accum = 0
function M.onHeartbeat(dt: number)
	local c = cfg
	if not c then
		return
	end
	accum = accum + dt
	if accum < 0.2 then
		return
	end
	local step = accum
	accum = 0

	for model, rec in pairs(registry) do
		if model.Parent then
			tickOneBot(model, rec, step, c)
		else
			unregister(model)
		end
	end
end

function M.iterBotModels(): { Model }
	local list: { Model } = {}
	for m in pairs(registry) do
		if m.Parent then
			table.insert(list, m)
		end
	end
	return list
end

function M.setLastAttacker(botModel: Model, attacker: Player)
	botModel:SetAttribute("LastAttackerUserId", attacker.UserId)
end

return M
