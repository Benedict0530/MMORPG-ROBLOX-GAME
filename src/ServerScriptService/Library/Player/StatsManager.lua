-- StatsManager.lua
-- Manages player stat point allocation and upgrades
-- All saves are delegated to UnifiedDataStoreManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("OrbSpiritHandler"))

-- Create RemoteEvent for stat allocation
local statsUpdateEvent = ReplicatedStorage:FindFirstChild("AllocateStatPoint")
if not statsUpdateEvent then
	statsUpdateEvent = Instance.new("RemoteEvent")
	statsUpdateEvent.Name = "AllocateStatPoint"
	statsUpdateEvent.Parent = ReplicatedStorage
end

-- Create RemoteEvent to trigger UI refresh when stats are updated
local refreshStatsUIEvent = ReplicatedStorage:FindFirstChild("RefreshStatsUI")
if not refreshStatsUIEvent then
	refreshStatsUIEvent = Instance.new("RemoteEvent")
	refreshStatsUIEvent.Name = "RefreshStatsUI"
	refreshStatsUIEvent.Parent = ReplicatedStorage
end

-- Stat costs (points per increase)
local STAT_COST = 1

-- Maximum stat values (optional cap)
-- Only Dexterity has a max limit, all other stats are unlimited
local MAX_STAT_VALUES = {
	Dexterity = 300
}

local function saveStatsToDataStore(player, reason)
	-- Delegate to UnifiedDataStoreManager (strip orb bonuses for stat changes)
	UnifiedDataStoreManager.SaveStats(player, false)
end

local function allocateStatPoint(player, statType)
	local stats = player:FindFirstChild("Stats")
	if not stats then
		return false
	end
	
	-- Check if statType is valid
	if not (statType == "MaxHealth" or statType == "MaxMana" or statType == "Attack" or statType == "Defence" or statType == "Dexterity") then
		return false
	end
	
	-- SUSPEND stat change listeners AND prevent orb switch operations
	-- [REMOVED] OrbSpiritHandler.SetAdminStatChangeFlag
	local userId = player.UserId
	
	local statPoints = stats:FindFirstChild("StatPoints")
	local statValue = stats:FindFirstChild(statType)
	
	if not statPoints or not statValue then
		-- [REMOVED] OrbSpiritHandler.SetAdminStatChangeFlag
		return false
	end
	
	-- Check if player has enough stat points
	if statPoints.Value < STAT_COST then
		OrbSpiritHandler.SetAdminStatChangeFlag(player, false)
		return false
	end
	
	-- Check if stat is at max (only Dexterity has a limit)
	local maxValue = MAX_STAT_VALUES[statType]
	if maxValue and statValue.Value >= maxValue then
		OrbSpiritHandler.SetAdminStatChangeFlag(player, false)
		return false
	end
	
	-- Allocate the point
	statPoints.Value = statPoints.Value - STAT_COST
	
	-- Different increases for different stats
	if statType == "MaxHealth" then
		statValue.Value = statValue.Value + 10
		local currentHealth = stats:FindFirstChild("CurrentHealth")
		if currentHealth then
			currentHealth.Value = currentHealth.Value + 10
		end
	elseif statType == "MaxMana" then
		statValue.Value = statValue.Value + 5
		local currentMana = stats:FindFirstChild("CurrentMana")
		if currentMana then
			currentMana.Value = currentMana.Value + 5
		end
	else
		-- Attack, Defence, Dexterity all increase by 1
		statValue.Value = statValue.Value + 1
	end
	
	-- Save to DataStore (throttled)
	saveStatsToDataStore(player, " (Stat allocation: " .. statType .. ")")
	
	-- Small delay to ensure stat value changes have fully propagated
	task.wait(0.01)
	
	-- Update base stats cache to reflect the new allocation (for UI to display correctly)
	-- This will remove orb bonuses, update base, and reapply orb if needed (no double buff)
	-- [REMOVED] OrbSpiritHandler.UpdateBaseStats

	-- Delay to ensure cache update completes before UI reads it
	task.wait(0.05)
	
	-- Trigger UI refresh on the client to pull fresh base stats from server
	refreshStatsUIEvent:FireClient(player)
	
	-- RESUME stat change listeners
	OrbSpiritHandler.SetAdminStatChangeFlag(player, false)
	
	return true
end

