-- PlayerDataStore.lua
-- Loads player stats on join and sets up collision groups
-- All saves are now handled by UnifiedDataStoreManager

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local statsStore = DataStoreService:GetDataStore("PlayerStats")

-- Create or get Players collision group
local function setupPlayerCollisionGroup()
	local success, err = pcall(function()
		PhysicsService:RegisterCollisionGroup("Players")
	end)
	if success then
		-- Players collision group created
	else
		-- Players collision group already exists
	end
	-- Disable collision between players
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	end)
end

-- Initialize collision group on script load
setupPlayerCollisionGroup()

-- Create a folder in ReplicatedStorage to store initialization signals
local playerSignalsFolder = ReplicatedStorage:FindFirstChild("PlayerInitSignals")
if not playerSignalsFolder then
	playerSignalsFolder = Instance.new("Folder")
	playerSignalsFolder.Name = "PlayerInitSignals"
	playerSignalsFolder.Parent = ReplicatedStorage
end

-- Track which players have stats ready
local playersStatsReady = {} -- Maps userId -> true

local function getStatsReadySignal(userId)
	local signalName = "Player_" .. userId
	local signal = playerSignalsFolder:FindFirstChild(signalName)
	if not signal then
		signal = Instance.new("BindableEvent")
		signal.Name = signalName
		signal.Parent = playerSignalsFolder
	end
	return signal
end

local DEFAULT_STATS = {
	MaxHealth = 10,
	CurrentHealth = 10,
	MaxMana = 5,
	CurrentMana = 5,
	Attack = 1,
	Defence = 1,
	ArmorDefence = 0,
	Dexterity = 1,
	Money = 0,
	Level = 1,
	Experience = 0,
	NeededExperience = 10,
	StatPoints = 3,
	Equipped = nil, -- Will be set per-player using InventoryManager.CreateStarterWeaponAndEquipped
	EquippedSuit = nil, -- Armor suit slot
	EquippedHelmet = nil, -- Armor helmet slot
	EquippedLegs = nil, -- Armor legs slot
	EquippedShoes = nil, -- Armor shoes slot
	ResetPoints = 1,
	PlayerMap = "Grimleaf Entrance",
	LastSpawnName = "SpawnLocation", -- Track last used spawn part
	InventoryCapacity = 0, -- Current item count (updated dynamically based on actual inventory)
	InventoryMaxCapacity = 10, -- Max items allowed (can be increased by gamepass later)
	HasOrbBuff = false, -- Track if orb buff was active at save
	CriticalDamage = 50, -- Default critical damage percent (50%)
}

