-- PlayerDisconnectHandler.server.lua
-- Centralized handler for saving all player data on disconnect
-- Uses UnifiedDataStoreManager to coordinate all saves

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))

local function savePlayerDataOnDisconnect(player)
	-- Save all player data through unified manager (handles all data types at once)
	-- This includes: Stats, Level, Experience, Money, Weapons, Inventory, and Enemies
	task.spawn(function()
		pcall(function()
			UnifiedDataStoreManager.SaveAll(player, true)
		end)
	end)
end

-- Centralized player removal handler
Players.PlayerRemoving:Connect(function(player)
	-- Run disconnect save sequence
	task.spawn(function()
		savePlayerDataOnDisconnect(player)
	end)
end)

-- [PlayerDisconnectHandler] loaded - uses UnifiedDataStoreManager for coordinated saves
