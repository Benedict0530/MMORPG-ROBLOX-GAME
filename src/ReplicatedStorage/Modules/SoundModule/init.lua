-- SoundModule.lua
local SoundService = game:GetService("SoundService")

local SoundModule = {}

-- Define your sound groups
local BGMGroup = SoundService:WaitForChild("BGMGroup")
local SFXGroup = SoundService:WaitForChild("SFXGroup")

function SoundModule.getCurrentlyPlayingBGM()
	for _, sound in pairs(SoundService:GetChildren()) do
		if sound:IsA("Sound") and sound.SoundGroup == BGMGroup and sound.IsPlaying then
			return sound
		end
	end
	return nil
end

function SoundModule.playSoundByName(name, group, loop, duration)
	local sourceGroup

	if group == "SFX" then
		sourceGroup = SFXGroup
	elseif group == "BGM" then
		sourceGroup = BGMGroup
	else
		warn("Invalid group: " .. tostring(group))
		return
	end

	local soundTemplate = sourceGroup:FindFirstChild(name)
	if not soundTemplate then
		warn("Sound not found in group " .. group .. ": " .. name)
		return
	end

	local sound = soundTemplate:Clone()
	sound.Parent = SoundService
	-- Only set SoundGroup if the template has it (avoid setting a Folder)
	if soundTemplate.SoundGroup then
		sound.SoundGroup = soundTemplate.SoundGroup
	end
	sound.Looped = loop or false
	sound:Play()

	if duration then
		task.delay(duration, function()
			if sound and sound:IsDescendantOf(SoundService) then
				sound:Stop()
			end
		end)
	end

	local function cleanup()
		if sound then
			sound:Destroy()
		end
	end

	if not sound.Looped then
		sound.Ended:Connect(cleanup)
	end

	return sound
end

function SoundModule.stopAllLoopedSFX()
    for _, sound in pairs(SoundService:GetChildren()) do
        if sound:IsA("Sound") and sound.SoundGroup == SFXGroup and sound.Looped and sound.IsPlaying then
            sound:Stop()
        end
    end
end

function SoundModule.playSoundInRange(name, position, group, range, loop, duration)
	-- Get or create the remote event for proximity sounds
	local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("PlayProximitySound")
	
	if not RemoteEvent then
		RemoteEvent = Instance.new("RemoteEvent")
		RemoteEvent.Name = "PlayProximitySound"
		RemoteEvent.Parent = game:GetService("ReplicatedStorage")
	end

	-- Validate sound exists
	local sourceGroup
	if group == "SFX" then
		sourceGroup = SFXGroup
	elseif group == "BGM" then
		sourceGroup = BGMGroup
	else
		warn("Invalid group: " .. tostring(group))
		return
	end

	local soundTemplate = sourceGroup:FindFirstChild(name)
	if not soundTemplate then
		warn("Sound not found in group " .. group .. ": " .. name)
		return
	end

	-- Find all players within range
	local playersInRange = {}
	local Players = game:GetService("Players")
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPos = player.Character.HumanoidRootPart.Position
			local distance = (playerPos - position).Magnitude
			
			if distance <= range then
				table.insert(playersInRange, player)
			end
		end
	end

	-- Fire the RemoteEvent to each player in range
	for _, player in pairs(playersInRange) do
		RemoteEvent:FireClient(player, name, group, loop, duration)
	end
end

return SoundModule