local function resetStats(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return false end
	
	local level = stats:FindFirstChild("Level")
	if not level then return false end
	
	local resetPoints = stats:FindFirstChild("ResetPoints")
	if not resetPoints then return false end
	
	-- Check if player has reset points available
	if resetPoints.Value <= 0 then
		return false
	end
	
	-- SUSPEND stat change listeners to prevent recursion
	OrbSpiritHandler.SetAdminStatChangeFlag(player, true)
	
	-- Check if already at default stats to prevent giving extra points
	local baseStats = {
		MaxHealth = 10,
		MaxMana = 5,
		Attack = 1,
		Defence = 1,
		Dexterity = 1
	}
	
	local isAtDefault = true
	for statName, baseValue in pairs(baseStats) do
		local stat = stats:FindFirstChild(statName)
		if not stat or stat.Value ~= baseValue then
			isAtDefault = false
			break
		end
	end
	
	-- If already at default stats, just decrement reset points (don't add extra stat points)
	if isAtDefault then
		resetPoints.Value = resetPoints.Value - 1
		saveStatsToDataStore(player, " (Stats Reset - Already at default - " .. resetPoints.Value .. " resets remaining)")
		OrbSpiritHandler.SetAdminStatChangeFlag(player, false)
		return true
	end
	
	-- Decrement reset points
	resetPoints.Value = resetPoints.Value - 1
	
	-- Calculate total stat points based on actual stat increases from defaults
	-- considering the cost per point for each stat
	local baseStats = {
		MaxHealth = 10,
		MaxMana = 5,
		Attack = 1,
		Defence = 1,
		Dexterity = 1
	}
	
	local statIncreaseAmounts = {
		MaxHealth = 10,  -- Each point adds 10
		MaxMana = 5,      -- Each point adds 5
		Attack = 1,       -- Each point adds 1
		Defence = 1,      -- Each point adds 1
		Dexterity = 1     -- Each point adds 1
	}
	
	local totalStatPoints = 0
	for statName, baseValue in pairs(baseStats) do
		local stat = stats:FindFirstChild(statName)
		if stat then
			local currentValue = stat.Value
			local increaseAmount = statIncreaseAmounts[statName]
			-- Calculate points spent: (current - base) / increase per point
			local pointsSpent = math.floor((currentValue - baseValue) / increaseAmount)
			if pointsSpent > 0 then
				totalStatPoints = totalStatPoints + pointsSpent
			end
		end
	end
	
	-- Reset stats to base values
	for statName, baseValue in pairs(baseStats) do
		local stat = stats:FindFirstChild(statName)
		if stat then
			stat.Value = baseValue
		end
	end
	
	-- Also reset current health/mana to max
	local currentHealth = stats:FindFirstChild("CurrentHealth")
	local maxHealthStat = stats:FindFirstChild("MaxHealth")
	if currentHealth and maxHealthStat then
		currentHealth.Value = maxHealthStat.Value
	end
	
	local currentMana = stats:FindFirstChild("CurrentMana")
	local maxManaStat = stats:FindFirstChild("MaxMana")
	if currentMana and maxManaStat then
		currentMana.Value = maxManaStat.Value
	end
	
	-- Add stat points to the total available (in case player got points from other sources)
	local statPoints = stats:FindFirstChild("StatPoints")
	if statPoints then
		statPoints.Value = statPoints.Value + totalStatPoints
	end
	
	-- Save to DataStore
	saveStatsToDataStore(player, " (Stats Reset - " .. resetPoints.Value .. " resets remaining)")
	
	-- Small delay to ensure stat changes have fully propagated
	task.wait(0.01)
	
	-- Update base stats cache to reflect the reset (for UI to display correctly)
	OrbSpiritHandler.UpdateBaseStats(player)
	
	-- Delay to ensure cache update completes before UI reads it
	task.wait(0.05)
	
	-- Trigger UI refresh on the client to pull fresh base stats from server
	refreshStatsUIEvent:FireClient(player)
	
	-- RESUME stat change listeners
	OrbSpiritHandler.SetAdminStatChangeFlag(player, false)
	
	return true
end

-- Handle stat allocation requests from client
statsUpdateEvent.OnServerEvent:Connect(function(player, action, statType)
	if action == "Allocate" then
		allocateStatPoint(player, statType)
	elseif action == "Reset" then
		resetStats(player)
	end
end)

return {
	allocateStatPoint = allocateStatPoint,
	resetStats = resetStats
}
