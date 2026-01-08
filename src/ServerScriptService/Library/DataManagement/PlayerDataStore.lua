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
	ResetPoints = 1,
	PlayerMap = "Grimleaf Entrance",
	LastSpawnName = "SpawnLocation", -- Track last used spawn part
	InventoryCapacity = 0, -- Current item count (updated dynamically based on actual inventory)
	InventoryMaxCapacity = 10 -- Max items allowed (can be increased by gamepass later)
}

local function setupStatsFolder(player, data)
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = player

	-- If equipped is blank, try to set it to the first item in inventory (if available)
	if data.Equipped and (data.Equipped.name == "" or data.Equipped.id == "") then
		-- Try to get inventory from InventoryManager
		local success, InventoryManager = pcall(function()
			return require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
		end)
		if success and InventoryManager then
			local inventory = InventoryManager.GetInventory(player)
			if inventory and #inventory > 0 then
				data.Equipped = { name = inventory[1].name, id = inventory[1].id }
			end
		end
	end

	for statName, value in pairs(data) do
		local statValue
		if statName == "Equipped" then
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
		elseif statName == "PlayerMap" or statName == "LastSpawnName" then
			statValue = Instance.new("StringValue")
			statValue.Name = statName
			statValue.Value = tostring(value)
			statValue.Parent = statsFolder
		else
			statValue = Instance.new("IntValue")
			statValue.Name = statName
			statValue.Value = value
			statValue.Parent = statsFolder
		end
	end
end

local function migrateData(oldData)
    -- Ensure Equipped field exists and is in correct table format
    local equippedWeaponName = ""
    local equippedItemId = ""
    
    -- Check if old Equipped field exists
    if oldData.Equipped then
        if type(oldData.Equipped) == "table" then
            -- Already in new format
            equippedWeaponName = oldData.Equipped.name or ""
            equippedItemId = oldData.Equipped.id or ""
        elseif type(oldData.Equipped) == "string" and oldData.Equipped ~= "" then
            -- Old string format
            equippedWeaponName = oldData.Equipped
        end
    end
    
    -- Check for legacy EquippedItemId field and merge it
    if oldData.EquippedItemId and oldData.EquippedItemId ~= "" then
        equippedItemId = oldData.EquippedItemId
    end
    
    -- Set Equipped to new table format
    oldData.Equipped = {
        name = equippedWeaponName,
        id = equippedItemId
    }
    
    -- Remove old EquippedItemId field if it exists
    oldData.EquippedItemId = nil
    
    -- Merge any missing fields from DEFAULT_STATS
    for statName, defaultValue in pairs(DEFAULT_STATS) do
        if oldData[statName] == nil then
            oldData[statName] = defaultValue
        end
    end
    return oldData
end

Players.PlayerAdded:Connect(function(player)
	local key = "Player_" .. player.UserId
	local data
	local success, err = pcall(function()
		data = statsStore:GetAsync(key)
	end)
	if not success or not data then
		-- No data exists, create default entry
		local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
		local inventory, equipped = InventoryManager.CreateStarterWeaponAndEquipped()
		-- Instead of generating a new equipped id, use the id of the starter item in inventory
		local starterEquipped = { name = inventory[1].name, id = inventory[1].id }
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
				UnifiedDataStoreManager.SaveStats(player, true)
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
	-- Mark player as disconnected so their character can't receive damage
	local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
	DamageManager.MarkPlayerDisconnected(player)
	
	UnifiedDataStoreManager.SaveStats(player, true)
end)

-- Optionally, save all players on server shutdown
if game:IsA("DataModel") then
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			UnifiedDataStoreManager.SaveStats(player, true)
		end
	end)
end

return PlayerDataStore
