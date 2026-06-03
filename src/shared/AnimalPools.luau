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

local POOLS: { { Animal } } = {
	TIER_1,
	TIER_2,
	TIER_3,
}

local function getTierForLevel(level: number): number
	if level <= 4 then
		return 1
	elseif level <= 9 then
		return 2
	elseif level <= 17 then
		return 3
	else
		return 3 -- 18+ reuses tier 3 until more tiers exist
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

return {
	getTierForLevel = getTierForLevel,
	sampleChoicesForLevel = sampleChoicesForLevel,
	isNameInChoices = isNameInChoices,
}
