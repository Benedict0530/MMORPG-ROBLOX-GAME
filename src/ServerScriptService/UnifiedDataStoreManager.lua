-- UnifiedDataStoreManager.lua
-- Centralized DataStore manager for all player data (Stats, Level, Experience, Money, Weapons)
-- Handles throttling, queuing, and safe concurrent modifications

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Get all required data stores
local statsStore = DataStoreService:GetDataStore("PlayerStats")
local weaponDataStore = DataStoreService:GetDataStore("WeaponData")
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

-- Configuration
local SAVE_THROTTLE_INTERVAL = 0 -- Save at most every 1 second per player
local CONFIG = {
	THROTTLE_INTERVAL = 0, -- seconds
	MAX_RETRIES = 3,
	RETRY_DELAY = 0
}

-- Tracking tables
local lastSaveTime = {} -- Maps userId -> last save timestamp
local pendingChanges = {} -- Maps userId -> {type -> data}
local isSaving = {} -- Maps userId -> whether currently saving

-- Initialize pending changes tracking
local function initPlayerTracking(userId)
	if not pendingChanges[userId] then
		pendingChanges[userId] = {
			stats = nil,
			level = nil,
			experience = nil,
			neededExperience = nil,
			money = nil,
			weapons = nil,
			inventory = nil
		}
	end
end

-- Check if enough time has passed for a save
local function canSaveNow(userId)
	local now = tick()
	if not lastSaveTime[userId] then
		return true
	end
	return (now - lastSaveTime[userId]) >= CONFIG.THROTTLE_INTERVAL
end

-- Mark a pending change for a specific data type
local function markPending(userId, dataType)
	initPlayerTracking(userId)
	if pendingChanges[userId] then
		pendingChanges[userId][dataType] = true
	end
end

-- Clear pending changes for a specific data type
local function clearPending(userId, dataType)
	if pendingChanges[userId] then
		pendingChanges[userId][dataType] = nil
	end
end

