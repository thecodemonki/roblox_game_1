-- World chests, skin inventory, shop chest purchases, playtime skin milestones.

local ChestSystem = {}

local G: any = nil

local chestFolder: Folder
local chestSlots: { BasePart? } = {}

local function randomChestPosition(): Vector3
	return Vector3.new(
		math.random(-G.MAP_SIZE, G.MAP_SIZE),
		G.MAP_SURFACE_Y + G.CHEST_SIZE / 2,
		math.random(-G.MAP_SIZE, G.MAP_SIZE)
	)
end

local function buildChestPart(): BasePart
	local p = Instance.new("Part")
	p.Name = "TreasureChest"
	p.Size = Vector3.new(G.CHEST_SIZE, G.CHEST_SIZE, G.CHEST_SIZE)
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

local function rollRandomSkinWorld(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 60 then
		rarity = "Common"
		pool = G.SKINS_COMMON
	elseif r <= 85 then
		rarity = "Rare"
		pool = G.SKINS_RARE
	elseif r <= 97 then
		rarity = "Epic"
		pool = G.SKINS_EPIC
	else
		rarity = "Legendary"
		pool = G.SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

local function rollRandomSkinShopRare(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 20 then
		rarity = "Common"
		pool = G.SKINS_COMMON
	elseif r <= 70 then
		rarity = "Rare"
		pool = G.SKINS_RARE
	elseif r <= 95 then
		rarity = "Epic"
		pool = G.SKINS_EPIC
	else
		rarity = "Legendary"
		pool = G.SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

local function rollPlaytimeEpicChest(): (string, string)
	local r = math.random(1, 100)
	local rarity: string
	local pool: { string }
	if r <= 10 then
		rarity = "Common"
		pool = G.SKINS_COMMON
	elseif r <= 30 then
		rarity = "Rare"
		pool = G.SKINS_RARE
	elseif r <= 85 then
		rarity = "Epic"
		pool = G.SKINS_EPIC
	else
		rarity = "Legendary"
		pool = G.SKINS_LEGENDARY
	end
	return pool[math.random(1, #pool)], rarity
end

local function getSkinListSerializable(player: Player): { { name: string, rarity: string, level: number } }
	local inv = G.playerSkins[player]
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

function ChestSystem.syncSkinInventory(player: Player)
	if G.playerSkins[player] ~= nil then
		G.skinInventorySync:FireClient(player, getSkinListSerializable(player))
	end
end

-- kind: "new" | "level_up" | "duplicate_max"
function ChestSystem.grantSkinFromRoll(player: Player, skinName: string, rolledRarity: string)
	local inv = G.playerSkins[player]
	if not inv then
		return
	end
	local existing = inv[skinName]
	local rarity: string
	local level: number
	local kind: string
	if existing then
		rarity = existing.rarity
		if existing.level < G.SKIN_MAX_LEVEL then
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
	G.skinReceived:FireClient(player, skinName, rarity, level, kind)
	ChestSystem.syncSkinInventory(player)
end

local function grantRandomSkinFromChest(player: Player)
	local skinName, rolledRarity = rollRandomSkinWorld()
	ChestSystem.grantSkinFromRoll(player, skinName, rolledRarity)
end

function ChestSystem.tryOpenNearbyChest(player: Player, rootPos: Vector3)
	local now = tick()
	if now - (G.lastPlayerChestOpenTime[player] or 0) < G.CHEST_OPEN_COOLDOWN_SEC then
		return
	end
	for slot = 1, G.CHEST_COUNT do
		local ch = chestSlots[slot]
		if ch and ch.Parent and ch:GetAttribute("Available") == true then
			if now - (G.lastChestProximityAttempt[ch] or 0) < G.CHEST_SAME_PART_DEBOUNCE_SEC then
				continue
			end
			if (ch.Position - rootPos).Magnitude <= G.CHEST_OPEN_RANGE then
				G.lastChestProximityAttempt[ch] = now
				G.lastPlayerChestOpenTime[player] = now
				ch:SetAttribute("Available", false)
				ch:Destroy()
				chestSlots[slot] = nil
				grantRandomSkinFromChest(player)
				task.delay(G.CHEST_RESPAWN_SEC, function()
					if chestFolder.Parent then
						spawnChestAtSlot(slot)
					end
				end)
				return
			end
		end
	end
end

function ChestSystem.checkPlaytimeMilestones(player: Player, oldT: number, newT: number)
	local m = G.playerPlaytimeMilestonesDone[player]
	if not m then
		return
	end
	if not m["5m"] and oldT < G.PLAYTIME_MILESTONE_5M and newT >= G.PLAYTIME_MILESTONE_5M then
		m["5m"] = true
		local sn, rr = rollRandomSkinWorld()
		ChestSystem.grantSkinFromRoll(player, sn, rr)
	end
	if not m["20m"] and oldT < G.PLAYTIME_MILESTONE_20M and newT >= G.PLAYTIME_MILESTONE_20M then
		m["20m"] = true
		local sn, rr = rollRandomSkinShopRare()
		ChestSystem.grantSkinFromRoll(player, sn, rr)
		G.addCoins(player, 25)
	end
	if not m["1h"] and oldT < G.PLAYTIME_MILESTONE_1H and newT >= G.PLAYTIME_MILESTONE_1H then
		m["1h"] = true
		local sn, rr = rollPlaytimeEpicChest()
		ChestSystem.grantSkinFromRoll(player, sn, rr)
	end
	if not m["5h"] and oldT < G.PLAYTIME_MILESTONE_5H and newT >= G.PLAYTIME_MILESTONE_5H then
		m["5h"] = true
		local sn = G.SKINS_RARE[math.random(1, #G.SKINS_RARE)]
		ChestSystem.grantSkinFromRoll(player, sn, "Rare")
	end
end

function ChestSystem.mount(game: any)
	G = game
	chestFolder = Instance.new("Folder")
	chestFolder.Name = "Chests"
	chestFolder.Parent = workspace

	for slot = 1, G.CHEST_COUNT do
		spawnChestAtSlot(slot)
	end

	G.rollRandomSkinWorld = rollRandomSkinWorld
	G.rollRandomSkinShopRare = rollRandomSkinShopRare
	G.rollPlaytimeEpicChest = rollPlaytimeEpicChest
	G.grantSkinFromRoll = ChestSystem.grantSkinFromRoll
	G.tryOpenNearbyChest = ChestSystem.tryOpenNearbyChest
	G.checkPlaytimeMilestones = ChestSystem.checkPlaytimeMilestones

	G.purchaseChest.OnServerInvoke = function(player: Player, chestKind: unknown): boolean
		if typeof(chestKind) ~= "string" then
			return false
		end
		local k = chestKind :: string
		if k ~= "Common" and k ~= "Rare" then
			return false
		end
		if G.playerCoins[player] == nil or G.playerSkins[player] == nil then
			return false
		end
		if tick() - (G.lastPlayerChestOpenTime[player] or 0) < G.CHEST_OPEN_COOLDOWN_SEC then
			return false
		end
		local price = if k == "Rare" then G.SHOP_CHEST_RARE_PRICE else G.SHOP_CHEST_COMMON_PRICE
		if G.playerCoins[player] < price then
			return false
		end
		G.playerCoins[player] = G.playerCoins[player] - price
		G.coinsUpdated:FireClient(player, G.playerCoins[player])
		G.lastPlayerChestOpenTime[player] = tick()

		local skinName: string
		local rolledRarity: string
		if k == "Rare" then
			skinName, rolledRarity = rollRandomSkinShopRare()
		else
			skinName, rolledRarity = rollRandomSkinWorld()
		end

		task.defer(function()
			task.wait(0.42)
			if player.Parent and G.playerSkins[player] then
				ChestSystem.grantSkinFromRoll(player, skinName, rolledRarity)
			end
		end)
		return true
	end
end

return ChestSystem
