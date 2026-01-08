-- Init.server.lua
-- Main server initialization script - Consolidated Single Entry Point
-- Requires and initializes all game systems from the Library folder
-- All functionality is organized in Library/[Category]/[Module]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- === SETUP: CREATE REMOTE EVENTS ===

local function createRemoteEvent(name, parent)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = parent
	return event
end

-- Create all RemoteEvents that modules need
createRemoteEvent("InventoryChanged", ReplicatedStorage)
createRemoteEvent("AllocateStatPoint", ReplicatedStorage)
createRemoteEvent("EnemyDamage", ReplicatedStorage)
createRemoteEvent("PlayerRunning", ReplicatedStorage)
createRemoteEvent("ShowDamageText", ReplicatedStorage)

-- === DATA MANAGEMENT SYSTEMS ===

local UnifiedDataStoreManager
local success, err = pcall(function()
	UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
end)
if success then
else
	error("[Init] Failed to load UnifiedDataStoreManager: " .. tostring(err))
end

local PlayerDataStore
success, err = pcall(function()
	PlayerDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("PlayerDataStore"))
end)
if success then
else
	error("[Init] Failed to load PlayerDataStore: " .. tostring(err))
end

local EnemyStatsDataStore
success, err = pcall(function()
	EnemyStatsDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("EnemyStatsDataStore"))
end)
if success then
else
	error("[Init] Failed to load EnemyStatsDataStore: " .. tostring(err))
end

-- === PLAYER SYSTEMS ===

local StatsManager
success, err = pcall(function()
	StatsManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("StatsManager"))
end)
if success then

else
	error("[Init] Failed to load StatsManager: " .. tostring(err))
end

local LevelSystem
success, err = pcall(function()
	LevelSystem = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("LevelSystem"))
end)
if success then
else
	error("[Init] Failed to load LevelSystem: " .. tostring(err))
end

local ManaManager
success, err = pcall(function()
	ManaManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("ManaManager"))
end)
if success then
else
	error("[Init] Failed to load ManaManager: " .. tostring(err))
end


local InventoryManager
success, err = pcall(function()
	InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
end)
if success then

else
	error("[Init] Failed to load InventoryManager: " .. tostring(err))
end

local WeaponManager
success, err = pcall(function()
	WeaponManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("WeaponManager"))
end)
if success then
else
	error("[Init] Failed to load WeaponManager: " .. tostring(err))
end

local ItemDropManager
success, err = pcall(function()
	ItemDropManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ItemDropManager"))
end)
if success then
else
	error("[Init] Failed to load ItemDropManager: " .. tostring(err))
end

local WeaponDataStore
success, err = pcall(function()
	WeaponDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("WeaponDataStore"))
end)
if success then
else
	error("[Init] Failed to load WeaponDataStore: " .. tostring(err))
end

local ItemCollectionHandler
success, err = pcall(function()
	ItemCollectionHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ItemCollectionHandler"))
end)
if success then
else
	error("[Init] Failed to load ItemCollectionHandler: " .. tostring(err))
end

local ItemActionHandler
success, err = pcall(function()
	ItemActionHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ItemActionHandler"))
end)
if success then

else
	error("[Init] Failed to load ItemActionHandler: " .. tostring(err))
end

local PortalTeleportHandler
success, err = pcall(function()
	PortalTeleportHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("PortalHandler"))
end)
if success then
	PortalTeleportHandler.Init()
else
	error("[Init] Failed to load PortalTeleportHandler: " .. tostring(err))
end

-- === COMBAT SYSTEMS ===

local DamageManager
success, err = pcall(function()
	DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
end)
if success then
else
	error("[Init] Failed to load DamageManager: " .. tostring(err))
end

local ManaManagerHandler
success, err = pcall(function()
	ManaManagerHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("ManaManagerHandler"))
end)
if success then
else
	error("[Init] Failed to load ManaManagerHandler: " .. tostring(err))
end

