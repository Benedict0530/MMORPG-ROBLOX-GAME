local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SFXEvent = ReplicatedStorage:FindFirstChild("SFXEvent")
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)
local ProximitySoundEvent = ReplicatedStorage:WaitForChild("PlayProximitySound")


SFXEvent.OnClientEvent:Connect(function(soundName)
	SoundModule.playSoundByName(soundName, "SFX", false, 1)
end)

-- Listen for proximity sounds

ProximitySoundEvent.OnClientEvent:Connect(function(soundName, group, loop, duration)
	SoundModule.playSoundByName(soundName, group, loop, duration)
end)
