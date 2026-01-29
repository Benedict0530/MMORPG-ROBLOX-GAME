-- AdminCommandsHandler.lua
-- Handles admin commands like fly, walk speed, teleport, etc.

local AdminCommandsHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AdminId = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AdminId"))
local ServerStorage = game:GetService("ServerStorage")

-- Create RemoteEvent for admin commands
local function createAdminEvent()
	local existing = ReplicatedStorage:FindFirstChild("AdminCommandEvent")
	if existing then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = "AdminCommandEvent"
	event.Parent = ReplicatedStorage
	return event
end

local adminEvent = createAdminEvent()

-- Heal player
local function healPlayer(player)
	if not player.Character then
		return
	end
	
	local stats = player:FindFirstChild("Stats")
	if stats then
		local maxHealth = stats:FindFirstChild("MaxHealth")
		local currentHealth = stats:FindFirstChild("CurrentHealth")
		if maxHealth and currentHealth then
			currentHealth.Value = maxHealth.Value
			print("[AdminCommands] Healed " .. player.Name)
		end
	end
end

-- Set all combat stats to a specified value (max 300 for Dexterity)
local function setStats(adminPlayer, targetPlayer, statValue)
	if not targetPlayer.Character then
		return
	end
	
	-- Get OrbSpiritHandler to suspend stat listeners during admin change
	local ServerScriptService = game:GetService("ServerScriptService")
	local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("OrbSpiritHandler"))
	
	-- SUSPEND stat change listeners to prevent recursion
	-- [REMOVED] OrbSpiritHandler.SetAdminStatChangeFlag
	
	local stats = targetPlayer:FindFirstChild("Stats")
	if not stats then
		-- [REMOVED] OrbSpiritHandler.SetAdminStatChangeFlag
		return
	end
	
	-- List of combat stats to set
	local combatStats = {"Attack", "Defence", "MaxHealth", "MaxMana"}
	
	-- Set all combat stats
	for _, statName in ipairs(combatStats) do
		local statValue_obj = stats:FindFirstChild(statName)
		if statValue_obj then
			statValue_obj.Value = statValue
		end
	end
	
	-- Set Dexterity (max 300)
	local dexValue = stats:FindFirstChild("Dexterity")
	if dexValue then
		dexValue.Value = math.min(statValue, 300)
	end
	
	-- Update CurrentHealth to new MaxHealth
	local currentHealth = stats:FindFirstChild("CurrentHealth")
	local maxHealth = stats:FindFirstChild("MaxHealth")
	if currentHealth and maxHealth then
		currentHealth.Value = maxHealth.Value
	end
	
	-- Update CurrentMana to new MaxMana
	local currentMana = stats:FindFirstChild("CurrentMana")
	local maxMana = stats:FindFirstChild("MaxMana")
	if currentMana and maxMana then
		currentMana.Value = maxMana.Value
	end
	
	print("[AdminCommands] " .. adminPlayer.Name .. " set all combat stats to " .. statValue .. " for " .. targetPlayer.Name .. " (Dex capped at 300)")
	
	-- Save to datastore
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveStats(targetPlayer, false)
	
	-- RESUME stat change listeners and manually trigger buff recalculation
	OrbSpiritHandler.SetAdminStatChangeFlag(targetPlayer, false)
	-- Force UpdateBaseStats to recalculate buff with new admin-set stats
	-- [REMOVED] OrbSpiritHandler.UpdateBaseStats
	-- [REMOVED] OrbSpiritHandler.UpdateOrbBonusedStats
end

-- Kick player (admin only)
local function kickPlayer(admin, targetPlayer, reason)
	reason = reason or "Kicked by admin"
	targetPlayer:Kick(reason)
	print("[AdminCommands] Admin " .. admin.Name .. " kicked " .. targetPlayer.Name .. " - Reason: " .. reason)
end

