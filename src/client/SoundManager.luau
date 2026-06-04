-- Client-side SFX helper (require from LocalScripts only).
-- Plays one-shots by cloning built-in SoundService template Sounds (no rbxassetid).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local LEGACY_AMBIENT_NAME = "EvolveForestAmbient"
local SOUND_VOLUME = 0.5

-- Built-in SoundService child names (see Explorer > SoundService).
local TEMPLATE_BY_SOUND: { [string]: string } = {
	eat = "Action Footsteps Plastic",
	levelUp = "Action Jump",
	death = "Action Get Hit",
	kill = "Action Get Hit",
	chestOpen = "Action Jump",
	titleUnlock = "Action Jump",
	attack = "Slash",
}

local warnedMissing: { [string]: boolean } = {}

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

local function playCloneFromTemplate(templateName: string, parent: Instance, volume: number)
	local t = SoundService:FindFirstChild(templateName)
	if not t or not t:IsA("Sound") then
		if not warnedMissing[templateName] then
			warnedMissing[templateName] = true
			warn("[SoundManager] Missing built-in Sound template:", templateName)
		end
		return
	end
	local s = (t :: Sound):Clone()
	s.Looped = false
	s.Volume = volume
	s.Parent = parent
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function playClone2D(templateName: string, volume: number)
	playCloneFromTemplate(templateName, SoundService, volume)
end

local SoundManager = {}

function SoundManager.playSound(soundName: string)
	local templateName = TEMPLATE_BY_SOUND[soundName]
	if not templateName then
		warn("[SoundManager] Unknown sound:", soundName)
		return
	end

	if soundName == "eat" or soundName == "attack" then
		local root = getLocalRoot()
		if root then
			playCloneFromTemplate(templateName, root, SOUND_VOLUME)
		else
			playClone2D(templateName, SOUND_VOLUME)
		end
		return
	end

	playClone2D(templateName, SOUND_VOLUME)
end

-- Ambient / looping music skipped until we have working assets; remove legacy loop if present.
function SoundManager.startAmbientLoop()
	local existing = SoundService:FindFirstChild(LEGACY_AMBIENT_NAME)
	if existing then
		existing:Destroy()
	end
end

return SoundManager
