-- Server-only: body colors, R15 body scales, and overhead nameplate from chosen animal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalPools = require(Shared:WaitForChild("AnimalPools"))

local OVERHEAD_GUI_NAME = "AnimalOverhead"

local TIER_SCALE: { number } = { 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0 }
local APEX_TIER7_SCALE = 2.5

local function brick(name: string): Color3
	return BrickColor.new(name).Color
end

local function getBodyColors(character: Model): BodyColors
	local bc = character:FindFirstChildOfClass("BodyColors")
	if not bc then
		bc = Instance.new("BodyColors")
		bc.Name = "BodyColors"
		bc.Parent = character
	end
	return bc
end

local function applyUniform(bc: BodyColors, col: Color3)
	bc.HeadColor3 = col
	bc.LeftArmColor3 = col
	bc.RightArmColor3 = col
	bc.LeftLegColor3 = col
	bc.RightLegColor3 = col
	bc.TorsoColor3 = col
end

local function applyBodyColors(character: Model, animalName: string)
	local bc = getBodyColors(character)

	if animalName == "Noob Chicken" then
		local y, w = brick("Bright yellow"), brick("White")
		bc.HeadColor3 = y
		bc.TorsoColor3 = y
		bc.LeftArmColor3 = w
		bc.RightArmColor3 = w
		bc.LeftLegColor3 = y
		bc.RightLegColor3 = y
	elseif animalName == "Desert Mouse" then
		applyUniform(bc, brick("Medium stone grey"))
	elseif animalName == "Ice Fish" then
		applyUniform(bc, brick("Light blue"))
	elseif animalName == "Rat" then
		applyUniform(bc, brick("Dark grey"))
	elseif animalName == "Gecko" then
		applyUniform(bc, brick("Lime green"))
	elseif animalName == "Penguin" then
		local bk, wh = brick("Black"), brick("White")
		bc.HeadColor3 = bk
		bc.LeftArmColor3 = bk
		bc.RightArmColor3 = bk
		bc.LeftLegColor3 = bk
		bc.RightLegColor3 = bk
		bc.TorsoColor3 = wh
	elseif animalName == "Pigeon" then
		applyUniform(bc, brick("Sand blue"))
	elseif animalName == "Fox" then
		applyUniform(bc, brick("Bright orange"))
	elseif animalName == "Cobra" then
		applyUniform(bc, brick("Dark green"))
	elseif animalName == "Arctic Fox" then
		applyUniform(bc, brick("White"))
	elseif animalName == "Ember Hawk" then
		applyUniform(bc, brick("Dark red"))
	elseif animalName == "Wolf" then
		local dark, light = brick("Dark grey"), brick("Medium stone grey")
		bc.HeadColor3 = dark
		bc.LeftArmColor3 = dark
		bc.RightArmColor3 = dark
		bc.LeftLegColor3 = dark
		bc.RightLegColor3 = dark
		bc.TorsoColor3 = light
	elseif animalName == "Hyena" then
		applyUniform(bc, brick("Dark stone grey"))
	elseif animalName == "Seal" then
		applyUniform(bc, brick("Medium blue"))
	elseif animalName == "Lava Lion" then
		applyUniform(bc, brick("Bright red"))
	elseif animalName == "Gorilla" then
		applyUniform(bc, brick("Dark orange"))
	elseif animalName == "Camel" then
		applyUniform(bc, brick("Brown"))
	elseif animalName == "Polar Bear" then
		applyUniform(bc, brick("Institutional white"))
	elseif animalName == "Magma Rhino" then
		applyUniform(bc, brick("Really red"))
	elseif animalName == "Croc" then
		applyUniform(bc, brick("Earth green"))
	elseif animalName == "Sand Golem" then
		applyUniform(bc, brick("Sand yellow"))
	elseif animalName == "Orca" then
		local bk, wh = brick("Black"), brick("White")
		bc.HeadColor3 = bk
		bc.LeftArmColor3 = bk
		bc.RightArmColor3 = bk
		bc.LeftLegColor3 = bk
		bc.RightLegColor3 = bk
		bc.TorsoColor3 = wh
	elseif animalName == "Flame Gorilla" then
		applyUniform(bc, brick("Neon orange"))
	elseif animalName == "T-Rex" then
		applyUniform(bc, brick("Olive"))
	elseif animalName == "Sandworm" then
		applyUniform(bc, brick("Dark taupe"))
	elseif animalName == "Mammoth" then
		applyUniform(bc, brick("Reddish brown"))
	elseif animalName == "Magma Titan" then
		applyUniform(bc, brick("Really red"))
	else
		applyUniform(bc, brick("Medium stone grey"))
	end
end

local function setBodyScales(humanoid: Humanoid, scale: number)
	for _, childName in ipairs({ "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" }) do
		local v = humanoid:FindFirstChild(childName)
		if v and v:IsA("NumberValue") then
			v.Value = scale
		end
	end
end

local function scaleForAnimal(animalName: string, voidApex: boolean): number
	local tier = AnimalPools.getTierForAnimalName(animalName) or 1
	local s = TIER_SCALE[tier] or 1.0
	if voidApex and tier == 7 then
		return APEX_TIER7_SCALE
	end
	return s
end

local function mountOrUpdateOverhead(character: Model, animalName: string, level: number)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	local existing = head:FindFirstChild(OVERHEAD_GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = OVERHEAD_GUI_NAME
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = Vector3.new(0, 2.35, 0)
	bb.MaxDistance = 200
	bb.Adornee = head
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "AnimalLine"
	label.Size = UDim2.fromScale(1, 0.55)
	label.Position = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 245, 200)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.Text = animalName
	label.Parent = bb

	local lv = Instance.new("TextLabel")
	lv.Name = "LevelLine"
	lv.Size = UDim2.fromScale(1, 0.45)
	lv.Position = UDim2.fromScale(0, 0.52)
	lv.BackgroundTransparency = 1
	lv.Font = Enum.Font.GothamBold
	lv.TextScaled = true
	lv.TextColor3 = Color3.fromRGB(180, 220, 255)
	lv.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lv.TextStrokeTransparency = 0.4
	lv.Text = "Level " .. tostring(level)
	lv.Parent = bb
end

local function updateOverheadTextOnly(character: Model, animalName: string, level: number)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local bb = head:FindFirstChild(OVERHEAD_GUI_NAME)
	if not bb or not bb:IsA("BillboardGui") then
		mountOrUpdateOverhead(character, animalName, level)
		return
	end
	local a = bb:FindFirstChild("AnimalLine")
	local l = bb:FindFirstChild("LevelLine")
	if a and a:IsA("TextLabel") then
		a.Text = animalName
	end
	if l and l:IsA("TextLabel") then
		l.Text = "Level " .. tostring(level)
	end
end

local function applyFull(character: Model, animalName: string, level: number, voidApex: boolean)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	applyBodyColors(character, animalName)
	setBodyScales(hum, scaleForAnimal(animalName, voidApex))
	mountOrUpdateOverhead(character, animalName, level)
end

-- Defer until default scales exist (R15).
local function applyFullDeferred(character: Model, animalName: string, level: number, voidApex: boolean)
	task.defer(function()
		if not character.Parent then
			return
		end
		task.wait(0.12)
		if not character.Parent then
			return
		end
		applyFull(character, animalName, level, voidApex)
	end)
end

return {
	applyFullDeferred = applyFullDeferred,
	updateOverheadTextOnly = updateOverheadTextOnly,
}
