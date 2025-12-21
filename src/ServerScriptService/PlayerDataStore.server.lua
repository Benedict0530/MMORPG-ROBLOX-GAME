-- PlayerDataStore.server.lua
-- Stores and loads player stats: Health, Mana, Attack, Defence, Dexterity, Money

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local statsStore = DataStoreService:GetDataStore("PlayerStats")

local DEFAULT_STATS = {
	Health = 50,
	Mana = 5,
	Attack = 1,
	Defence = 1,
	Dexterity = 1,
	Money = 0,
	Level = 1,
	Experience = 0,
	NeededExperience = 10,
	Equipped = "Twig"
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

local function saveStats(player)
	local key = "Player_" .. player.UserId
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local data = {}
	for _, stat in ipairs(stats:GetChildren()) do
		-- Only exclude Health (calculated value), save everything else including NeededExperience
		if stat.Name ~= "Health" then
			data[stat.Name] = stat.Value
		end
	end
	-- Always keep Health at default in DataStore (runtime value)
	data["Health"] = DEFAULT_STATS.Health
	pcall(function()
		statsStore:SetAsync(key, data)
	end)
end

local function setupStatsFolder(player, data)
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = player
	for statName, value in pairs(data) do
		local statValue
		-- Create StringValue for Equipped stat, IntValue for everything else
		if statName == "Equipped" then
			statValue = Instance.new("StringValue")
		else
			statValue = Instance.new("IntValue")
		end
		statValue.Name = statName
		statValue.Value = value
		statValue.Parent = statsFolder
	end
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
		if createSuccess then
			print("[PlayerDataStore] Created new data for player " .. player.Name .. " (" .. player.UserId .. ")")
		else
			warn("[PlayerDataStore] Failed to create data for player " .. player.Name .. " (" .. player.UserId .. "): " .. tostring(createErr))
		end
		data = table.clone(DEFAULT_STATS)
	else
		print("[PlayerDataStore] Loaded data for player " .. player.Name .. " (" .. player.UserId .. ")")
		-- If Health is nil or <= 0, reset to default max
		if data["Health"] == nil or data["Health"] <= 0 then
			data["Health"] = DEFAULT_STATS.Health
		end
	end
	-- Remove any existing Stats folder to ensure reset
	local oldStats = player:FindFirstChild("Stats")
	if oldStats then
		oldStats:Destroy()
	end
	-- Log all data
	local function tableToString(tbl)
		local str = "{ "
		for k, v in pairs(tbl) do
			str = str .. tostring(k) .. " = " .. tostring(v) .. ", "
		end
		return str .. "}"
	end
	print("[PlayerDataStore] Data for " .. player.Name .. ": " .. tableToString(data))
	setupStatsFolder(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	saveStats(player)
end)

-- Optionally, save all players on server shutdown
if game:IsA("DataModel") then
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			saveStats(player)
		end
	end)
end
