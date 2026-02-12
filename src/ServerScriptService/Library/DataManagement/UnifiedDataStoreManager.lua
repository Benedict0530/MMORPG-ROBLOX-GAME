-- UnifiedDataStoreManager.lua

local UnifiedDataStoreManager = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Get all required data stores
local statsStore = DataStoreService:GetDataStore("PlayerStats")
local weaponDataStore = DataStoreService:GetDataStore("WeaponData")
local orbDataStore = DataStoreService:GetDataStore("OrbData")
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")
local dungeonTimerStore = DataStoreService:GetDataStore("DungeonTimers")

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
-- In-memory caches for all player data types (per server session)
local playerStatsCache = {}
local inventoryCache = {}
local weaponDataCache = {}
local orbDataCache = {}
local dungeonTimerCache = {} -- [userId] = {toMap, endTime}
-- ===== DUNGEON TIMER FUNCTIONS =====
function UnifiedDataStoreManager.SaveDungeonTimer(userId, toMap, endTime, forceImmediate)
	if not userId or not toMap or not endTime then return false end
	-- Save to cache
	dungeonTimerCache[userId] = {toMap = toMap, endTime = endTime}
	-- Save to DataStore
	local success, err = pcall(function()
		dungeonTimerStore:SetAsync("Player_" .. userId, {toMap = toMap, endTime = endTime})
	end)
	if not success then
		warn("[UnifiedDataStoreManager] Failed to save dungeon timer for user " .. userId .. ": " .. tostring(err))
		return false
	end
	return true
end

function UnifiedDataStoreManager.LoadDungeonTimer(userId)
	if not userId then return nil end
	-- Check cache first
	if dungeonTimerCache[userId] then
		return dungeonTimerCache[userId]
	end
	local data
	local success, err = pcall(function()
		data = dungeonTimerStore:GetAsync("Player_" .. userId)
	end)
	if not success then
		warn("[UnifiedDataStoreManager] Failed to load dungeon timer for user " .. userId .. ": " .. tostring(err))
		return nil
	end
	if data then
		dungeonTimerCache[userId] = data
	end
	return data
end

function UnifiedDataStoreManager.ClearDungeonTimer(userId)
	if not userId then return false end
	dungeonTimerCache[userId] = nil
	local success, err = pcall(function()
		dungeonTimerStore:RemoveAsync("Player_" .. userId)
	end)
	if not success then
		warn("[UnifiedDataStoreManager] Failed to clear dungeon timer for user " .. userId .. ": " .. tostring(err))
		return false
	end
	return true
