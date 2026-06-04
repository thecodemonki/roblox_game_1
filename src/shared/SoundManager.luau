-- Client-side SFX helper (require from LocalScripts only).
-- Central place for asset IDs and playback rules.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AMBIENT_NAME = "EvolveForestAmbient"
local ROLL_OFF_MAX = 100

local VOL_AMBIENT = 0.3
local VOL_UI = 0.6
local VOL_COMBAT = 0.8

local IDS: { [string]: string } = {
	eat = "rbxassetid://6026984224",
	levelUp = "rbxassetid://6042053626",
	death = "rbxassetid://6042053626",
	kill = "rbxassetid://4612332731",
	chestOpen = "rbxassetid://6026984224",
	titleUnlock = "rbxassetid://4612332731",
	attack = "rbxassetid://9120386446",
	ambientForest = "rbxassetid://1837862028",
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
			local vol = if soundName == "eat" then VOL_UI else VOL_COMBAT
			playOneShotAtParent(id, root, vol)
		else
			local vol = if soundName == "eat" then VOL_UI else VOL_COMBAT
			playOneShot2D(id, vol)
		end
		return
	end

	if soundName == "death" or soundName == "levelUp" or soundName == "kill" or soundName == "titleUnlock" or soundName == "chestOpen" then
		playOneShot2D(id, VOL_UI)
	else
		playOneShot2D(id, VOL_UI)
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
	s.Volume = VOL_AMBIENT
	s.RollOffMaxDistance = ROLL_OFF_MAX
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end

return SoundManager
