-- Client-side SFX helper (require from LocalScripts only).
-- Central place for asset IDs and playback rules.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AMBIENT_NAME = "EvolveForestAmbient"

local IDS: { [string]: string } = {
	eat = "rbxassetid://131961136",
	levelUp = "rbxassetid://4612334716",
	death = "rbxassetid://131070686",
	kill = "rbxassetid://4612334716",
	chestOpen = "rbxassetid://131070759",
	titleUnlock = "rbxassetid://4612334716",
	attack = "rbxassetid://131070689",
	ambientForest = "rbxassetid://1840054027",
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

local function playOneShotAtParent(soundId: string, parent: Instance, volume: number, maxDistance: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	if maxDistance then
		s.RollOffMaxDistance = maxDistance
	end
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
			local vol = if soundName == "eat" then 0.75 else 0.55
			playOneShotAtParent(id, root, vol, 140)
		else
			playOneShot2D(id, 0.65)
		end
		return
	end

	if soundName == "death" then
		playOneShot2D(id, 0.9)
	elseif soundName == "levelUp" or soundName == "kill" or soundName == "titleUnlock" then
		playOneShot2D(id, 0.55)
	elseif soundName == "chestOpen" then
		playOneShot2D(id, 0.65)
	else
		playOneShot2D(id, 0.7)
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
	s.Volume = 0.3
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end

return SoundManager
