-- Tier animal pools for evolution pick (server samples; client displays server payload).

export type Animal = {
	name: string,
	ability: string,
}

local TIER_1: { Animal } = {
	{ name = "Noob Chicken", ability = "Cluck — nearby animals flinch" },
	{ name = "Desert Mouse", ability = "Burrow — hide briefly" },
	{ name = "Ice Fish", ability = "Slippery — hard to grab" },
}

local TIER_2: { Animal } = {
	{ name = "Rat", ability = "Scurry — speed burst" },
	{ name = "Gecko", ability = "Wall climb" },
	{ name = "Penguin", ability = "Slide — fast on ice" },
	{ name = "Pigeon", ability = "Poop — slow puddle on enemies" },
}

local TIER_3: { Animal } = {
	{ name = "Fox", ability = "Dash — quick lunge" },
	{ name = "Cobra", ability = "Venom — poison over time" },
	{ name = "Arctic Fox", ability = "Camouflage — invisible in snow" },
	{ name = "Ember Hawk", ability = "Dive — aerial strike" },
}

local TIER_4: { Animal } = {
	{ name = "Wolf", ability = "Pack howl — short speed boost" },
	{ name = "Hyena", ability = "Laugh — bleed on bite" },
	{ name = "Seal", ability = "Slide — bonus damage on ice" },
	{ name = "Lava Lion", ability = "Mane flare — fire cone" },
}

local TIER_5: { Animal } = {
	{ name = "Gorilla", ability = "Smash — ground slam" },
	{ name = "Camel", ability = "Spit — blind enemies briefly" },
	{ name = "Polar Bear", ability = "Bear hug — slow grapple" },
	{ name = "Magma Rhino", ability = "Charge — unstoppable dash" },
}

local TIER_6: { Animal } = {
	{ name = "Croc", ability = "Death roll — high burst damage" },
	{ name = "Sand Golem", ability = "Harden — reduce incoming damage" },
	{ name = "Orca", ability = "Sonar — reveal nearby players" },
	{ name = "Flame Gorilla", ability = "Inferno fists — burn over time" },
}

local TIER_7: { Animal } = {
	{ name = "T-Rex", ability = "Crunch — massive bite" },
	{ name = "Sandworm", ability = "Burrow ambush — underground dash" },
	{ name = "Mammoth", ability = "Trample — wide knockback" },
	{ name = "Magma Titan", ability = "Eruption — AoE lava pools" },
}

local POOLS: { { Animal } } = {
	TIER_1,
	TIER_2,
	TIER_3,
	TIER_4,
	TIER_5,
	TIER_6,
	TIER_7,
}

-- Level bands match the game's level curve (see server LEVEL_ANCHORS).
local function getTierForLevel(level: number): number
	if level <= 4 then
		return 1
	elseif level <= 9 then
		return 2
	elseif level <= 17 then
		return 3
	elseif level <= 27 then
		return 4
	elseif level <= 39 then
		return 5
	elseif level <= 54 then
		return 6
	else
		return 7
	end
end

local function shallowCopyPool(pool: { Animal }): { Animal }
	local copy: { Animal } = {}
	for i, a in ipairs(pool) do
		copy[i] = { name = a.name, ability = a.ability }
	end
	return copy
end

local function shuffleInPlace(t: { Animal })
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Returns exactly 3 animals for the tier matching `level` (after level-up).
local function sampleChoicesForLevel(level: number): { Animal }
	local tier = getTierForLevel(level)
	local pool = POOLS[tier]
	local copy = shallowCopyPool(pool)
	shuffleInPlace(copy)
	if #copy <= 3 then
		return copy
	end
	return { copy[1], copy[2], copy[3] }
end

local function isNameInChoices(animalName: string, choices: { Animal }): boolean
	for _, a in ipairs(choices) do
		if a.name == animalName then
			return true
		end
	end
	return false
end

-- Strongest / cap pick for the tier: last entry in the tier list.
local function getDefaultAnimalNameForLevel(level: number): string
	local tier = getTierForLevel(level)
	local pool = POOLS[tier]
	return pool[#pool].name
end

local function isAnimalAllowedAtLevel(animalName: string, level: number): boolean
	local tier = getTierForLevel(level)
	local pool = POOLS[tier]
	for _, a in ipairs(pool) do
		if a.name == animalName then
			return true
		end
	end
	return false
end

return {
	getTierForLevel = getTierForLevel,
	sampleChoicesForLevel = sampleChoicesForLevel,
	isNameInChoices = isNameInChoices,
	getDefaultAnimalNameForLevel = getDefaultAnimalNameForLevel,
	isAnimalAllowedAtLevel = isAnimalAllowedAtLevel,
}