local function setupStatsFolder(player, data)
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = player

	for statName, value in pairs(data) do
		local statValue
		if statName == "Equipped" or statName == "EquippedSuit" or statName == "EquippedHelmet" or statName == "EquippedLegs" or statName == "EquippedShoes" then
			statValue = Instance.new("Folder")
			statValue.Name = statName
			statValue.Parent = statsFolder
			if type(value) == "table" then
				local nameValue = Instance.new("StringValue")
				nameValue.Name = "name"
				nameValue.Value = value.name or ""
				nameValue.Parent = statValue
				local idValue = Instance.new("StringValue")
				idValue.Name = "id"
				idValue.Value = value.id or ""
				idValue.Parent = statValue
			else
				local nameValue = Instance.new("StringValue")
				nameValue.Name = "name"
				nameValue.Value = tostring(value)
				nameValue.Parent = statValue
				local idValue = Instance.new("StringValue")
				idValue.Name = "id"
				idValue.Value = ""
				idValue.Parent = statValue
			end
		elseif statName == "EquippedOrb" then
			-- ...existing code...
			statValue = Instance.new("Folder")
			statValue.Name = statName
			statValue.Parent = statsFolder
			if type(value) == "table" then
				local nameValue = Instance.new("StringValue")
				nameValue.Name = "name"
				nameValue.Value = value.name or ""
				nameValue.Parent = statValue
				local idValue = Instance.new("StringValue")
				idValue.Name = "id"
				idValue.Value = value.id or ""
				idValue.Parent = statValue
			else
				local nameValue = Instance.new("StringValue")
				nameValue.Name = "name"
				nameValue.Value = ""
				nameValue.Parent = statValue
				local idValue = Instance.new("StringValue")
				idValue.Name = "id"
				idValue.Value = ""
				idValue.Parent = statValue
			end
		elseif statName == "PlayerMap" or statName == "LastSpawnName" or statName == "SpiritOrb" then
			statValue = Instance.new("StringValue")
			statValue.Name = statName
			statValue.Value = tostring(value)
			statValue.Parent = statsFolder
		elseif statName == "HasOrbBuff" then
			local boolValue = Instance.new("BoolValue")
			boolValue.Name = statName
			boolValue.Value = value and true or false
			boolValue.Parent = statsFolder
		elseif statName == "CriticalDamage" then
			statValue = Instance.new("IntValue")
			statValue.Name = statName
			statValue.Value = value
			statValue.Parent = statsFolder
		else
			statValue = Instance.new("IntValue")
			statValue.Name = statName
			statValue.Value = value
			statValue.Parent = statsFolder
		end
	end
	
	-- Ensure EquippedOrb folder exists (in case it wasn't in the loaded data)
	if not statsFolder:FindFirstChild("EquippedOrb") then
		local equippedOrbFolder = Instance.new("Folder")
		equippedOrbFolder.Name = "EquippedOrb"
		equippedOrbFolder.Parent = statsFolder
		
		local orbNameValue = Instance.new("StringValue")
		orbNameValue.Name = "name"
		orbNameValue.Value = ""
		orbNameValue.Parent = equippedOrbFolder
		
		local orbIdValue = Instance.new("StringValue")
		orbIdValue.Name = "id"
		orbIdValue.Value = ""
		orbIdValue.Parent = equippedOrbFolder
		
		print("[PlayerDataStore] Created EquippedOrb folder for " .. player.Name)
	end
end

local function migrateData(oldData)
    -- Ensure Equipped field exists and is in correct table format
	local equippedWeaponName = ""
	local equippedItemId = ""

	-- Patch: Only weapons go in Equipped, armors go in their slots
	if oldData.Equipped then
		if type(oldData.Equipped) == "table" then
			local equippedItemType = oldData.Equipped.itemType or nil
			if equippedItemType == "weapon" or equippedItemType == nil then
				equippedWeaponName = oldData.Equipped.name or ""
				equippedItemId = oldData.Equipped.id or ""
			elseif equippedItemType == "armor" then
				-- Place in correct armor slot
				local armorName = oldData.Equipped.name or ""
				local armorId = oldData.Equipped.id or ""
				   -- Try to detect armor type from name (Helmet, Suit, Legs, Shoes/Boots)
				   local lowerName = armorName:lower()
				   if lowerName:find("helmet") then
					   oldData.EquippedHelmet = { name = armorName, id = armorId }
				   elseif lowerName:find("suit") then
					   oldData.EquippedSuit = { name = armorName, id = armorId }
				   elseif lowerName:find("legs") then
					   oldData.EquippedLegs = { name = armorName, id = armorId }
				   elseif lowerName:find("shoes") or lowerName:find("boots") then
					   oldData.EquippedShoes = { name = armorName, id = armorId }
				   end
				-- Clear Equipped slot for armor
				equippedWeaponName = ""
				equippedItemId = ""
			end
		elseif type(oldData.Equipped) == "string" and oldData.Equipped ~= "" then
			-- Old string format, assume weapon
			equippedWeaponName = oldData.Equipped
		end
	end

	-- Check for legacy EquippedItemId field and merge it
	if oldData.EquippedItemId and oldData.EquippedItemId ~= "" then
		equippedItemId = oldData.EquippedItemId
	end

	-- Set Equipped to new table format (only weapon)
	oldData.Equipped = {
		name = equippedWeaponName,
		id = equippedItemId
	}

	-- Remove old EquippedItemId field if it exists
	oldData.EquippedItemId = nil

	-- Ensure EquippedOrb exists (for spirit orbs from inventory)
	if not oldData.EquippedOrb then
		oldData.EquippedOrb = {
			name = "",
			id = ""
		}
	elseif type(oldData.EquippedOrb) == "string" then
		oldData.EquippedOrb = {
			name = oldData.EquippedOrb,
			id = ""
		}
	end

	-- Ensure EquippedSuit, EquippedHelmet, EquippedLegs, and EquippedShoes exist and are in correct format
	local function ensureArmorSlot(slotName)
		if not oldData[slotName] or type(oldData[slotName]) ~= "table" then
			oldData[slotName] = { name = "", id = "" }
		else
			if not oldData[slotName].name then oldData[slotName].name = "" end
			if not oldData[slotName].id then oldData[slotName].id = "" end
		end
	end
	ensureArmorSlot("EquippedSuit")
	ensureArmorSlot("EquippedHelmet")
	ensureArmorSlot("EquippedLegs")
	ensureArmorSlot("EquippedShoes")

	-- Merge any missing fields from DEFAULT_STATS
	for statName, defaultValue in pairs(DEFAULT_STATS) do
		if oldData[statName] == nil then
			oldData[statName] = defaultValue
		end
	end
	return oldData
end

Players.PlayerAdded:Connect(function(player)
	print("[PlayerDataStore] ========== PLAYER JOINING: " .. player.Name .. " ==========")
	
	local key = "Player_" .. player.UserId
	local data
	local success, err = pcall(function()
		data = statsStore:GetAsync(key)
	end)
	if not success or not data then
		-- No data exists, create default entry
		print("[PlayerDataStore] No existing data found, creating new player with defaults")
		local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
		local inventory, equipped = InventoryManager.CreateStarterWeaponAndEquipped()
		-- Set both Twig and Normal Orb as equipped for new players
		local starterEquipped = {}
		if equipped and type(equipped) == "table" then
			-- If equipped is a table of items, add each as equipped
			for _, item in ipairs(equipped) do
				table.insert(starterEquipped, { name = item.name, id = item.id })
			end
		else
			-- Fallback: single equipped item
			starterEquipped = { name = inventory[1].name, id = inventory[1].id }
		end
		local newStats = table.clone(DEFAULT_STATS)
		newStats.Equipped = starterEquipped
		local createSuccess, createErr = pcall(function()
			statsStore:SetAsync(key, newStats)
		end)
		if not createSuccess then
			warn("[PlayerDataStore] Failed to create data for player " .. player.Name .. " (" .. player.UserId .. "): " .. tostring(createErr))
		end
		data = newStats
		-- Also immediately save starter inventory for this player
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		UnifiedDataStoreManager.SaveInventory(player.UserId, inventory, true)
	else
		-- Data loaded from DataStore
		print("[PlayerDataStore] Loaded player data from DataStore:")
		print("  ├─ Attack: " .. (data.Attack or "nil"))
		print("  ├─ Defence: " .. (data.Defence or "nil"))
		print("  ├─ MaxHealth: " .. (data.MaxHealth or "nil"))
		print("  ├─ MaxMana: " .. (data.MaxMana or "nil"))
		print("  └─ Dexterity: " .. (data.Dexterity or "nil"))
		
		-- If CurrentHealth is nil or <= 0, reset to MaxHealth
		if data["CurrentHealth"] == nil or data["CurrentHealth"] <= 0 then
			data["CurrentHealth"] = data["MaxHealth"] or DEFAULT_STATS.MaxHealth
		end
		-- If CurrentMana is nil, reset to MaxMana
		if data["CurrentMana"] == nil then
			data["CurrentMana"] = data["MaxMana"] or DEFAULT_STATS.MaxMana
		end
		-- Migrate data to ensure all fields are present
		data = migrateData(data)
	end
	-- Remove any existing Stats folder to ensure reset
	local oldStats = player:FindFirstChild("Stats")
	if oldStats then
		oldStats:Destroy()
	end
	-- Setup stats folder with loaded data
	setupStatsFolder(player, data)
	-- Log EquippedOrb value after setup
	local stats = player:FindFirstChild("Stats")
	if stats then
		local equippedOrb = stats:FindFirstChild("EquippedOrb")
		if equippedOrb and equippedOrb:IsA("Folder") then
			local orbName = equippedOrb:FindFirstChild("name")
			local orbId = equippedOrb:FindFirstChild("id")
			local actualName = orbName and orbName.Value or "nil"
			local actualId = orbId and orbId.Value or "nil"
			print("[PlayerDataStore] On join: EquippedOrb actual value: name='" .. actualName .. "', id='" .. actualId .. "'")
		end
	end

	print("[PlayerDataStore] ✓ Base stats restored and captured for " .. player.Name)
    
	-- Signal that Stats folder is ready for this player
	local signal = getStatsReadySignal(player.UserId)
	playersStatsReady[player.UserId] = true
	-- Mark the signal as fired so late listeners know
	local fired = signal:FindFirstChild("_Fired")
	if not fired then
		fired = Instance.new("BoolValue")
		fired.Name = "_Fired"
		fired.Parent = signal
	end
	fired.Value = true
	signal:Fire(player)
    
	-- Add player character to collision group to prevent player-to-player collision
	if player.Character then
		task.spawn(function()
			task.wait(0.5) -- Wait for character parts to fully load
			local success, err = pcall(function()
				-- Add all parts of the character to the Players collision group
				for _, part in ipairs(player.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CollisionGroup = "Players"
					end
				end
			end)
			if success then
				-- Added to Players collision group
			else
				warn("[PlayerDataStore] Failed to add " .. player.Name .. " to collision group: " .. tostring(err))
			end
			
			-- Monitor for new parts added (like accessories) and add them to Players collision group
			player.Character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					pcall(function()
						descendant.CollisionGroup = "Players"
					end)
				end
			end)
		end)
	end
    
	-- Setup CharacterAdded to add future characters to collision group and reset health/mana

	local function handleCharacterSpawn(character)
		task.spawn(function()
			-- Mark player as initializing on respawn
			local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
			DamageManager.MarkPlayerInitializing(player)
			
			task.wait(0.1) -- Short wait for character to spawn

			-- Find spawn location based on PlayerMap and LastSpawnName stat
			local stats = player:FindFirstChild("Stats")
			local mapName, spawnName
			if stats then
				local playerMapValue = stats:FindFirstChild("PlayerMap")
				if playerMapValue and playerMapValue.Value ~= "" then
					mapName = playerMapValue.Value
				end
				local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
				if lastSpawnValue and lastSpawnValue.Value ~= "" then
					spawnName = lastSpawnValue.Value
				end
			end
			-- Fallbacks only if both are missing
			if not mapName then mapName = "Grimleaf Entrance" end
			if not spawnName then spawnName = "SpawnLocation" end
			print("[PlayerDataStore] Respawn: PlayerMap=", mapName, ", LastSpawnName=", spawnName)
			local mapFolder = workspace:FindFirstChild("Maps")
			local spawnLocation = nil
			if mapFolder then
				local map = mapFolder:FindFirstChild(mapName)
				if map then
					spawnLocation = map:FindFirstChild(spawnName)
				end
			end
			if player:GetAttribute("IsPortalTeleporting") then
				print("[PlayerDataStore] Skipping respawn teleport due to portal teleport.")
				return
			end
			if spawnLocation and spawnLocation:IsA("BasePart") then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					print("[PlayerDataStore] Actually respawning to part:", spawnLocation.Name, "in map:", mapName, "at position", tostring(spawnLocation.Position))
					-- If respawning at default SpawnLocation, reset portal state to allow portal use
					if spawnLocation.Name == "SpawnLocation" then
						local PortalHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("PortalHandler"))
						PortalHandler.ResetPlayerPortalState(player.UserId)
						-- Do NOT reset LastSpawnName here; keep it as the last portal used
					end
					-- Position at spawn location, slightly above the part
					local spawnPos = spawnLocation.Position
					humanoidRootPart.CFrame = CFrame.new(spawnPos.X, spawnPos.Y, spawnPos.Z + 5)
				end
			end

			task.wait(0.5) -- Wait for character parts to fully load

			-- Reset CurrentHealth and CurrentMana to full when respawning
			local stats = player:FindFirstChild("Stats")
			if stats then
				local maxHealth = stats:FindFirstChild("MaxHealth")
				local currentHealth = stats:FindFirstChild("CurrentHealth")
				local maxMana = stats:FindFirstChild("MaxMana")
				local currentMana = stats:FindFirstChild("CurrentMana")

				if maxHealth and currentHealth then
					currentHealth.Value = maxHealth.Value
				end
				if maxMana and currentMana then
					currentMana.Value = maxMana.Value
				end

				-- Save the reset health/mana to DataStore
			UnifiedDataStoreManager.SaveStats(player, false)
			end

			-- Add all parts of the character to the Players collision group
			local success, err = pcall(function()
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CollisionGroup = "Players"
					end
				end
			end)
			if success then
				-- Added respawn character to collision group
			else
				warn("[PlayerDataStore] Failed to add respawn character to collision group: " .. tostring(err))
			end
			
			-- Monitor for new parts added (like accessories) and add them to Players collision group
			character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					pcall(function()
						descendant.CollisionGroup = "Players"
					end)
				end
			end)

			-- Mark player as loaded after setup
			DamageManager.MarkPlayerLoaded(player)
		end)
	end

	-- Handle initial character if it exists (NEW PLAYERS ON FIRST JOIN)
	if player.Character then
		print("[PlayerDataStore] Initial character exists for", player.Name, "- teleporting to spawn location")
		handleCharacterSpawn(player.Character)
	end

	-- Handle future respawns
	player.CharacterAdded:Connect(handleCharacterSpawn)
end)

Players.PlayerRemoving:Connect(function(player)
	-- ...existing code...
end)


-- Save all players on server shutdown and wait to ensure saves complete
if game:IsA("DataModel") then
	game:BindToClose(function()
		print("[PlayerDataStore] BindToClose: Saving all player stats before shutdown...")
		for _, player in ipairs(Players:GetPlayers()) do
			UnifiedDataStoreManager.SaveStats(player, true)
		end
		-- Wait up to 25 seconds for all saves to complete
		print("[PlayerDataStore] BindToClose: Waiting for saves to finish...")
		task.wait(5)
		print("[PlayerDataStore] BindToClose: Shutdown complete.")
	end)
end

return PlayerDataStore