end

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
			       }	       elseif stat.Name == "SecondaryEquipped" and stat:IsA("Folder") then
		       local nameValue = stat:FindFirstChild("name")
		       local idValue = stat:FindFirstChild("id")
		       data["SecondaryEquipped"] = {
			       name = nameValue and nameValue.Value or "",
			       id = idValue and idValue.Value or ""
		       }		       elseif stat.Name == "EquippedOrb" and stat:IsA("Folder") then
			       local nameValue = stat:FindFirstChild("name")
			       local idValue = stat:FindFirstChild("id")
			       data["EquippedOrb"] = {
				       name = nameValue and nameValue.Value or "",
				       id = idValue and idValue.Value or ""
			       }
			   elseif (stat.Name == "EquippedSuit" or stat.Name == "EquippedHelmet" or stat.Name == "EquippedLegs" or stat.Name == "EquippedShoes") and stat:IsA("Folder") then
				  local nameValue = stat:FindFirstChild("name")
				  local idValue = stat:FindFirstChild("id")
				  data[stat.Name] = {
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
		statsStore:UpdateAsync("Player_" .. userId, function(_)
			-- Always build a fresh data table from current in-memory stats
			local stats = player:FindFirstChild("Stats")
			if not stats then
				warn("[UnifiedDataStoreManager] Stats folder disappeared during save for player " .. userId .. " - aborting")
				return nil
			end
			   local newData = {}
			   for _, stat in ipairs(stats:GetChildren()) do
				   if stat:IsA("ValueBase") then
					   newData[stat.Name] = stat.Value
				   elseif stat.Name == "Equipped" and stat:IsA("Folder") then
					   local nameValue = stat:FindFirstChild("name")
					   local idValue = stat:FindFirstChild("id")
					   newData["Equipped"] = {
						   name = nameValue and nameValue.Value or "",
						   id = idValue and idValue.Value or ""
					   }
				   elseif stat.Name == "SecondaryEquipped" and stat:IsA("Folder") then
					   local nameValue = stat:FindFirstChild("name")
					   local idValue = stat:FindFirstChild("id")
					   newData["SecondaryEquipped"] = {
						   name = nameValue and nameValue.Value or "",
						   id = idValue and idValue.Value or ""
					   }
				   elseif stat.Name == "EquippedOrb" and stat:IsA("Folder") then
					   local nameValue = stat:FindFirstChild("name")
					   local idValue = stat:FindFirstChild("id")
					   newData["EquippedOrb"] = {
						   name = nameValue and nameValue.Value or "",
						   id = idValue and idValue.Value or ""
					   }
					   --print("[UnifiedDataStoreManager] (UpdateAsync) Writing EquippedOrb for userId " .. tostring(userId) .. ": name='" .. (nameValue and nameValue.Value or "nil") .. "', id='" .. (idValue and idValue.Value or "nil") .. "'")
				   elseif (stat.Name == "EquippedSuit" or stat.Name == "EquippedHelmet" or stat.Name == "EquippedLegs" or stat.Name == "EquippedShoes") and stat:IsA("Folder") then
					  local nameValue = stat:FindFirstChild("name")
					  local idValue = stat:FindFirstChild("id")
					  newData[stat.Name] = {
						  name = nameValue and nameValue.Value or "",
						  id = idValue and idValue.Value or ""
					  }
				   end
			   end
			   --print("[UnifiedDataStoreManager] (UpdateAsync) FINAL DATA WRITTEN for userId " .. tostring(userId) .. ": " .. game:GetService("HttpService"):JSONEncode(newData))
			   return newData
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
		warn("[UnifiedDataStoreManager] ❌ FAILED to save data for user " .. userId)
		warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		end
		return false
	end
end


-- ===== STATS FUNCTIONS =====
function UnifiedDataStoreManager.SaveStats(player, forceImmediate)
	   if not player or not player.UserId then return false end
	   -- Always remove orb stat bonuses before saving to ensure only base stats are saved
	   local OrbSpiritHandler = require(game:GetService("ServerScriptService"):WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
	-- [REMOVED] OrbSpiritHandler.RemoveOrbStatBonuses
	   local success = savePlayerDataToStore(player.UserId, forceImmediate)
	   -- Update cache with latest stats
	   if success then
		   local stats = player:FindFirstChild("Stats")
		   if stats then
			   local data = {}
			   for _, stat in ipairs(stats:GetChildren()) do
				   if stat:IsA("ValueBase") then
					   data[stat.Name] = stat.Value
				   end
			   end
			   playerStatsCache[player.UserId] = data
		   end
		   -- Only reapply if the player still exists and has an orb equipped
		   local equippedOrbFolder = stats and stats:FindFirstChild("EquippedOrb")
		   if equippedOrbFolder and equippedOrbFolder:IsA("Folder") then
			   local orbNameValue = equippedOrbFolder:FindFirstChild("name")
			   local orbName = orbNameValue and orbNameValue.Value or ""
			   if orbName ~= "" then
				   -- [REMOVED] OrbSpiritHandler.ApplyOrbStatBonuses
			   end
		   end
	   end
	   return success
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
		   weaponDataCache[userId] = weaponData
		   return true
	   else
		   warn("[UnifiedDataStoreManager] ❌ FAILED to save weapon data for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   markPending(userId, "weapons")
		   return false
	   end
end

function UnifiedDataStoreManager.LoadWeaponData(userId)
	if not userId then return nil end
	
	   -- Check cache first
	   if weaponDataCache[userId] then
		   return weaponDataCache[userId]
	   end
	   local data
	   local success, err = pcall(function()
		   data = weaponDataStore:GetAsync("Player_" .. userId)
	   end)
	   if not success then
		   warn("[UnifiedDataStoreManager] ❌ FAILED to load weapon data for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   return nil
	   end
	   if data then
		   weaponDataCache[userId] = data
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

-- ===== ORB DATA FUNCTIONS =====
function UnifiedDataStoreManager.SaveOrbData(userId, orbData, forceImmediate)
	if not userId then return false end
	
	-- CRITICAL SAFEGUARD: Never save nil or invalid orb data
	if not orbData then
		warn("[UnifiedDataStoreManager] WARNING: Orb data is nil for userId " .. userId .. " - aborting save to prevent data loss")
		return false
	end
	
	if not forceImmediate and not canSaveNow(userId) then
		markPending(userId, "orbs")
		return false
	end
	
	local success, err = pcall(function()
		orbDataStore:SetAsync("Player_" .. userId, orbData)
	end)
	
	   if success then
		   lastSaveTime[userId] = tick()
		   clearPending(userId, "orbs")
		   orbDataCache[userId] = orbData
		   return true
	   else
		   warn("[UnifiedDataStoreManager] ❌ FAILED to save orb data for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   markPending(userId, "orbs")
		   return false
	   end
end

function UnifiedDataStoreManager.LoadOrbData(userId)
	if not userId then return nil end
	
	   -- Check cache first
	   if orbDataCache[userId] then
		   return orbDataCache[userId]
	   end
	   local data
	   local success, err = pcall(function()
		   data = orbDataStore:GetAsync("Player_" .. userId)
	   end)
	   if not success then
		   warn("[UnifiedDataStoreManager] ❌ FAILED to load orb data for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   return nil
	   end
	   if data then
		   orbDataCache[userId] = data
	   end
	   return data
end

function UnifiedDataStoreManager.DeleteOrbData(userId)
	if not userId then return false end
	
	local success, err = pcall(function()
		orbDataStore:RemoveAsync("Player_" .. userId)
	end)
	
	if not success then
		warn("[UnifiedDataStoreManager] Failed to delete orb data for user " .. userId .. ": " .. tostring(err))
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
	
	--print("[UnifiedDataStoreManager] Saving inventory for userId " .. userId .. " with " .. #inventoryData .. " items")
	for i, item in ipairs(inventoryData) do
		--print("[UnifiedDataStoreManager]   Item " .. i .. ": " .. tostring(item.name))
	end
	
	local success, err = pcall(function()
		inventoryStore:SetAsync("Player_" .. userId, inventoryData)
	end)
	
	   if success then
		   lastSaveTime[userId] = tick()
		   clearPending(userId, "inventory")
		   inventoryCache[userId] = inventoryData
		   --print("[UnifiedDataStoreManager] Successfully saved inventory for userId " .. userId)
		   return true
	   else
		   warn("[UnifiedDataStoreManager] ❌ FAILED to save inventory for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   markPending(userId, "inventory")
		   return false
	   end
end

function UnifiedDataStoreManager.LoadInventory(userId)
	if not userId then return nil end
	
	   -- Check cache first
	   if inventoryCache[userId] then
		   return inventoryCache[userId]
	   end
	   local data
	   local success, err = pcall(function()
		   data = inventoryStore:GetAsync("Player_" .. userId)
	   end)
	   if not success then
		   warn("[UnifiedDataStoreManager] ❌ FAILED to load inventory for user " .. userId)
		   warn("[UnifiedDataStoreManager] Error: " .. tostring(err))
		   if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			   warn("[UnifiedDataStoreManager] ⚠️  Studio Access to API Services may be DISABLED!")
		   end
		   return nil
	   end
	   if data then
		   --print("[UnifiedDataStoreManager] Loaded inventory for userId " .. userId .. ": " .. #data .. " items")
		   for i, item in ipairs(data) do
			   --print("[UnifiedDataStoreManager]   Item " .. i .. ": " .. tostring(item.name or item))
		   end
		   inventoryCache[userId] = data
	   else
		   --print("[UnifiedDataStoreManager] No saved inventory data for userId " .. userId .. " (first time player)")
	   end
	   -- Return data even if nil (caller should handle nil case)
	   return data
end

function UnifiedDataStoreManager.MarkInventoryPending(userId)
	markPending(userId, "inventory")
end

-- ===== ENEMY STATS FUNCTIONS =====

local enemyStatsStore = DataStoreService:GetDataStore("EnemyStats")
-- In-memory cache for enemy stats (per server session)
local enemyStatsCache = {}

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
	-- Check cache first
	if enemyStatsCache[enemyName] then
		return enemyStatsCache[enemyName]
	end
	local stats
	local success, err = pcall(function()
		stats = enemyStatsStore:GetAsync(enemyName)
	end)
	if not success then
		warn("[UnifiedDataStoreManager] Failed to load enemy stats for " .. enemyName .. ": " .. tostring(err))
		return nil
	end
	if stats then
		enemyStatsCache[enemyName] = stats
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
-- PlayerAdded handler moved to Init.server.lua for centralized initialization
-- initPlayerTracking is called from Init.server.lua

-- Cleanup on disconnect
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- CRITICAL FIX: Clear pending changes to prevent queued saves with buffed stats
	-- This ensures no old saves will execute after the player leaves
	if pendingChanges[userId] then
		for dataType in pairs(pendingChanges[userId]) do
			pendingChanges[userId][dataType] = nil
		end
	end


	-- Wait a brief moment to ensure any in-progress saves complete
	task.wait(0.05)

	-- FINAL: Force immediate save of ALL data (stats, quests, etc.)
	--print("[UnifiedDataStoreManager] Forcing final save of ALL data for userId " .. tostring(userId))
	UnifiedDataStoreManager.SaveAll(player, true)

	-- Cleanup tracking tables
	lastSaveTime[userId] = nil
	pendingChanges[userId] = nil
	isSaving[userId] = nil
	saveCooldowns[userId] = nil
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
	
	--print("[UnifiedDataStoreManager] Saving ALL data for", player.Name)
	
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

-- ===== RESET FUNCTIONS (FOR TESTING/ADMIN) =====
function UnifiedDataStoreManager.ResetPlayerData(userId)
	local success = false
	
	-- Reset stats store
	local statsSuccess = pcall(function()
		statsStore:RemoveAsync(tostring(userId))
	end)
	
	-- Reset weapon data
	local weaponSuccess = pcall(function()
		weaponDataStore:RemoveAsync(tostring(userId))
	end)
	
	-- Reset orb data
	local orbSuccess = pcall(function()
		orbDataStore:RemoveAsync(tostring(userId))
	end)
	
	-- Reset inventory
	local inventorySuccess = pcall(function()
		inventoryStore:RemoveAsync(tostring(userId))
	end)
	
	-- Reset quest data
	local questSuccess = pcall(function()
		local questStore = DataStoreService:GetDataStore("PlayerQuests")
		questStore:RemoveAsync(tostring(userId))
	end)
	
	-- Clear local tracking
	lastSaveTime[userId] = nil
	saveCooldowns[userId] = nil
	isSaving[userId] = nil
	pendingChanges[userId] = nil
	
	success = statsSuccess and weaponSuccess and orbSuccess and inventorySuccess and questSuccess
	
	if success then
		--print("[UnifiedDataStoreManager] Successfully reset ALL data (stats, weapons, orbs, inventory, quests) for user " .. userId)
	else
		warn("[UnifiedDataStoreManager] Failed to reset some data for user " .. userId)
	end
	
	return success
end

function UnifiedDataStoreManager.ResetAllPlayersData()
	local successCount = 0
	local failureCount = 0
	
	-- Function to clear all entries from a DataStore using cursors
	local function clearDataStore(dataStore, storeName)
		local success = pcall(function()
			local cursor = dataStore:ListKeysAsync()
			while true do
				local keys = cursor:GetCurrentPage()
				if #keys == 0 then break end
				
				for _, key in ipairs(keys) do
					pcall(function()
						dataStore:RemoveAsync(key.KeyName)
					end)
				end
				
				if cursor.IsFinished then break end
				cursor:AdvanceToNextPageAsync()
			end
			--print("[UnifiedDataStoreManager] Cleared all entries from " .. storeName)
		end)
		return success
	end
	
	-- Clear all DataStores completely (including offline players)
	local statsCleared = clearDataStore(statsStore, "PlayerStats")
	local weaponsCleared = clearDataStore(weaponDataStore, "WeaponData")
	local orbsCleared = clearDataStore(orbDataStore, "OrbData")
	local inventoryCleared = clearDataStore(inventoryStore, "PlayerInventory")
	
	local questStore = DataStoreService:GetDataStore("PlayerQuests")
	local questsCleared = clearDataStore(questStore, "PlayerQuests")
	
	-- Also reset all players currently in game (their local data)
	for _, player in ipairs(Players:GetPlayers()) do
		UnifiedDataStoreManager.ResetPlayerData(player.UserId)
		successCount = successCount + 1
	end
	
	local allSuccess = statsCleared and weaponsCleared and orbsCleared and inventoryCleared and questsCleared
	
	if allSuccess then
		--print("[UnifiedDataStoreManager] ⚠️  COMPLETE RESET - All player data (online and offline) has been deleted from all DataStores!")
		--print("[UnifiedDataStoreManager] Players reset: " .. successCount)
	else
		--print("[UnifiedDataStoreManager] ⚠️  PARTIAL RESET - Some DataStore entries may not have been cleared")
		failureCount = 1
	end
	
	return successCount, failureCount
end
-- Server shutdown handler
if game:IsA("DataModel") then
	-- All shutdown saves are handled by PlayerDataStore
end

-- Export initPlayerTracking for Init.server.lua to call
UnifiedDataStoreManager.initPlayerTracking = initPlayerTracking

-- UnifiedDataStoreManager.ResetAllPlayersData()
return UnifiedDataStoreManager
