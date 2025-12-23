-- WeaponManager.lua
-- Handles weapon/tool usage: animations, sounds, effects


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local WeaponDataStore = require(script.Parent.WeaponDataStore)
local EnemyStatsDataStore = require(script.Parent.Parent.Enemies.EnemyStatsDataStore)
local DamageManager = require(script.Parent.Parent.DamageManager)

-- Create RemoteEvent for showing enemy damage text on clients
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end



local lastAttackTimes = {} -- keys are player instances
local WeaponManager = {}

-- Helper: Get or create Health IntValue for enemy
local function getOrCreateEnemyHealth(enemyModel, enemyStats)
	local enemyHealth = enemyModel:FindFirstChild("Health")
	if not enemyHealth then
		enemyHealth = Instance.new("IntValue")
		enemyHealth.Name = "Health"
		enemyHealth.Value = enemyStats and enemyStats.Health or 1
		enemyHealth.Parent = enemyModel
	end
	return enemyHealth
end



-- Modular attack logic for each weapon
function WeaponManager.PerformAttack(player, tool)
	if not player or not tool or not tool.Name then 
		warn("[WeaponManager] PerformAttack called with invalid args: player=" .. tostring(player) .. ", tool=" .. tostring(tool))
		return 
	end
	
	print("[WeaponManager] PerformAttack called for player " .. player.Name .. " with tool " .. tool.Name)
	local character = player.Character
	if not character then
		warn("[WeaponManager] Player " .. player.Name .. " has no character.")
		return
	end
	local backpack = player:FindFirstChild("Backpack") or player.Backpack
	if tool.Parent ~= character and tool.Parent ~= backpack then
		warn("[WeaponManager] Player " .. player.Name .. " does not own tool " .. tool.Name)
		return
	end
	if tool.Parent ~= character then
		warn("[WeaponManager] Player " .. player.Name .. " is not holding tool " .. tool.Name)
		return
	end

	-- Passed validation, perform attack
	local weaponName = tool.Name
	local weaponStats = WeaponData.GetWeaponStats(weaponName)
	local speed = weaponStats and weaponStats.speed or 1
	local now = tick()
	local lastAttack = lastAttackTimes[player] or 0
	if (now - lastAttack) < (speed) then
		warn("[WeaponManager] " .. player.Name .. " tried to attack too quickly with " .. weaponName)
		return
	end
	lastAttackTimes[player] = now

	local hitPart = tool:FindFirstChild("HitPart")
	if not hitPart then
		warn("[WeaponManager] Tool " .. tool.Name .. " has no HitPart child.")
		return
	end

	local hitEnemies = {}
	local deadEnemies = {} -- Track dead enemies to prevent further damage
	local function onTouched(hit)
		-- Ignore if hit is a player character
		local hitParent = hit.Parent
		if hitParent and Players:GetPlayerFromCharacter(hitParent) then
			return
		end
		local enemyModel = hit:FindFirstAncestorOfClass("Model")
		-- Only process if NOT a player character
		if enemyModel and enemyModel:FindFirstChild("Humanoid") and not hitEnemies[enemyModel] then
			if Players:GetPlayerFromCharacter(enemyModel) then
				return -- skip player models
			end
			-- Don't process if enemy is already dead
			if deadEnemies[enemyModel] then
				return
			end
			hitEnemies[enemyModel] = true
			local enemyName = enemyModel.Name
			local enemyStats = EnemyStatsDataStore.loadEnemyStats(enemyName)
			local enemyHealth = getOrCreateEnemyHealth(enemyModel, enemyStats)
			if not enemyHealth:IsA("IntValue") then
				warn("[WeaponManager] Enemy Health is not IntValue for model " .. enemyName)
				return
			end
			
			-- Calculate damage using DamageManager (attack + weapon + critical)
			local damage, isCritical, baseDamage, dexterity = DamageManager.calculateDamage(player, weaponName)
			
			local oldHealth = enemyHealth.Value
			enemyHealth.Value = math.max(oldHealth - damage, 0)
			
			-- Show damage text on all clients with critical indicator
			damageEvent:FireAllClients(enemyModel, damage, isCritical)
			
			local critText = isCritical and " [CRITICAL]" or ""
			print(string.format("[WeaponManager] %s hit enemy '%s' for %d damage%s. HP: %d/%d (Attack: %d, Weapon: %s, Dex: %d)", 
				player.Name, enemyName, damage, critText, enemyHealth.Value, enemyStats and enemyStats.Health or 1, baseDamage, weaponName, dexterity))
			
			if enemyHealth.Value <= 0 then
				print(string.format("[WeaponManager] Enemy '%s' defeated by %s", enemyName, player.Name))
				local humanoid = enemyModel:FindFirstChild("Humanoid")
				if humanoid then humanoid.Health = 0 end
				-- Mark enemy as dead to prevent further damage
				deadEnemies[enemyModel] = true
			end
		end
	end

	local touchedConn = hitPart.Touched:Connect(onTouched)
	task.delay(0.3, function()
		if touchedConn then touchedConn:Disconnect() end
	end)
