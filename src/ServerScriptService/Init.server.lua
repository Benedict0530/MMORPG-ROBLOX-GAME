-- Init.server.lua
-- Main server initialization script - Consolidated Single Entry Point
-- Requires and initializes all game systems from the Library folder
-- All functionality is organized in Library/[Category]/[Module]
--
-- ⚠️ IMPORTANT FOR STUDIO TESTING:
-- DataStore is DISABLED by default in Roblox Studio.
-- To enable player data saving in Studio:
--   1. Click "Home" tab → "Game Settings" button
--   2. Navigate to "Security" section
--   3. Enable "Enable Studio Access to API Services"
--   4. Click "Save" and restart the game
-- Without this, all player data will be lost between sessions!
--

print("[Init] 🚀 Init.server.lua starting...")

-- === SERVER READY WAIT ===
-- Wait for all critical services and assets to be available before initializing modules
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local function waitForDescendant(parent, name, timeout)
	local t0 = tick()
	while true do
		local found = parent:FindFirstChild(name)
		if found then return found end
		if timeout and (tick() - t0) > timeout then return nil end
		task.wait(0.05)
	end
end


waitForDescendant(ReplicatedStorage, "Modules", 10)
waitForDescendant(ServerScriptService, "Library", 10)
waitForDescendant(ServerStorage, "Armor Accessories", 10)
waitForDescendant(ServerStorage, "Orbs", 10)

--print("[Init] All critical services and assets loaded. Proceeding with module initialization...")

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
createRemoteEvent("EquippedChanged", ReplicatedStorage)
createRemoteEvent("ItemActionEvent", ReplicatedStorage)
createRemoteEvent("AllocateStatPoint", ReplicatedStorage)
createRemoteEvent("EnemyDamage", ReplicatedStorage)
createRemoteEvent("PlayerRunning", ReplicatedStorage)
createRemoteEvent("ShowDamageText", ReplicatedStorage)
createRemoteEvent("ParalysisEvent", ReplicatedStorage)
createRemoteEvent("KnockbackEvent", ReplicatedStorage)
createRemoteEvent("ResumeAnimationEvent", ReplicatedStorage)
createRemoteEvent("PlayDashSound", ReplicatedStorage)
createRemoteEvent("PerformDash", ReplicatedStorage)

-- Dungeon system RemoteEvents
createRemoteEvent("DungeonEntryEvent", ReplicatedStorage)
createRemoteEvent("DungeonTimerEvent", ReplicatedStorage)
createRemoteEvent("DungeonLeaveEvent", ReplicatedStorage)
createRemoteEvent("DungeonUIEvent", ReplicatedStorage)

--print("[Init] All RemoteEvents created")

-- === DASH HANDLER ===
local PerformDashEvent = ReplicatedStorage:FindFirstChild("PerformDash")
if PerformDashEvent then
	PerformDashEvent.OnServerEvent:Connect(function(player, position)
		-- Try to consume 2 mana (will be implemented after ManaManager loads)
		task.defer(function()
			-- Get ManaManager after it's loaded
			local ManaManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("ManaManager"))
			local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundModule"))
			
			-- Check and consume mana
			if ManaManager.ConsumeMana(player, 2) then
				-- Store original transparency and VFX states
				local originalTransparency = {}
				local originalVFXStates = {}
				local character = player.Character
				local humanoid = character and character:FindFirstChild("Humanoid")
				
				if character then
					-- Store and disable transparency + all VFX
					for _, instance in ipairs(character:GetDescendants()) do
						if instance:IsA("BasePart") then
							originalTransparency[instance] = instance.Transparency
							instance.Transparency = 1
						end
					end
					--print("[Init] " .. player.Name .. " dashing - made transparent, all VFX disabled")
					
					-- Play dash sound in range around the player
					SoundModule.playSoundInRange("Dash Sound Effect", position, "SFX", 50, false, 1)
					--print("[Init] Dash performed by " .. player.Name .. " - 2 mana consumed, sound played")
					
					-- Wait for dash duration (0.3 seconds) and restore visuals
					task.wait(0.3)
					
					-- Restore transparency to original values
					for part, transparency in pairs(originalTransparency) do
						if part and part.Parent then
							part.Transparency = transparency
						end
					end
					
					
					--print("[Init] " .. player.Name .. " dash ended - restored transparency and VFX")
				end
			else
				--print("[Init] Dash failed - insufficient mana for " .. player.Name)
			end
		end)
	end)