local ProximityPromptListener
success, err = pcall(function()
	ProximityPromptListener = require(ServerScriptService:WaitForChild("Library"):WaitForChild("ProximityPromptListener"))
end)
if success then
else
	error("[Init] Failed to load ProximityPromptListener: " .. tostring(err))
end

local PVPHandler
success, err = pcall(function()
	PVPHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("PVPHandler"))
end)
if success then
else
	error("[Init] Failed to load PVPHandler: " .. tostring(err))
end

local PlayerNameDisplay
success, err = pcall(function()
	PlayerNameDisplay = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("PlayerNameDisplay"))
	PlayerNameDisplay.Initialize()
end)
if success then
	print("[Init] ✓ PlayerNameDisplay initialized")
else
	error("[Init] Failed to load PlayerNameDisplay: " .. tostring(err))
end

-- === ENEMY SYSTEMS ===

-- Load EnemiesModule if it exists
local EnemiesModule = nil
local enemiesPath = ServerScriptService:FindFirstChild("Library")
if enemiesPath then
	enemiesPath = enemiesPath:FindFirstChild("Enemies")
	if enemiesPath then
		local enemiesModuleScript = enemiesPath:FindFirstChild("EnemiesModule")
		if enemiesModuleScript then
			EnemiesModule = require(enemiesModuleScript)
		end
	end
end

-- === PLAYER LIFECYCLE EVENTS ===

-- Handle player join
Players.PlayerAdded:Connect(function(player)
	-- All data loading is handled by PlayerDataStore module via PlayerAdded event
	-- All item loading is handled by InventoryManager module via PlayerAdded event
	-- All mana initialization is handled by ManaManager module via PlayerAdded event
end)

-- Handle players who are already in the game (for fast reloads)
for _, player in ipairs(Players:GetPlayers()) do
	-- Initialize inventory and mana for existing players
	task.spawn(function()
		task.wait(0.5) -- Wait for all modules to be ready
		if InventoryManager and InventoryManager.InitializePlayer then
			InventoryManager.InitializePlayer(player)
		end
		if ManaManager and ManaManager.InitializePlayer then
			ManaManager.InitializePlayer(player)
		end
	end)
end

-- Handle player disconnect
Players.PlayerRemoving:Connect(function(player)
	-- All saves are delegated to UnifiedDataStoreManager via its PlayerRemoving event
	-- All cleanup is handled by individual modules
end)

-- === UTILITY: Setup Collision Groups for Items ===
local PhysicsService = game:GetService("PhysicsService")

-- Register collision groups
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Enemies") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Coins") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Items") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Env") end)
pcall(function() PhysicsService:RegisterCollisionGroup("WeaponHits") end)

-- Enable WeaponHits to collide with Players for PVP damage detection
pcall(function() PhysicsService:CollisionGroupSetCollidable("WeaponHits", "Players", true) end)
-- Disable WeaponHits colliding with other WeaponHits to prevent interference
pcall(function() PhysicsService:CollisionGroupSetCollidable("WeaponHits", "WeaponHits", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("WeaponHits", "Walls", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("WeaponHits", "Env", false) end)

-- Setup collision relationships for Coins (like Enemies)
PhysicsService:CollisionGroupSetCollidable("Coins", "Coins", true)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Enemies", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Enemies", "Enemies", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Players", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Env", true) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "Players", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "DeadEnemies", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "Coins", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "Items", false) end)
-- Verify collision setup
task.wait(0.1)
local success, canCollide = pcall(function()
	return PhysicsService:CollisionGroupsAreCollidable("Coins", "Players")
end)
if not success then
	warn("[GloopCrusher] Could not verify Coins-Players collision relationship")
end

-- === ITEM COLLECTION SETUP ===
if ItemCollectionHandler then
	ItemCollectionHandler.Initialize(UnifiedDataStoreManager, InventoryManager)
end

-- === SERVER READY ===

-- Keep the script running
while true do
	task.wait(1)
end
