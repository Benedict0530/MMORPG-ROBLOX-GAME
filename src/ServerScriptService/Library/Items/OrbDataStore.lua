-- OrbDataStore.lua
-- Spirit Orb data management with unique IDs

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

local OrbDataStore = {}

function OrbDataStore.saveOrbData(userId, orbData)
	return UnifiedDataStoreManager.SaveOrbData(userId, orbData, false)
end

function OrbDataStore.loadOrbData(userId)
	return UnifiedDataStoreManager.LoadOrbData(userId)
end

function OrbDataStore.deleteOrbData(userId)
	return UnifiedDataStoreManager.DeleteOrbData(userId)
end

return OrbDataStore