end

-- === DASH SOUND HANDLER (Legacy - can be removed) ===
local PlayDashSoundEvent = ReplicatedStorage:FindFirstChild("PlayDashSound")
if PlayDashSoundEvent then
	local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundModule"))
	PlayDashSoundEvent.OnServerEvent:Connect(function(player, position)
		-- Play dash sound in range around the player
		SoundModule.playSoundInRange("Dash Sound Effect", position, "SFX", 50, false, 1)
		--print("[Init] Dash sound played at position: " .. tostring(position))
	end)
end

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

local OrbSpiritHandler
success, err = pcall(function()
	OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
end)
if success then
	--print("[Init] ✓ OrbSpiritHandler loaded")
else
	error("[Init] Failed to load OrbSpiritHandler: " .. tostring(err))
end


local StatsManager
success, err = pcall(function()
	StatsManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("StatsManager"))
end)
if success then

else
	error("[Init] Failed to load StatsManager: " .. tostring(err))
end

-- Ensure ArmorsManager is loaded so PlayerAdded logic runs
local ArmorsManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ArmorsManager"))

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

local SecondaryWeaponHandler
success, err = pcall(function()
	SecondaryWeaponHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("SecondaryWeaponHandler"))
end)
if success then
	SecondaryWeaponHandler:Initialize()
	--print("[Init] ✓ SecondaryWeaponHandler initialized")
else
	error("[Init] Failed to load SecondaryWeaponHandler: " .. tostring(err))
end

local HealingCapsuleHandler
success, err = pcall(function()
	HealingCapsuleHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Environment"):WaitForChild("HealingCapsuleHandler"))
end)
if success then

else
	error("[Init] Failed to load HealingCapsuleHandler: " .. tostring(err))
end

local SafeZoneHandler
success, err = pcall(function()
	SafeZoneHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Environment"):WaitForChild("SafeZoneHandler"))
end)
if success then
	SafeZoneHandler.Initialize()
	print("[Init] ✓ SafeZoneHandler initialized")
else
	error("[Init] Failed to load SafeZoneHandler: " .. tostring(err))
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

local NPCManager
success, err = pcall(function()
	NPCManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("NPC"):WaitForChild("NPCManager"))
end)
if success then
	--print("[Init] ✅ NPCManager loaded")
else
	warn("[Init] ⚠️ Failed to load NPCManager: " .. tostring(err))
end

local NpcQuestHandler
success, err = pcall(function()
	NpcQuestHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("NPC"):WaitForChild("NpcQuestHandler"))
end)
if success then
	--print("[Init] ✅ NpcQuestHandler loaded")
else
	warn("[Init] ⚠️ Failed to load NpcQuestHandler: " .. tostring(err))
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
	ProximityPromptListener = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Interaction"):WaitForChild("ProximityPromptListener"))
end)
if success then
else
	error("[Init] Failed to load ProximityPromptListener: " .. tostring(err))
end

local PVPHandler
success, err = pcall(function()
	PVPHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("PVPHandler"))
end)
if success then
else
	error("[Init] Failed to load PVPHandler: " .. tostring(err))
end

local PlayerInteractionManager
success, err = pcall(function()
	PlayerInteractionManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Interaction"):WaitForChild("PlayerInteractionManager"))
	PlayerInteractionManager.Initialize()
end)
if success then
	--print("[Init] ✓ PlayerInteractionManager initialized")
else
	error("[Init] Failed to load PlayerInteractionManager: " .. tostring(err))
end

local DuelHandler
success, err = pcall(function()
	DuelHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("DuelHandler"))
	DuelHandler.Initialize()
end)
if success then
	--print("[Init] ✓ DuelHandler initialized")
else
	error("[Init] Failed to load DuelHandler: " .. tostring(err))
end

local PlayerNameDisplay
success, err = pcall(function()
	PlayerNameDisplay = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("PlayerNameDisplay"))
	PlayerNameDisplay.Initialize()
end)
if success then
	--print("[Init] ✓ PlayerNameDisplay initialized")
else
	error("[Init] Failed to load PlayerNameDisplay: " .. tostring(err))
end

-- === ULTIMATE SYSTEM ===

local UltimateHandler
success, err = pcall(function()
	UltimateHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("UltimateHandler"))
end)
if success then
	UltimateHandler.Init()
	--print("[Init] ✓ UltimateHandler initialized")
