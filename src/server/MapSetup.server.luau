-- Static Workspace map. Script order: MapSetup → init (Rojo name sort).

local Workspace = game:GetService("Workspace")

local existing = Workspace:FindFirstChild("Baseplate")
if existing then
	existing:Destroy()
end

local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(800, 4, 800)
ground.Position = Vector3.new(0, -2, 0)
ground.Anchored = true
ground.BrickColor = BrickColor.new("Bright green")
ground.Material = Enum.Material.Grass
ground.CanCollide = true
ground.Parent = Workspace

local wallT = 4
local wallH = 60
local half = 400 -- half of 800 ground
local yCenter = wallH / 2

local function makeWall(name: string, pos: Vector3, size: Vector3)
	local w = Instance.new("Part")
	w.Name = name
	w.Size = size
	w.Position = pos
	w.Anchored = true
	w.CanCollide = true
	w.Transparency = 1
	w.Parent = Workspace
end

local zOff = half + wallT / 2
local xOff = half + wallT / 2
makeWall("BoundaryNorth", Vector3.new(0, yCenter, zOff), Vector3.new(800, wallH, wallT))
makeWall("BoundarySouth", Vector3.new(0, yCenter, -zOff), Vector3.new(800, wallH, wallT))
makeWall("BoundaryEast", Vector3.new(xOff, yCenter, 0), Vector3.new(wallT, wallH, 800))
makeWall("BoundaryWest", Vector3.new(-xOff, yCenter, 0), Vector3.new(wallT, wallH, 800))

local mapProps = Instance.new("Folder")
mapProps.Name = "MapProps"
mapProps.Parent = Workspace

for i = 1, 20 do
	local x = math.random(-350, 350)
	local z = math.random(-350, 350)
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "Tree_" .. tostring(i)
	treeFolder.Parent = mapProps

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	-- Roblox cylinder: height along local X; rotate so height is world Y (~10 stud trunk, ~2 stud thick).
	trunk.Size = Vector3.new(10, 2, 2)
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material = Enum.Material.SmoothPlastic
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.CFrame = CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = treeFolder

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(8, 8, 8)
	leaves.BrickColor = BrickColor.new("Bright green")
	leaves.Material = Enum.Material.Grass
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Position = Vector3.new(x, 10 + 4, z)
	leaves.Parent = treeFolder
end

for i = 1, 8 do
	local rx = math.random(4, 8)
	local ry = math.random(4, 8)
	local rz = math.random(4, 8)
	local x = math.random(-350, 350)
	local z = math.random(-350, 350)
	local rock = Instance.new("Part")
	rock.Name = "Rock_" .. tostring(i)
	rock.Size = Vector3.new(rx, ry, rz)
	rock.Position = Vector3.new(x, ry / 2, z)
	rock.BrickColor = BrickColor.new("Medium stone grey")
	rock.Material = Enum.Material.Rock
	rock.Anchored = true
	rock.CanCollide = true
	rock.Parent = mapProps
end

for i = 1, 5 do
	local x = math.random(-350, 350)
	local z = math.random(-350, 350)
	local bush = Instance.new("Part")
	bush.Name = "Bush_" .. tostring(i)
	bush.Shape = Enum.PartType.Ball
	bush.Size = Vector3.new(4, 3, 4)
	bush.Position = Vector3.new(x, 1.5, z)
	bush.BrickColor = BrickColor.new("Dark green")
	bush.Material = Enum.Material.Grass
	bush.Anchored = true
	bush.CanCollide = true
	bush.Parent = mapProps
end

local spawnPositions: { Vector3 } = {
	Vector3.new(-300, 2, -250),
	Vector3.new(-150, 2, -250),
	Vector3.new(0, 2, -250),
	Vector3.new(150, 2, -250),
	Vector3.new(300, 2, -250),
	Vector3.new(-300, 2, 250),
	Vector3.new(-150, 2, 250),
	Vector3.new(0, 2, 250),
	Vector3.new(150, 2, 250),
	Vector3.new(300, 2, 250),
}

for i, pos in ipairs(spawnPositions) do
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn_" .. tostring(i)
	sp.Size = Vector3.new(6, 1, 6)
	sp.Position = pos
	sp.Anchored = true
	sp.Neutral = true
	sp.Enabled = true
	sp.Duration = 0
	sp.TeamColor = BrickColor.new("White")
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Parent = Workspace
end

print("Map loaded successfully")
