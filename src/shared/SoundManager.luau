-- Client-side SFX helper (require from LocalScripts only).
-- Central place for asset IDs and playback rules.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AMBIENT_NAME = "EvolveForestAmbient"
local ROLL_OFF_MAX = 100

-- Temporary: single verified audio asset for all SFX until per-sound IDs are set.
local UNIFIED_SOUND_ID = "rbxassetid://9120386456"
local SOUND_VOLUME = 0.5

local IDS: { [string]: string } = {
	eat = UNIFIED_SOUND_ID,
	levelUp = UNIFIED_SOUND_ID,
	death = UNIFIED_SOUND_ID,
	kill = UNIFIED_SOUND_ID,
	chestOpen = UNIFIED_SOUND_ID,
	titleUnlock = UNIFIED_SOUND_ID,
	attack = UNIFIED_SOUND_ID,
	ambientForest = UNIFIED_SOUND_ID,
}

local function getLocalRoot(): BasePart?
	local plr = Players.LocalPlayer
	if not plr then
		return nil
	end
	local ch = plr.Character
	if not ch then
		return nil
	end
	local r = ch:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r :: BasePart
	end
	return nil
end

local function playOneShotAtParent(soundId: string, parent: Instance, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.RollOffMaxDistance = ROLL_OFF_MAX
	s.Parent = parent
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function playOneShot2D(soundId: string, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.RollOffMaxDistance = ROLL_OFF_MAX
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local SoundManager = {}

function SoundManager.playSound(soundName: string)
	local id = IDS[soundName]
	if not id then
		warn("[SoundManager] Unknown sound:", soundName)
		return
	end

	if soundName == "eat" or soundName == "attack" then
		local root = getLocalRoot()
		if root then
			playOneShotAtParent(id, root, SOUND_VOLUME)
		else
			playOneShot2D(id, SOUND_VOLUME)
		end
		return
	end

	if soundName == "death" or soundName == "levelUp" or soundName == "kill" or soundName == "titleUnlock" or soundName == "chestOpen" then
		playOneShot2D(id, SOUND_VOLUME)
	else
		playOneShot2D(id, SOUND_VOLUME)
	end
end

-- Quiet looping ambience on SoundService (each client runs their own copy).
function SoundManager.startAmbientLoop()
	local existing = SoundService:FindFirstChild(AMBIENT_NAME)
	if existing then
		existing:Destroy()
	end
	local id = IDS.ambientForest
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.Name = AMBIENT_NAME
	s.SoundId = id
	s.Volume = SOUND_VOLUME
	s.RollOffMaxDistance = ROLL_OFF_MAX
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end

return SoundManager
