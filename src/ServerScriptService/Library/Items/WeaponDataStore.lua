-- WeaponDataStore.lua
-- Weapon data management

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

local WeaponDataStore = {}

function WeaponDataStore.saveWeaponData(userId, weaponData)
	return UnifiedDataStoreManager.SaveWeaponData(userId, weaponData, false)
end

function WeaponDataStore.loadWeaponData(userId)
	return UnifiedDataStoreManager.LoadWeaponData(userId)
end

function WeaponDataStore.deleteWeaponData(userId)
	return UnifiedDataStoreManager.DeleteWeaponData(userId)
end

return WeaponDataStore
