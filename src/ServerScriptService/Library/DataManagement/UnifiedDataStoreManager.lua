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
	THROTTLE_INTERVAL = 5, -- seconds - INCREASED from 0 to prevent save conflicts
	MAX_RETRIES = 3,
	RETRY_DELAY = 0
}

-- Tracking tables
local lastSaveTime = {} -- Maps userId -> last save timestamp
local pendingChanges = {} -- Maps userId -> {type -> data}
local isSaving = {} -- Maps userId -> whether currently saving
local saveCooldowns = {} -- Maps userId -> next allowed save time (with cooldown)

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
	
	-- Check hard cooldown (prevent DataStore spam)
	if saveCooldowns[userId] and now < saveCooldowns[userId] then
		return false -- Still in cooldown
	end
	
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
		-- Skip folders, only process Value objects
		if stat:IsA("ValueBase") then
			data[stat.Name] = stat.Value
		elseif stat.Name == "Equipped" and stat:IsA("Folder") then
			-- Handle Equipped folder specially (has name/id children, not a Value)
			local nameValue = stat:FindFirstChild("name")
			local idValue = stat:FindFirstChild("id")
			data["Equipped"] = {
				name = nameValue and nameValue.Value or "",
				id = idValue and idValue.Value or ""
			}
		end
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
	
	-- CRITICAL: Verify stats folder exists before attempting save
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[UnifiedDataStoreManager] CRITICAL: Stats folder missing for player " .. userId .. " - aborting save to prevent data loss")
		return false
	end
	
	isSaving[userId] = true
	lastSaveTime[userId] = tick()
	
	-- Set cooldown to prevent spam (minimum 2 seconds between saves per Roblox limits)
	saveCooldowns[userId] = tick() + 2
	
	local success, err = pcall(function()
		statsStore:UpdateAsync("Player_" .. userId, function(oldData)
			-- CRITICAL: Never overwrite with nil or incomplete data
			if not oldData or type(oldData) ~= "table" then
				warn("[UnifiedDataStoreManager] LoadAsync returned nil/invalid for player " .. userId .. " - aborting update to prevent data loss")
				return nil -- Return nil to abort the update
			end
			
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
			else
				warn("[UnifiedDataStoreManager] Stats folder disappeared during save for player " .. userId .. " - aborting")
				return nil
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
	
	-- CRITICAL: Verify player stats exist before saving
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[UnifiedDataStoreManager] CRITICAL: Stats folder missing for player " .. tostring(player.Name) .. " - aborting level save")
		return false
	end
	
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
	
	-- CRITICAL: Verify player stats exist before saving
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[UnifiedDataStoreManager] CRITICAL: Stats folder missing for player " .. tostring(player.Name) .. " - aborting money save")
		return false
	end
	
	markPending(player.UserId, "money")
	return savePlayerDataToStore(player.UserId, forceImmediate)
end

function UnifiedDataStoreManager.MarkMoneyPending(userId)
	markPending(userId, "money")
end

-- ===== WEAPON DATA FUNCTIONS =====
function UnifiedDataStoreManager.SaveWeaponData(userId, weaponData, forceImmediate)
	if not userId then return false end
	
	-- CRITICAL SAFEGUARD: Never save nil or invalid weapon data
	if not weaponData then
		warn("[UnifiedDataStoreManager] WARNING: Weapon data is nil for userId " .. userId .. " - aborting save to prevent data loss")
		return false
	end
	
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
	
	-- CRITICAL SAFEGUARD: Never save nil or invalid inventory data
	if not inventoryData or type(inventoryData) ~= "table" then
		warn("[UnifiedDataStoreManager] CRITICAL: Inventory data is nil or invalid for userId " .. userId .. " - aborting save to prevent data loss")
		return false
	end
	
	-- SAFEGUARD: Never save empty inventory without explicit validation
	if #inventoryData == 0 then
		warn("[UnifiedDataStoreManager] WARNING: Attempting to save EMPTY inventory for userId " .. userId .. " - possible data loss, check if this is intentional")
		-- Still allow save, but log warning - let caller decide if this is ok
	end
	
	-- SAFEGUARD: Detect suspicious inventory sizes that indicate data corruption
	if #inventoryData > 1000 then
		warn("[UnifiedDataStoreManager] CRITICAL: Inventory suspiciously large (" .. #inventoryData .. " items) for userId " .. userId .. " - aborting save to prevent corrupting DataStore")
		return false
	end
	
	if not forceImmediate and not canSaveNow(userId) then
		markPending(userId, "inventory")
		return false
	end
	
	print("[UnifiedDataStoreManager] Saving inventory for userId " .. userId .. " with " .. #inventoryData .. " items")
	for i, item in ipairs(inventoryData) do
		print("[UnifiedDataStoreManager]   Item " .. i .. ": " .. tostring(item.name))
	end
	
	local success, err = pcall(function()
		inventoryStore:SetAsync("Player_" .. userId, inventoryData)
	end)
	
	if success then
		lastSaveTime[userId] = tick()
		clearPending(userId, "inventory")
		print("[UnifiedDataStoreManager] Successfully saved inventory for userId " .. userId)
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
	
	if data then
		print("[UnifiedDataStoreManager] Loaded inventory for userId " .. userId .. ": " .. #data .. " items")
		for i, item in ipairs(data) do
			print("[UnifiedDataStoreManager]   Item " .. i .. ": " .. tostring(item.name or item))
		end
	else
		print("[UnifiedDataStoreManager] No saved inventory data for userId " .. userId .. " (first time player)")
	end
	
	-- Return data even if nil (caller should handle nil case)
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
	
	-- CRITICAL: Verify stats folder exists before attempting any saves
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[UnifiedDataStoreManager] CRITICAL: Stats folder missing for player " .. tostring(player.Name) .. " at disconnect - aborting SaveAll to prevent data loss")
		return false
	end
	
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

-- ===== QUEST DATA FUNCTIONS =====
local QuestDataStore = require(script.Parent:WaitForChild("QuestDataStore"))

function UnifiedDataStoreManager.SaveQuestData(player, forceImmediate)
	if not player or not player.UserId then return false end
	
	if not forceImmediate and not canSaveNow(player.UserId) then
		markPending(player.UserId, "quests")
		return false
	end
	
	local success = QuestDataStore.SaveQuestData(player)
	
	if success then
		lastSaveTime[player.UserId] = tick()
		saveCooldowns[player.UserId] = tick() + CONFIG.THROTTLE_INTERVAL
		clearPending(player.UserId, "quests")
		return true
	else
		markPending(player.UserId, "quests")
		return false
	end
end

function UnifiedDataStoreManager.MarkQuestDataPending(userId)
	markPending(userId, "quests")
end

-- Save all player data including quests
function UnifiedDataStoreManager.SaveAll(player, forceImmediate)
	if not player or not player.UserId then return false end
	
	print("[UnifiedDataStoreManager] Saving ALL data for", player.Name)
	
	-- Save stats
	UnifiedDataStoreManager.SaveStats(player, forceImmediate)
	
	-- Save quest data
	UnifiedDataStoreManager.SaveQuestData(player, forceImmediate)
	
	return true
end

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
					-- Also save quest data if pending
					if pendingChanges[userId].quests then
						UnifiedDataStoreManager.SaveQuestData(player, false)
					end
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