-- Get all current player stats from memory
local function getCurrentStats(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	
	local data = {}
	for _, stat in ipairs(stats:GetChildren()) do
		data[stat.Name] = stat.Value
	end
	return data
end

-- Save all data to DataStore with unified throttling
local function savePlayerDataToStore(userId, forceImmediate)
	if isSaving[userId] and not forceImmediate then
		return false -- Already saving, skip
	end
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then return false end
	
	-- Check throttle (unless force immediate)
	if not forceImmediate and not canSaveNow(userId) then
		-- Mark changes as pending instead
		if pendingChanges[userId] then
			for dataType in pairs(pendingChanges[userId]) do
				if getCurrentStats(player) or player:FindFirstChild("Stats") then
					pendingChanges[userId][dataType] = true
				end
			end
		end
		return false
	end
	
	isSaving[userId] = true
	lastSaveTime[userId] = tick()
	
	local success, err = pcall(function()
		statsStore:UpdateAsync("Player_" .. userId, function(oldData)
			oldData = oldData or {}
			local stats = player:FindFirstChild("Stats")
			
			if stats then
				-- Save all stats
				for _, stat in ipairs(stats:GetChildren()) do
					-- Special handling for Equipped folder (has name/id children)
					if stat.Name == "Equipped" and stat:IsA("Folder") then
						local nameValue = stat:FindFirstChild("name")
						local idValue = stat:FindFirstChild("id")
						oldData["Equipped"] = {
							name = nameValue and nameValue.Value or "",
							id = idValue and idValue.Value or ""
						}
					else
						-- Regular stats with .Value property
						oldData[stat.Name] = stat.Value
					end
				end
			end
			
			return oldData
		end)
	end)
	
	isSaving[userId] = false
	
	if success then
		-- Clear all pending changes since we just saved everything
		if pendingChanges[userId] then
			for dataType in pairs(pendingChanges[userId]) do
				pendingChanges[userId][dataType] = nil
			end
		end
		return true
	else
		warn("[UnifiedDataStoreManager] Failed to save data for player " .. userId .. ": " .. tostring(err))
		return false
	end
end

-- Public API
local UnifiedDataStoreManager = {}

-- ===== STATS FUNCTIONS =====
function UnifiedDataStoreManager.SaveStats(player, forceImmediate)
	if not player or not player.UserId then return false end
	return savePlayerDataToStore(player.UserId, forceImmediate)
end

function UnifiedDataStoreManager.MarkStatsPending(userId)
	markPending(userId, "stats")
end

-- ===== LEVEL & EXPERIENCE FUNCTIONS =====
function UnifiedDataStoreManager.SaveLevelData(player, forceImmediate)
	if not player or not player.UserId then return false end
	markPending(player.UserId, "level")
	markPending(player.UserId, "experience")
	markPending(player.UserId, "neededExperience")
	return savePlayerDataToStore(player.UserId, forceImmediate)
end

function UnifiedDataStoreManager.MarkLevelPending(userId)
	markPending(userId, "level")
	markPending(userId, "experience")
	markPending(userId, "neededExperience")
end

-- ===== MONEY/COIN FUNCTIONS =====
function UnifiedDataStoreManager.SaveMoney(player, forceImmediate)
	if not player or not player.UserId then return false end
	markPending(player.UserId, "money")
	return savePlayerDataToStore(player.UserId, forceImmediate)
end

function UnifiedDataStoreManager.MarkMoneyPending(userId)
	markPending(userId, "money")
end

-- ===== WEAPON DATA FUNCTIONS =====
function UnifiedDataStoreManager.SaveWeaponData(userId, weaponData, forceImmediate)
	if not userId then return false end
	
	if not forceImmediate and not canSaveNow(userId) then
		markPending(userId, "weapons")
		return false
	end
	
	local success, err = pcall(function()
		weaponDataStore:SetAsync("Player_" .. userId, weaponData)
	end)
	
	if success then
		lastSaveTime[userId] = tick()
		clearPending(userId, "weapons")
		return true
	else
		warn("[UnifiedDataStoreManager] Failed to save weapon data for user " .. userId .. ": " .. tostring(err))
		markPending(userId, "weapons")
		return false
	end
end

function UnifiedDataStoreManager.LoadWeaponData(userId)
	if not userId then return nil end
	
	local data
	local success, err = pcall(function()
		data = weaponDataStore:GetAsync("Player_" .. userId)
	end)
	
	if not success then
		warn("[UnifiedDataStoreManager] Failed to load weapon data for user " .. userId .. ": " .. tostring(err))
		return nil
	end
	
	return data
end

function UnifiedDataStoreManager.DeleteWeaponData(userId)
	if not userId then return false end
	
	local success, err = pcall(function()
		weaponDataStore:RemoveAsync("Player_" .. userId)
	end)
	
	if not success then
		warn("[UnifiedDataStoreManager] Failed to delete weapon data for user " .. userId .. ": " .. tostring(err))
	end
	
	return success
end

-- ===== INVENTORY FUNCTIONS =====
function UnifiedDataStoreManager.SaveInventory(userId, inventoryData, forceImmediate)
	if not userId then return false end
	
	if not forceImmediate and not canSaveNow(userId) then
		markPending(userId, "inventory")
		return false
	end
	
	local success, err = pcall(function()
		inventoryStore:SetAsync("Player_" .. userId, inventoryData)
	end)
	
	if success then
		lastSaveTime[userId] = tick()
		clearPending(userId, "inventory")
		return true
	else
		warn("[UnifiedDataStoreManager] Failed to save inventory for user " .. userId .. ": " .. tostring(err))
		markPending(userId, "inventory")
		return false
	end
end

function UnifiedDataStoreManager.LoadInventory(userId)
	if not userId then return nil end
	
	local data
	local success, err = pcall(function()
		data = inventoryStore:GetAsync("Player_" .. userId)
	end)
	
	if not success then
		warn("[UnifiedDataStoreManager] Failed to load inventory for user " .. userId .. ": " .. tostring(err))
		return nil
	end
	
	return data
end

function UnifiedDataStoreManager.MarkInventoryPending(userId)
	markPending(userId, "inventory")
end

-- ===== ENEMY STATS FUNCTIONS =====
local enemyStatsStore = DataStoreService:GetDataStore("EnemyStats")

function UnifiedDataStoreManager.SaveEnemyStats(enemyName, stats)
	local success, err = pcall(function()
		enemyStatsStore:SetAsync(enemyName, stats)
	end)
	
	if success then
		return true
	else
		warn("[UnifiedDataStoreManager] Failed to save enemy stats for " .. enemyName .. ": " .. tostring(err))
		return false
	end
end

function UnifiedDataStoreManager.LoadEnemyStats(enemyName)
	local stats
	local success, err = pcall(function()
		stats = enemyStatsStore:GetAsync(enemyName)
	end)
	
	if not success then
		warn("[UnifiedDataStoreManager] Failed to load enemy stats for " .. enemyName .. ": " .. tostring(err))
		return nil
	end
	
	return stats
end

-- ===== BATCH OPERATIONS =====
-- Save all pending data for a player (called on disconnect)
function UnifiedDataStoreManager.SaveAll(player, forceImmediate)
	if not player or not player.UserId then return false end
	
	local userId = player.UserId
	initPlayerTracking(userId)
	
	-- Check all pending changes and save
	local hasPending = false
	if pendingChanges[userId] then
		for _, isPending in pairs(pendingChanges[userId]) do
			if isPending then
				hasPending = true
				break
			end
		end
	end
	
	-- Save all player stats in one operation
	return savePlayerDataToStore(userId, forceImmediate or hasPending)
end

-- Initialize player tracking on join
Players.PlayerAdded:Connect(function(player)
	initPlayerTracking(player.UserId)
end)

-- Cleanup on disconnect
Players.PlayerRemoving:Connect(function(player)
	-- Force save all pending data
	UnifiedDataStoreManager.SaveAll(player, true)
	
	-- Cleanup tracking tables
	lastSaveTime[player.UserId] = nil
	pendingChanges[player.UserId] = nil
	isSaving[player.UserId] = nil
end)

-- Periodic heartbeat to save pending changes that are due
game:GetService("RunService").Heartbeat:Connect(function()
	for userId in pairs(pendingChanges) do
		if canSaveNow(userId) then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				-- Check if there are any pending changes
				local hasPending = false
				for _, isPending in pairs(pendingChanges[userId]) do
					if isPending then
						hasPending = true
						break
					end
				end
				
				if hasPending then
					savePlayerDataToStore(userId, false)
				end
			end
		end
	end
end)

-- Server shutdown handler
if game:IsA("DataModel") then
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			UnifiedDataStoreManager.SaveAll(player, true)
		end
	end)
end

return UnifiedDataStoreManager
