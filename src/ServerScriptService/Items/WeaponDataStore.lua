local DataStoreService = game:GetService("DataStoreService")
local weaponDataStore = DataStoreService:GetDataStore("WeaponData")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)

local WeaponDataStore = {}

-- Save weapon data for a player
function WeaponDataStore.SaveWeaponData(userId, weaponData)
	local key = "Player_" .. userId
	local success, err = pcall(function()
		weaponDataStore:SetAsync(key, weaponData)
	end)
	if not success then
		warn("[WeaponDataStore] Failed to save weapon data for user " .. userId .. ": " .. tostring(err))
	end
	return success
end

-- Load weapon data for a player
function WeaponDataStore.LoadWeaponData(userId)
	local key = "Player_" .. userId
	local data
	local success, err = pcall(function()
		data = weaponDataStore:GetAsync(key)
	end)
	if not success then
		warn("[WeaponDataStore] Failed to load weapon data for user " .. userId .. ": " .. tostring(err))
		return nil
	end
	return data
end

-- Update weapon data using UpdateAsync for safe concurrent modifications
function WeaponDataStore.UpdateWeaponData(userId, updateFunction)
	local key = "Player_" .. userId
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
	local key = "Player_" .. userId
	local success, err = pcall(function()
		weaponDataStore:RemoveAsync(key)
	end)
	if not success then
		warn("[WeaponDataStore] Failed to delete weapon data for user " .. userId .. ": " .. tostring(err))
	end
	return success
end

return WeaponDataStore
