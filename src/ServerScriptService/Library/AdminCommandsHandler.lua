-- AdminCommandsHandler.lua
-- Handles admin commands like fly, walk speed, teleport, etc.

local AdminCommandsHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AdminId = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AdminId"))

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

-- Add levels to a player with stat points
local function addLevels(adminPlayer, targetPlayer, levelAmount)
	if not targetPlayer.Character then
		return
	end
	
	local stats = targetPlayer:FindFirstChild("Stats")
	if not stats then
		return
	end
	
	-- Get current level
	local levelValue = stats:FindFirstChild("Level")
	if not levelValue then
		return
	end

	local currentLevel = levelValue.Value
	local newLevel = currentLevel + levelAmount

	-- Update level
	levelValue.Value = newLevel

	-- Adjust NeededExperience to match new level (same formula as LevelSystem, default 10)
	local neededExperience = stats:FindFirstChild("NeededExperience")
	if neededExperience then
		neededExperience.Value = math.floor(10 * (1.2 ^ (newLevel - 1)))
	end

	-- Add stat points (3 points per level)
	local statPointsValue = stats:FindFirstChild("StatPoints")
	if not statPointsValue then
		-- Create StatPoints if it doesn't exist
		statPointsValue = Instance.new("NumberValue")
		statPointsValue.Name = "StatPoints"
		statPointsValue.Value = 0
		statPointsValue.Parent = stats
	end

	statPointsValue.Value = statPointsValue.Value + (levelAmount * 3)

	-- Restore full health when leveling up
	local currentHealthValue = stats:FindFirstChild("CurrentHealth")
	local maxHealthValue = stats:FindFirstChild("MaxHealth")
	if currentHealthValue and maxHealthValue then
		currentHealthValue.Value = maxHealthValue.Value
	end

	print("[AdminCommands] " .. adminPlayer.Name .. " added " .. levelAmount .. " levels to " .. targetPlayer.Name .. " (Now level " .. newLevel .. ", +"..(levelAmount * 3).." stat points)")

	-- Save to datastore
	local ServerScriptService = game:GetService("ServerScriptService")
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveLevelData(targetPlayer, true)
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
		local adminType = AdminId.GetAdminType(player.UserId)
		if adminType ~= "verified" then
			warn("[AdminCommands] Only verified admins can use ResetStats.")
			return
		end
		local targetName = args[1]
		local targetPlayer = Players:FindFirstChild(targetName)
		if not targetPlayer then
			print("[AdminCommands] Target player '" .. tostring(targetName) .. "' not found for ResetStats")
			return
		end
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
			print("[AdminCommands] Reset battle stats and level/exp for " .. targetPlayer.Name)
			-- Save to datastore
			local ServerScriptService = game:GetService("ServerScriptService")
			local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
			UnifiedDataStoreManager.SaveLevelData(targetPlayer, true)
		end
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
	
	elseif command == "AddLevels" then
		-- Get admin tier
		local adminType = AdminId.GetAdminType(player.UserId)
		
		local targetName = args[1]
		local levelAmount = tonumber(args[2]) or 1
		
		-- Find target player
		local targetPlayer = Players:FindFirstChild(targetName)
		if not targetPlayer then
			print("[AdminCommands] Target player '" .. targetName .. "' not found")
			return
		end
		
		-- Check permissions
		if adminType == "verified" then
			-- Verified admins can add levels to anyone
			addLevels(player, targetPlayer, levelAmount)
		elseif adminType == "admin" then
			-- Regular admins can only add levels to themselves
			if targetPlayer == player then
				addLevels(player, targetPlayer, levelAmount)
			else
				warn("[AdminCommands] Admin " .. player.Name .. " tried to add levels to other player " .. targetPlayer.Name .. " (not verified)")
			end
		end
	
	elseif command == "Kick" then
		local targetName = args[1]
		local reason = args[2] or "Kicked by admin"
		local targetPlayer = Players:FindFirstChild(targetName)
		if targetPlayer then
			kickPlayer(player, targetPlayer, reason)
		end
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