else
	error("[Init] Failed to load UltimateHandler: " .. tostring(err))
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

print("[Init] 🔧 Setting up PlayerAdded connection...")

-- Handle player join (SINGLE UNIFIED HANDLER - ALL PLAYER INITIALIZATION HERE)
Players.PlayerAdded:Connect(function(player)
	print("[Init] 🎮 Player joined:", player.Name, "UserId:", player.UserId)
	
	local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
	local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
	print("[Init] 📦 About to require QuestDataStore...")
	local QuestDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("QuestDataStore"))
	print("[Init] ✅ QuestDataStore required successfully")
	local PortalHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("PortalHandler"))
	local ArmorsManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ArmorsManager"))
	local EnemiesModule = ServerScriptService.Library.Enemies:FindFirstChild("EnemiesModule")
	
	-- 1. Initialize UnifiedDataStoreManager tracking
	UnifiedDataStoreManager.initPlayerTracking(player.UserId)
	
	-- 2. Initialize player data FIRST (critical for all other systems)
	-- PlayerDataStore.PlayerAdded is already connected, it creates Stats folder
	
	-- 3. Wait for Stats folder to be created by PlayerDataStore
	local stats = player:WaitForChild("Stats", 10)
	if not stats then
		warn("[Init] Stats folder not created for", player.Name)
		return
	end
	
	-- 4. Load Quest Data
	task.spawn(function()
		task.wait(0.2)
		print("[Init] 🔄 About to load quest data for", player.Name)
		local loadSuccess, loadErr = pcall(function()
			QuestDataStore.LoadQuestData(player)
		end)
		if loadSuccess then
			print("[Init] ✓ Quests loaded for", player.Name)
		else
			warn("[Init] ❌ Failed to load quests for", player.Name, ":", loadErr)
		end
	end)
	
	-- 5. Initialize Inventory and Mana
	task.spawn(function()
		if InventoryManager and InventoryManager.InitializePlayer then
			InventoryManager.InitializePlayer(player)
			--print("[Init] ✓ Inventory initialized for", player.Name)
		end
		if ManaManager and ManaManager.InitializePlayer then
			ManaManager.InitializePlayer(player)
			--print("[Init] ✓ Mana initialized for", player.Name)
		end
	end)
	
	-- 6. Setup Portal Handler for this player
	PortalHandler.SetupPlayer(player)
	--print("[Init] ✓ Portal handler setup for", player.Name)
	
	-- 7. Setup Armor Manager connections
	ArmorsManager.setupPlayerConnections(player)
	--print("[Init] ✓ Armor manager setup for", player.Name)
	
	-- 8. Add player to enemy targeting group
	if EnemiesModule then
		local EnemiesManager = require(EnemiesModule)
		EnemiesManager.addPlayerToGroup(player)
		--print("[Init] ✓ Added to enemy targeting for", player.Name)
	end
	
	-- 9. Setup Player Name Display
	if PlayerNameDisplay and PlayerNameDisplay.SetupPlayer then
		PlayerNameDisplay.SetupPlayer(player)
		--print("[Init] ✓ Name display setup for", player.Name)
	end

	-- 10. Ensure respawn listener is set up for orb VFX/slash auto-equip
	OrbSpiritHandler.SetupPlayerRespawnListener(player)

	-- Auto-equip orb on join, ONLY if no orb is already equipped
	local function autoEquipOrbIfNeeded()
		-- Check if player already has an equipped orb in Stats.EquippedOrb
		local stats = player:FindFirstChild("Stats")
		if stats then
			local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
			if equippedOrbFolder and equippedOrbFolder:IsA("Folder") then
				local nameValue = equippedOrbFolder:FindFirstChild("name")
				local idValue = equippedOrbFolder:FindFirstChild("id")
				if nameValue and nameValue.Value ~= "" and idValue and idValue.Value ~= "" then
					-- Player already has an orb equipped, just apply visuals
					--print("[Init] Player " .. player.Name .. " already has equipped orb: " .. nameValue.Value .. ", applying visuals only")
					OrbSpiritHandler.EquipOrbFromInventory(player)
					return
				end
			end
		end
		
		-- No equipped orb found, check if starter inventory
		local inventory = InventoryManager.GetInventoryWithEquippedStatus(player)
		local isStarter = false
		if #inventory == 2 then
			local hasTwig, hasNormalOrb = false, false
			for _, item in ipairs(inventory) do
				if item.name == "Twig" and item.itemType == "weapon" then
					hasTwig = true
				elseif item.name == "Normal Orb" and item.itemType == "spirit orb" then
					hasNormalOrb = true
				end
			end
			if hasTwig and hasNormalOrb then
				isStarter = true
			end
		end
		
		-- Only auto-equip first orb if not starter inventory
		if not isStarter then
			for _, item in ipairs(inventory) do
				if item.itemType == "spirit orb" then
					InventoryManager.setEquippedOrb(player, item.name, item.id)
					--print("[Init] Auto-equipped first orb for " .. player.Name .. ": " .. item.name)
					break
				end
			end
		end
	end
	player.CharacterAdded:Connect(function(character)
		-- Wait for Humanoid to exist
		local tries = 0
		local humanoid = character:FindFirstChild("Humanoid")
		while not humanoid and tries < 30 do
			task.wait(0.1)
			humanoid = character:FindFirstChild("Humanoid")
			tries = tries + 1
		end
		-- Auto-equip orb only if needed (respects already equipped orb)
		autoEquipOrbIfNeeded()
	end)
	if player.Character then
		local character = player.Character
		local tries = 0
		local humanoid = character:FindFirstChild("Humanoid")
		while not humanoid and tries < 30 do
			task.wait(0.1)
			humanoid = character:FindFirstChild("Humanoid")
			tries = tries + 1
		end
		autoEquipOrbIfNeeded()
	end
	
	-- Fire ServerReady to this specific player after brief delay
	task.spawn(function()
		task.wait(0.5)
		local serverReadyEvent = ReplicatedStorage:FindFirstChild("ServerReady")
		if serverReadyEvent then
			serverReadyEvent:FireClient(player)
			--print("[Init] ✓ Fired ServerReady to", player.Name)
		end
	end)
