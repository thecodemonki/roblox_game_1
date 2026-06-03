-- Builds the Forest arena: floor, props, river, bounds, spawn points.
-- Call once at server start before food/chests. Exposes river overlap for WalkSpeed.

local CollectionService = game:GetService("CollectionService")

local BUSH_TAG = "ForestBush"

local riverPart: BasePart? = nil

local function destroyIfPresent(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function inRiverOBB(worldPos: Vector3): boolean
	local p = riverPart
	if not p or not p.Parent then
		return false
	end
	local localPos = p.CFrame:PointToObjectSpace(worldPos)
	local h = p.Size * 0.5
	return math.abs(localPos.X) <= h.X and math.abs(localPos.Y) <= h.Y and math.abs(localPos.Z) <= h.Z
end

local function clearForestFolder(workspace: Workspace): Folder
	destroyIfPresent(workspace, "Forest")
	local folder = Instance.new("Folder")
	folder.Name = "Forest"
	folder.Parent = workspace
	return folder
end

local function makeFloor(parent: Folder, mapHalf: number)
	local floor = Instance.new("Part")
	floor.Name = "GrassFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(72, 118, 62)
	floor.Size = Vector3.new(mapHalf * 2, 1, mapHalf * 2)
	floor.Position = Vector3.new(0, 0.5, 0)
	floor.Parent = parent
	return floor
end

local function makeRiver(parent: Folder, mapHalf: number): BasePart
	local width = 36
	local depthY = 7
	local lengthZ = mapHalf * 2 + 8
	local p = Instance.new("Part")
	p.Name = "River"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.Material = Enum.Material.Glass
	p.Transparency = 0.35
	p.Color = Color3.fromRGB(55, 120, 200)
	p.Size = Vector3.new(width, depthY, lengthZ)
	p.Position = Vector3.new(0, 3, 0)
	p.Parent = parent
	riverPart = p
	return p
end

local function makeBoundaryWalls(parent: Folder, mapHalf: number)
	local wallH = 52
	local wallT = 3
	local span = mapHalf * 2 + wallT * 2 + 4
	local yCenter = wallH / 2 + 1

	local function wall(name: string, pos: Vector3, size: Vector3)
		local w = Instance.new("Part")
		w.Name = name
		w.Anchored = true
		w.CanCollide = true
		w.Transparency = 1
		w.Size = size
		w.Position = pos
		w.Parent = parent
	end

	wall("WallNorth", Vector3.new(0, yCenter, mapHalf + wallT / 2 + 1), Vector3.new(span, wallH, wallT))
	wall("WallSouth", Vector3.new(0, yCenter, -(mapHalf + wallT / 2 + 1)), Vector3.new(span, wallH, wallT))
	wall("WallEast", Vector3.new(mapHalf + wallT / 2 + 1, yCenter, 0), Vector3.new(wallT, wallH, span))
	wall("WallWest", Vector3.new(-(mapHalf + wallT / 2 + 1), yCenter, 0), Vector3.new(wallT, wallH, span))
end

local RIVER_CLEAR_X = 22 -- keep props / spawns out of river strip (world X)

local function isClearOfRiver(x: number, z: number, radius: number): boolean
	return math.abs(x) > RIVER_CLEAR_X + radius
end

local function distSq(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return dx * dx + dz * dz
end

local function tryRandomXZ(mapHalf: number, margin: number, minRiverClearRadius: number, avoid: { { x: number, z: number, r: number } }, selfR: number): (number?, number?)
	local inner = mapHalf - margin
	for _ = 1, 60 do
		local x = math.random() * 2 * inner - inner
		local z = math.random() * 2 * inner - inner
		if not isClearOfRiver(x, z, minRiverClearRadius) then
			continue
		end
		local ok = true
		for _, o in ipairs(avoid) do
			if distSq(x, z, o.x, o.z) < (selfR + o.r) * (selfR + o.r) then
				ok = false
				break
			end
		end
		if ok then
			return x, z
		end
	end
	return nil, nil
end

local function makeTree(parent: Folder, mapHalf: number, avoid: { { x: number, z: number, r: number } })
	local scale = 0.7 + math.random() * 0.65
	local trunkH = 10 * scale
	local trunkR = 1.1 * scale
	local leafR = 4 * scale
	local selfR = leafR + 1
	local x, z = tryRandomXZ(mapHalf, 12, selfR * 0.5, avoid, selfR)
	if x == nil then
		return
	end
	table.insert(avoid, { x = x :: number, z = z :: number, r = selfR })

	local folder = Instance.new("Folder")
	folder.Name = "Tree"
	folder.Parent = parent

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(92, 62, 42)
	trunk.Size = Vector3.new(trunkH, trunkR * 2, trunkR * 2)
	trunk.CFrame = CFrame.new(x :: number, 1 + trunkH / 2, z :: number) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = folder

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Anchored = true
	leaves.CanCollide = true
	leaves.Material = Enum.Material.Grass
	leaves.Color = Color3.fromRGB(48, 110, 58)
	leaves.Size = Vector3.new(leafR * 2, leafR * 2, leafR * 2)
	leaves.Position = Vector3.new(x :: number, 1 + trunkH + leafR * 0.85, z :: number)
	leaves.Parent = folder
end

local function makeRock(parent: Folder, mapHalf: number, avoid: { { x: number, z: number, r: number } })
	local w = 5 + math.random() * 5
	local h = 3 + math.random() * 4
	local d = 5 + math.random() * 4
	local selfR = math.max(w, d) * 0.55
	local x, z = tryRandomXZ(mapHalf, 10, selfR * 0.4, avoid, selfR)
	if x == nil then
		return
	end
	table.insert(avoid, { x = x :: number, z = z :: number, r = selfR })

	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Anchored = true
	rock.CanCollide = true
	rock.Material = Enum.Material.Rock
	rock.Color = Color3.fromRGB(110, 105, 100)
	rock.Size = Vector3.new(w, h, d)
	rock.CFrame = CFrame.new(x :: number, 1 + h / 2, z :: number)
		* CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(0, 359)), math.rad(math.random(-10, 10)))
	rock.Parent = parent
