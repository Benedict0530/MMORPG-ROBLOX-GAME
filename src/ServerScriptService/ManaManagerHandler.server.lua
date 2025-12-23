-- ManaManagerHandler.server.lua
-- Server-side handler for mana-related events
-- Listens to player running state and manages mana drain

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ManaManager = require(ServerScriptService:WaitForChild("ManaManager"))

-- Get or create the running event
local runningEvent = ReplicatedStorage:FindFirstChild("PlayerRunning")
if not runningEvent then
	runningEvent = Instance.new("RemoteEvent")
	runningEvent.Name = "PlayerRunning"
	runningEvent.Parent = ReplicatedStorage
end

-- Listen for running state changes from client
runningEvent.OnServerEvent:Connect(function(player, isRunning)
	if not player or not player.Parent then return end
	ManaManager.SetRunning(player, isRunning)
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	ManaManager.CleanupPlayer(player)
end)
