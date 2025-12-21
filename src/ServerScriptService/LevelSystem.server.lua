-- LevelSystem.server.lua
-- Handles player leveling up based on experience

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local statsStore = DataStoreService:GetDataStore("PlayerStats")

-- Function to save level and experience to datastore
local function saveLevelToDataStore(player, level, experience, neededExperience)
	local key = "Player_" .. player.UserId
	pcall(function()
		statsStore:UpdateAsync(key, function(data)
			data = data or {}
			data["Level"] = level
			data["Experience"] = experience
			data["NeededExperience"] = neededExperience
			return data
		end)
	end)
	print("[LevelSystem] Saved to datastore: Level=" .. level .. ", Experience=" .. experience .. ", NeededExperience=" .. neededExperience)
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
		
		-- Double the needed experience for next level
		neededExperience.Value = neededExperience.Value * 2
		
		leveledUp = true
		print("[LevelSystem] " .. player.Name .. " leveled up to " .. level.Value .. "! Next level needs " .. neededExperience.Value .. " experience.")
	end
	
	-- Save to datastore if leveled up
	if leveledUp then
		saveLevelToDataStore(player, level.Value, experience.Value, neededExperience.Value)
	end
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
	-- Wait for Stats folder to be created
	local stats = player:WaitForChild("Stats", 5)
	if stats then
		setupLevelMonitoring(player)
	end
end)

-- Also setup for existing players when script loads
for _, player in ipairs(Players:GetPlayers()) do
	setupLevelMonitoring(player)
end