end

-- Track tool connections to avoid duplicates
-- Map: uniqueToolId -> connection
local toolConnections = {}
-- Map: playerId -> table of tool IDs for that player
local playerToolIds = {}

-- Cleanup old tool connections for a player
local function cleanupPlayerToolConnections(player)
	local userId = player.UserId
	if playerToolIds[userId] then
		for _, toolId in ipairs(playerToolIds[userId]) do
			if toolConnections[toolId] then
				toolConnections[toolId]:Disconnect()
				toolConnections[toolId] = nil
				print("[WeaponManager] Disconnected old tool: " .. toolId)
			end
		end
		playerToolIds[userId] = {}
	end
end

-- Connect weapon/tool usage to effects and logic
function WeaponManager.ConnectTool(tool, player)
	if not tool or not tool.Name then 
		warn("[WeaponManager] Cannot connect tool: tool is nil or has no name")
		return 
	end
	
	if not player then
		warn("[WeaponManager] Cannot connect tool: player is nil")
		return
	end
	
	-- Get or create unique ID for this tool instance
	-- Use player ID + item ID to ensure uniqueness across all players
	local itemId = tool:GetAttribute("_ItemId") or ""
	local uniqueToolId = player.UserId .. "_" .. itemId
	
	-- If no item ID, fall back to player ID + tool name + timestamp
	if itemId == "" then
		uniqueToolId = player.UserId .. "_" .. tool.Name .. "_" .. tostring(tool)
	end
	
	-- Check if already connected (avoid duplicate listeners)
	if toolConnections[uniqueToolId] then
		print("[WeaponManager] Tool with ID '" .. uniqueToolId .. "' already connected, skipping")
		return
	end
	
	print("[WeaponManager] Connecting tool '" .. tool.Name .. "' with unique ID: " .. uniqueToolId .. " for player " .. player.Name)
	
	-- Wait for SwingEvent to exist (with timeout)
	local swingEvent = tool:FindFirstChild("SwingEvent")
	if not swingEvent then
		print("[WeaponManager] SwingEvent not found immediately, waiting for tool '" .. tool.Name .. "' to be ready...")
		swingEvent = tool:WaitForChild("SwingEvent", 5)
	end
	
	if not swingEvent then
		warn("[WeaponManager] Tool '" .. tool.Name .. "' does not have a SwingEvent after waiting")
		return
	end
	
	-- Store player reference with the tool for validation
	tool:SetAttribute("_OwnerUserId", player.UserId)
	
	-- Connect the event with closure capturing tool AND player
	local connection = swingEvent.OnServerEvent:Connect(function(attackingPlayer)
		-- Verify the attacking player owns this tool
		local ownerUserId = tool:GetAttribute("_OwnerUserId")
		if ownerUserId and ownerUserId ~= attackingPlayer.UserId then
			warn("[WeaponManager] Player " .. attackingPlayer.Name .. " tried to use tool owned by userId " .. tostring(ownerUserId))
			return
		end
		
		-- Verify tool still exists and is owned by the player
		-- Tool can be in: Player, Backpack, or Character depending on equipped state
		if not tool or not tool.Parent then
			warn("[WeaponManager] Tool no longer exists")
			return
		end
		
		local isToolInPlayerInventory = false
		if tool.Parent == attackingPlayer then
			isToolInPlayerInventory = true
		elseif tool.Parent == attackingPlayer.Backpack then
			isToolInPlayerInventory = true
		elseif tool.Parent == attackingPlayer.Character then
			isToolInPlayerInventory = true
		end
		
		if not isToolInPlayerInventory then
			print("[WeaponManager] Tool parent: " .. tostring(tool.Parent) .. ", expected player/backpack/character")
			return
		end
		
		print("[WeaponManager] SwingEvent triggered for player " .. attackingPlayer.Name .. " with tool " .. tool.Name)
		WeaponManager.PerformAttack(attackingPlayer, tool)
	end)
	
	-- Track this connection
	toolConnections[uniqueToolId] = connection
	
	-- Track which tools belong to this player
	playerToolIds[player.UserId] = playerToolIds[player.UserId] or {}
	table.insert(playerToolIds[player.UserId], uniqueToolId)
	
	print("[WeaponManager] Successfully connected tool '" .. tool.Name .. "' (ID: " .. uniqueToolId .. ") to player " .. player.Name)
end

-- Utility: Connect all tools in ReplicatedStorage.Weapons
function WeaponManager.ConnectAllWeapons()
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if weaponsFolder then
		for _, tool in ipairs(weaponsFolder:GetChildren()) do
			WeaponManager.ConnectTool(tool)
		end
	end
end

-- Cleanup: Called when player respawns or disconnects
function WeaponManager.CleanupPlayerTools(player)
	if not player then return end
	cleanupPlayerToolConnections(player)
	playerToolIds[player.UserId] = nil
	print("[WeaponManager] Cleaned up all tools for player " .. player.Name)
end


return WeaponManager