-- Handle admin commands from client
adminEvent.OnServerEvent:Connect(function(player, command, ...)
	-- Check if player is admin
	if not AdminId.IsAdmin(player.UserId) then
		warn("[AdminCommands] Non-admin " .. player.Name .. " tried command: " .. command)
		return
	end
	
	local args = {...}

	-- ResetStats command
	if command == "ResetStats" then
		local targetName = args[1]
		local targetPlayer = player -- Default to self
		
		-- If a target name is provided, only verified admins can reset others
		if targetName then
			local adminType = AdminId.GetAdminType(player.UserId)
			if adminType ~= "verified" then
				warn("[AdminCommands] Only verified admins can reset other players' stats.")
				return
			end
			targetPlayer = Players:FindFirstChild(targetName)
			if not targetPlayer then
				print("[AdminCommands] Target player '" .. tostring(targetName) .. "' not found for ResetStats")
				return
			end
		end
		
		-- Get OrbSpiritHandler to suspend stat listeners during reset
		local ServerScriptService = game:GetService("ServerScriptService")
		local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("OrbSpiritHandler"))
		
		-- SUSPEND stat change listeners to prevent recursion
		OrbSpiritHandler.SetAdminStatChangeFlag(targetPlayer, true)
		
		local stats = targetPlayer:FindFirstChild("Stats")
		if stats then
			-- Reset battle stats and level/exp to defaults
			local resetDefaults = {
				MaxHealth = 10,
				CurrentHealth = 10,
				MaxMana = 5,
				CurrentMana = 5,
				Attack = 1,
				Defence = 1,
				ArmorDefence = 0,
				Dexterity = 1,
				Level = 1,
				Experience = 0,
				NeededExperience = 10,
				StatPoints = 3
			}
			for statName, defaultValue in pairs(resetDefaults) do
				local statVal = stats:FindFirstChild(statName)
				if statVal then
					statVal.Value = defaultValue
				end
			end
			
			-- Clear cached base stats in OrbSpiritHandler to prevent buff stacking
			OrbSpiritHandler.ClearPlayerBaseStats(targetPlayer)
			
			if targetPlayer == player then
				print("[AdminCommands] " .. player.Name .. " reset their own stats (and cleared orb base stats cache)")
			else
				print("[AdminCommands] " .. player.Name .. " reset stats for " .. targetPlayer.Name .. " (and cleared orb base stats cache)")
			end
			-- Save to datastore
			local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
			UnifiedDataStoreManager.SaveLevelData(targetPlayer, false)  -- Changed from true to false to respect throttling
		end
		
		-- RESUME stat change listeners and manually trigger buff recalculation
		OrbSpiritHandler.SetAdminStatChangeFlag(targetPlayer, false)
		-- Force UpdateBaseStats to recalculate buff with reset stats
		OrbSpiritHandler.UpdateBaseStats(targetPlayer)
		return
	end
	
	if command == "WalkSpeed" then
		local speed = args[1] or 16
		setWalkSpeed(player, speed)
	
	elseif command == "Heal" then
		healPlayer(player)
	
	elseif command == "Teleport" then
		local x, y, z = args[1], args[2], args[3]
		if x and y and z then
			teleportPlayer(player, Vector3.new(x, y, z))
		end
	
	elseif command == "TeleportToMap" then
		local mapName = args[1]
		local spawnName = args[2] or "SpawnLocation"
		if mapName then
			teleportToMap(player, mapName, spawnName)
		end
	
	elseif command == "Stats" then
		local statValue = tonumber(args[1]) or 100
		
		-- Stats command sets all combat stats for the admin's own character
		setStats(player, player, statValue)
	
	elseif command == "Kick" then
		local targetName = args[1]
		local reason = args[2] or "Kicked by admin"
		local targetPlayer = Players:FindFirstChild(targetName)
		if targetPlayer then
			kickPlayer(player, targetPlayer, reason)
		end
	
	elseif command == "Orb" then
		local ServerScriptService = game:GetService("ServerScriptService")
		local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
		local adminType = AdminId.GetAdminType(player.UserId)
		
		-- Get orbs folder
		local orbsFolder = ServerStorage:FindFirstChild("Orbs")
		if not orbsFolder then
			print("[AdminCommands] ServerStorage.Orbs folder not found")
			return
		end
		
		-- Helper function to convert "FireOrb" to "Fire Orb"
		local function formatOrbName(name)
			-- Insert space before capital letters (except the first one)
			local formatted = name:gsub("([A-Z])([A-Z][a-z])", "%1 %2")
			formatted = formatted:gsub("([a-z])([A-Z])", "%1 %2")
			return formatted
		end
		
		-- Parse arguments: /orb orbName OR /orb playerName orbName
		local orbName, targetPlayer
		
		if #args < 1 then
			print("[AdminCommands] Invalid orb command syntax. Use: /orb orbName OR /orb playerName orbName")
			print("[AdminCommands] Examples: /orb FireOrb  OR  /orb PlayerName FireOrb")
			return
		end
		
		-- Check if args[1] is a player name (for admins giving to others)
		local potentialPlayer = Players:FindFirstChild(args[1])
		
		if potentialPlayer and #args >= 2 and AdminId.IsAdmin(player.UserId) then
			-- /orb playerName orbName format (admin can give to others)
			local targetName = args[1]
			local orbNameRaw = args[2]
			orbName = formatOrbName(orbNameRaw)
			targetPlayer = potentialPlayer
		else
			-- /orb orbName format (give to self)
			local orbNameRaw = args[1]
			orbName = formatOrbName(orbNameRaw)
			targetPlayer = player
		end
		
		-- Final check if orb exists
		if not orbsFolder:FindFirstChild(orbName) then
			print("[AdminCommands] Orb '" .. orbName .. "' not found in ServerStorage.Orbs")
			return
		end
		
		-- Add orb to inventory (now inventory-based system)
		local ok, itemId = InventoryManager.AddItem(targetPlayer, orbName, "spirit orb")
		if ok then
			print("[AdminCommands] " .. player.Name .. " gave orb '" .. orbName .. "' to " .. targetPlayer.Name)
			-- Fire InventoryChanged event to update client UI
			local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
			if inventoryChangedEvent then
				inventoryChangedEvent:FireClient(targetPlayer)
			end
		else
			print("[AdminCommands] Failed to give orb '" .. orbName .. "' to " .. targetPlayer.Name)
		end
	elseif command == "ResetData" then
		-- Reset data for a specific player
		local adminType = AdminId.GetAdminType(player.UserId)
		if adminType ~= "verified" then
			print("[AdminCommands] Only verified admins can use ResetData.")
			return
		end
		
		local targetName = args[1]
		local targetPlayer = Players:FindFirstChild(targetName)
		if not targetPlayer then
			print("[AdminCommands] Target player '" .. tostring(targetName) .. "' not found for ResetData")
			return
		end
		
		local ServerScriptService = game:GetService("ServerScriptService")
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		
		local success = UnifiedDataStoreManager.ResetPlayerData(targetPlayer.UserId)
		if success then
			print("[AdminCommands] " .. player.Name .. " reset all data for " .. targetPlayer.Name)
		else
			print("[AdminCommands] Failed to reset data for " .. targetPlayer.Name)
		end
	
	elseif command == "ResetAllData" then
		-- Reset data for all players (verified admins only)
		local adminType = AdminId.GetAdminType(player.UserId)
		if adminType ~= "verified" then
			print("[AdminCommands] Only verified admins can use ResetAllData.")
			return
		end
		
		local ServerScriptService = game:GetService("ServerScriptService")
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		
		local successCount, failureCount = UnifiedDataStoreManager.ResetAllPlayersData()
		print("[AdminCommands] " .. player.Name .. " reset all players data - Success: " .. successCount .. ", Failures: " .. failureCount)
	end
end)

-- Cleanup fly when player leaves
Players.PlayerRemoving:Connect(function(player)
	-- Removed: stopFly(player)
end)

-- Cleanup fly when character dies
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Removed: Stop fly on respawn
	end)
end)

-- Removed: Continuous fly update loop
-- Fly system has been removed

return AdminCommandsHandler

