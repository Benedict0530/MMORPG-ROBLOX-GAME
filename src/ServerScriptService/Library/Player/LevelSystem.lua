-- LevelSystem.lua
-- Handles player leveling up based on experience
-- All saves are delegated to UnifiedDataStoreManager

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local SFXEvent = ReplicatedStorage:FindFirstChild("SFXEvent")

-- Function to save level and experience to datastore (throttled)
local function saveLevelToDataStore(player, level, experience, neededExperience, reason)
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveLevelData(player, false)
end

-- Function to check if player should level up
local function checkLevelUp(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	
	local level = stats:FindFirstChild("Level")
	local experience = stats:FindFirstChild("Experience")
	local neededExperience = stats:FindFirstChild("NeededExperience")
	
	if not level or not experience or not neededExperience then return end
	
	-- Check if experience >= neededExperience
	local leveledUp = false
	while experience.Value >= neededExperience.Value do
		-- Level up!
		level.Value = level.Value + 1
		experience.Value = experience.Value - neededExperience.Value
		
		neededExperience.Value = neededExperience.Value * 1.2
		
		-- Grant 3 stat points per level
		local statPoints = stats:FindFirstChild("StatPoints")
		if statPoints then
			statPoints.Value = statPoints.Value + 3
		end
		SFXEvent:FireClient(player, "LevelUp")
		leveledUp = true
	end
	
	-- Save to datastore (whether leveled up or just gained exp)
	saveLevelToDataStore(player, level.Value, experience.Value, neededExperience.Value, leveledUp and " (Level Up)" or " (Experience Gain)")
end

-- Function to setup level monitoring for a player
local function setupLevelMonitoring(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	
	local experience = stats:FindFirstChild("Experience")
	if experience then
		-- Connect to experience changes
		experience.Changed:Connect(function()
			checkLevelUp(player)
		end)
	end
end

-- Monitor new players when they join
Players.PlayerAdded:Connect(function(player)
	-- Use task.spawn to ensure this doesn't block other PlayerAdded handlers
	task.spawn(function()
		-- Wait for PlayerDataStore to initialize stats folder
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local playerSignalsFolder = ReplicatedStorage:WaitForChild("PlayerInitSignals", 10)
		if not playerSignalsFolder then
			warn("[LevelSystem] PlayerInitSignals folder not found for " .. player.Name)
			return
		end
		
		local signalName = "Player_" .. player.UserId
		-- Wait for stats ready signal
		local statsReadySignal = playerSignalsFolder:WaitForChild(signalName, 10)
		if not statsReadySignal then
			warn("[LevelSystem] Stats ready signal not found for " .. player.Name)
			return
		end
		
		-- Check if signal was already fired (check _Fired flag)
		local firedFlag = statsReadySignal:FindFirstChild("_Fired")
		if not firedFlag or not firedFlag.Value then
			-- Wait for stats ready signal to fire
			statsReadySignal.Event:Wait()
		end
		-- Stats are now ready
		
		-- Now setup level monitoring
		setupLevelMonitoring(player)
	end)
end)

-- Also setup for existing players when script loads
for _, player in ipairs(Players:GetPlayers()) do
	setupLevelMonitoring(player)
end

-- Cleanup on player disconnect
Players.PlayerRemoving:Connect(function(player)
	-- Force save all data - delegated to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveAll(player, true)
end)

return {
	checkLevelUp = checkLevelUp,
	setupLevelMonitoring = setupLevelMonitoring
}