end)

print("[Init] ✅ PlayerAdded connection established. Waiting for players to join...")

-- Handle players who are already in the game (for fast reloads)
for _, player in ipairs(Players:GetPlayers()) do
	local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
	OrbSpiritHandler.SetupPlayerRespawnListener(player)
	
	-- Load quest data for existing players
	local QuestDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("QuestDataStore"))
	task.spawn(function()
		task.wait(0.2)
		print("[Init] 🔄 Loading quest data for early-joined player:", player.Name)
		local loadSuccess, loadErr = pcall(function()
			QuestDataStore.LoadQuestData(player)
		end)
		if loadSuccess then
			print("[Init] ✅ Quests loaded for early-joined player:", player.Name)
		else
			warn("[Init] ❌ Failed to load quests for early-joined player:", player.Name, ":", loadErr)
		end
	end)
	
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
	-- All saves are handled by PlayerDataStore. Only cleanup is handled here if needed.
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
pcall(function() PhysicsService:CollisionGroupSetCollidable("Players", "Enemies", false) end)
-- Verify collision setup
task.wait(0.1)
local success, canCollide = pcall(function()
	return PhysicsService:CollisionGroupsAreCollidable("Coins", "Players")
end)
if not success then
	warn("[GloopCrusher] Could not verify Coins-Players collision relationship")
end

-- === ADMIN COMMANDS SYSTEM ===

local AdminCommandsHandler
success, err = pcall(function()
	AdminCommandsHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Admin"):WaitForChild("AdminCommandsHandler"))
end)
if success then
	--print("[Init] ✅ AdminCommandsHandler loaded")
else
	warn("[Init] ⚠️ Failed to load AdminCommandsHandler: " .. tostring(err))
end

-- === ITEM COLLECTION SETUP ===
if ItemCollectionHandler then
	ItemCollectionHandler.Initialize(UnifiedDataStoreManager, InventoryManager)
end

-- === SERVER READY ===

--print("[Init] 🎮 SERVER READY - All systems initialized")

-- Fire ServerReady RemoteEvent to all clients
local serverReadyEvent = ReplicatedStorage:FindFirstChild("ServerReady")
if not serverReadyEvent then
	serverReadyEvent = Instance.new("RemoteEvent")
	serverReadyEvent.Name = "ServerReady"
	serverReadyEvent.Parent = ReplicatedStorage
end

-- Fire to all currently connected players
serverReadyEvent:FireAllClients()
print("[Init] 🎮 SERVER FULLY INITIALIZED - All systems ready!")

-- NOTE: PlayerAdded handler above handles ServerReady for new players

-- Keep the script running
while true do
	task.wait(1)
end
