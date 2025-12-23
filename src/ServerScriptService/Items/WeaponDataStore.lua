local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))

local WeaponDataStore = {}

-- Throttle settings for weapon data saves
local SAVE_THROTTLE_INTERVAL = 8 -- Save at most every 8 seconds
local lastSaveTime = {}
local pendingWeaponSaves = {}

-- Save weapon data for a player (throttled)
function WeaponDataStore.SaveWeaponData(userId, weaponData, forceImmediate)
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveWeaponData(userId, weaponData, forceImmediate)
end

-- Load weapon data for a player
function WeaponDataStore.LoadWeaponData(userId)
	-- Delegate to UnifiedDataStoreManager
	return UnifiedDataStoreManager.LoadWeaponData(userId)
end

-- Update weapon data using UpdateAsync for safe concurrent modifications
function WeaponDataStore.UpdateWeaponData(userId, updateFunction)
	local key = "Player_" .. userId
	local weaponDataStore = DataStoreService:GetDataStore("WeaponData")
	local newData
	local success, err = pcall(function()
		newData = weaponDataStore:UpdateAsync(key, function(oldData)
			return updateFunction(oldData)
		end)
	end)
	if not success then
		warn("[WeaponDataStore] Failed to update weapon data for user " .. userId .. ": " .. tostring(err))
		return nil
	end
	return newData
end

-- Delete weapon data for a player
function WeaponDataStore.DeleteWeaponData(userId)
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.DeleteWeaponData(userId)
end

-- Cleanup on player disconnect
Players.PlayerRemoving:Connect(function(player)
	-- Force save delegated to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveAll(player, true)
end)

return WeaponDataStore