end

local function makeBush(parent: Folder, mapHalf: number, avoid: { { x: number, z: number, r: number } })
	local r = 5 + math.random() * 2.5
	local x, z = tryRandomXZ(mapHalf, 8, r * 0.3, avoid, r)
	if x == nil then
		return
	end
	table.insert(avoid, { x = x :: number, z = z :: number, r = r })

	local bush = Instance.new("Part")
	bush.Name = "Bush"
	bush.Shape = Enum.PartType.Ball
	bush.Anchored = true
	bush.CanCollide = false
	bush.Material = Enum.Material.Grass
	bush.Color = Color3.fromRGB(40, 95, 48)
	bush.Transparency = 0.32
	bush.Size = Vector3.new(r * 2, r * 1.3, r * 2)
	bush.Position = Vector3.new(x :: number, 1 + r * 0.45, z :: number)
	bush.Parent = parent
	CollectionService:AddTag(bush, BUSH_TAG)
end

local function makeSpawnLocations(parent: Folder, mapHalf: number)
	-- Spread around map; favor |X| large to stay off the Z-running river (centered on X=0).
	local spots: { Vector3 } = {
		Vector3.new(130, 2, 0),
		Vector3.new(-130, 2, 0),
		Vector3.new(115, 2, 115),
		Vector3.new(115, 2, -115),
		Vector3.new(-115, 2, 115),
		Vector3.new(-115, 2, -115),
		Vector3.new(85, 2, 155),
		Vector3.new(-85, 2, 155),
		Vector3.new(85, 2, -155),
		Vector3.new(-85, 2, -155),
		Vector3.new(155, 2, 55),
		Vector3.new(-155, 2, 55),
		Vector3.new(155, 2, -55),
		Vector3.new(-155, 2, -55),
	}

	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "SpawnPoints"
	spawnsFolder.Parent = parent

	for i, pos in ipairs(spots) do
		if math.abs(pos.X) <= mapHalf - 4 and math.abs(pos.Z) <= mapHalf - 4 then
			local sp = Instance.new("SpawnLocation")
			sp.Name = "ForestSpawn_" .. tostring(i)
			sp.Size = Vector3.new(8, 1, 8)
			sp.Position = pos
			sp.Neutral = true
			sp.Enabled = true
			sp.Duration = 0
			sp.TeamColor = BrickColor.new("Bright green")
			sp.Transparency = 1
			sp.CanCollide = false
			sp.Anchored = true
			sp.Parent = spawnsFolder
		end
	end
end

local M = {}

function M.isPositionInRiver(worldPos: Vector3): boolean
	return inRiverOBB(worldPos)
end

function M.build(workspace: Workspace, mapHalf: number)
	destroyIfPresent(workspace, "Baseplate")

	local forest = clearForestFolder(workspace)
	makeFloor(forest, mapHalf)
	makeRiver(forest, mapHalf)
	makeBoundaryWalls(forest, mapHalf)

	local avoid: { { x: number, z: number, r: number } } = {}

	for _ = 1, 20 do
		makeTree(forest, mapHalf, avoid)
	end
	for _ = 1, 10 do
		makeRock(forest, mapHalf, avoid)
	end
	for _ = 1, 5 do
		makeBush(forest, mapHalf, avoid)
	end

	makeSpawnLocations(forest, mapHalf)
end

return M
