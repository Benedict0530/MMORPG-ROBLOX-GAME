-- PlayerDataStore.server.lua
-- Loads player stats on join and sets up collision groups
-- All saves are now handled by UnifiedDataStoreManager

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))
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

local function waitForStatsReady(userId)
	-- If already ready, return immediately
	if playersStatsReady[userId] then
		return
	end
	
	-- Otherwise wait for the signal
	local signalName = "Player_" .. userId
	local signal = playerSignalsFolder:FindFirstChild(signalName)
	if not signal then
		signal = Instance.new("BindableEvent")
		signal.Name = signalName
		signal.Parent = playerSignalsFolder
	end
	
	-- Wait for signal to fire
	signal.Event:Wait()
end

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
	MaxHealth = 50,
	CurrentHealth = 50,
	MaxMana = 5,
	CurrentMana = 5,
	Attack = 1,
	Defence = 1,
	Dexterity = 1,
	Money = 0,
	Level = 1,
	Experience = 0,
	NeededExperience = 10,
	StatPoints = 3,
	Equipped = { name = "", id = "" },
	ResetPoints = 1
}

local function loadStats(player)
	local key = "Player_" .. player.UserId
	local data
	local success, err = pcall(function()
		data = statsStore:GetAsync(key)
	end)
	if success and data then
		return data
	else
		return table.clone(DEFAULT_STATS)
	end
end

-- Throttle settings for DataStore saves
local SAVE_THROTTLE_INTERVAL = 8 -- Save every 8 seconds max
local lastSaveTime = {}
local pendingStatChanges = {}

local function saveStats(player, forceImmediate)
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveStats(player, forceImmediate)
end

-- Export throttled save function so other scripts can use it
local PlayerDataStoreModule = {}
function PlayerDataStoreModule.throttledSave(player)
	saveStats(player, false)
end
function PlayerDataStoreModule.forceSave(player)
	saveStats(player, true)
end

local function setupStatsFolder(player, data)
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = player
	for statName, value in pairs(data) do
		local statValue
		-- Create folder for Equipped with name/id children, IntValue for everything else
		if statName == "Equipped" then
			statValue = Instance.new("Folder")
			statValue.Name = statName
			statValue.Parent = statsFolder
			
			-- Create name and id children
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
				-- Fallback for old string format
				local nameValue = Instance.new("StringValue")
				nameValue.Name = "name"
				nameValue.Value = tostring(value)
				nameValue.Parent = statValue
				
				local idValue = Instance.new("StringValue")
				idValue.Name = "id"
				idValue.Value = ""
				idValue.Parent = statValue
			end
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
		local createSuccess, createErr = pcall(function()
			statsStore:SetAsync(key, table.clone(DEFAULT_STATS))
		end)
		if not createSuccess then
			warn("[PlayerDataStore] Failed to create data for player " .. player.Name .. " (" .. player.UserId .. "): " .. tostring(createErr))
		end
		data = table.clone(DEFAULT_STATS)
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
		end)
	end
	
	-- Setup CharacterAdded to add future characters to collision group and reset health/mana
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
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
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveStats(player, true) -- Force immediate save on disconnect
end)

-- Optionally, save all players on server shutdown
if game:IsA("DataModel") then
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			saveStats(player, true)
		end
	end)
end

-- Periodic check for pending changes (every 1 second, only save if changes pending and interval passed)
game:GetService("RunService").Heartbeat:Connect(function()
	-- All pending changes are now handled by UnifiedDataStoreManager
end)
