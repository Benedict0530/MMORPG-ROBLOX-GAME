-- WeaponManager.lua
-- Handles weapon/tool usage: animations, sounds, effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local WeaponDataStore = require(script.Parent:WaitForChild("WeaponDataStore"))
local EnemyStatsDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("EnemyStatsDataStore"))
local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)
local PVPHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("PVPHandler"))

-- Create RemoteEvent for showing enemy damage text on clients
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end

local lastAttackTimes = {} -- keys are player instances
local WeaponManager = {}

-- Per-player flag to block swing events during equip
local blockSwingEvent = {}

-- Expose for InventoryManager to use
WeaponManager.blockSwingEvent = blockSwingEvent

-- Helper function to check if target is in front of or beside the attacker
-- Uses a 120-degree cone (front + sides)
local function isTargetInAttackCone(attackerRoot, targetRoot)
	local attackDirection = attackerRoot.CFrame.LookVector  -- Forward direction of attacker
	local directionToTarget = (targetRoot.Position - attackerRoot.Position).Unit
	
	-- Dot product: if >= 0.5, target is within ~60 degrees on either side (120 degree total cone)
	local dotProduct = attackDirection:Dot(directionToTarget)
	return dotProduct >= 0.5  -- Approximately 60 degrees from center
end

-- Helper function to cast a ray and check if it hits the target
local function raycastHitsTarget(attackerRoot, targetRoot, maxDistance)
	local rayOrigin = attackerRoot.Position
	local rayDirection = (targetRoot.Position - rayOrigin)
	local rayDistance = rayDirection.Magnitude
	
	-- Don't raycast if target is beyond max distance
	if rayDistance > maxDistance then
		return false
	end
	
	-- Create raycast params, ignoring the attacker and target themselves
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {attackerRoot.Parent, targetRoot.Parent}
	
	-- Cast ray towards target
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	-- If ray hit something, check if it's the target
	if rayResult then
		local hitPart = rayResult.Instance
		-- Check if hit part belongs to target enemy
		if hitPart:IsDescendantOf(targetRoot.Parent) then
			return true
		else
			-- Ray hit something else (obstacle) before target
			return false
		end
	else
		-- Ray didn't hit anything, direct line of sight to target
		return true
	end
end

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
function WeaponManager.PerformAttack(player, tool, weaponSpeed)
	print("[WeaponManager] PerformAttack called for player=" .. tostring(player) .. ", tool=" .. tostring(tool) .. ", weaponSpeed=" .. tostring(weaponSpeed))
	if not player or not tool or not tool.Name then 
		warn("[WeaponManager] PerformAttack called with invalid args: player=" .. tostring(player) .. ", tool=" .. tostring(tool))
		return 
	end
    
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
	-- Enforce server-side minimum interval between attacks based on weapon speed (animation duration)
	local minInterval = 0.4
	local now = tick()
	local lastAttack = lastAttackTimes[player] or 0
	if (now - lastAttack) < minInterval then
		print("[WeaponManager] Attack skipped for " .. player.Name .. " due to cooldown. Time since last: " .. tostring(now - lastAttack))
		return
	end
	lastAttackTimes[player] = now

	local hitPart = tool:FindFirstChild("HitPart")
	if not hitPart then
		warn("[WeaponManager] Tool " .. tool.Name .. " has no HitPart child.")
		return
	end

	print("[WeaponManager] Attack proceeding for " .. player.Name .. " with tool " .. tool.Name)

	local hitEnemies = {} -- Track which enemies have been hit this attack
	local deadEnemies = {} -- Track dead enemies to prevent further damage

	-- PVP proximity check (once per attack)
	local charRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if charRoot then
		-- Sphere-based check from the player's root part
		PVPHandler.RaycastPlayerHit(player, weaponName, hitEnemies, 5)
		
		-- Play attack sound to players within range
		SoundModule.playSoundInRange("AttackAudio", charRoot.Position, "SFX", 100, false)
	end

	-- Only allow one hit per enemy per trigger (Touched for NPCs only)
	local function onTouched(hit)
		-- ===== ENEMY DAMAGE =====
		local enemyModel = hit:FindFirstAncestorOfClass("Model")
		if enemyModel and enemyModel:FindFirstChild("Humanoid") then
			if Players:GetPlayerFromCharacter(enemyModel) then
				return -- skip player models
			end
			-- Prevent damage to NPCs
			if enemyModel:GetAttribute("IsNPC") then
				return -- skip NPCs
			end
			if deadEnemies[enemyModel] or hitEnemies[enemyModel] then return end

			local charRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
            
		if not charRoot or not enemyRoot then return end
		
		-- Check directional cone (120-degree) and raycast line-of-sight
		if not (isTargetInAttackCone(charRoot, enemyRoot) and raycastHitsTarget(charRoot, enemyRoot, 50)) then
			return
			end

			hitEnemies[enemyModel] = true

			-- Load enemy stats and apply damage
			local enemyName = enemyModel.Name
			local enemyStats = EnemyStatsDataStore.loadEnemyStats(enemyName)
			local enemyHealth = getOrCreateEnemyHealth(enemyModel, enemyStats)
            
			if not enemyHealth:IsA("IntValue") then
				warn("[WeaponManager] Enemy Health is not IntValue for model " .. enemyName)
				return
			end

			local damage, isCritical = DamageManager.calculateDamage(player, weaponName)
			local oldHealth = enemyHealth.Value
			enemyHealth.Value = math.max(oldHealth - damage, 0)
            
			SoundModule.playSoundInRange("Hit", enemyRoot.Position, "SFX", 100, false, 1)
			damageEvent:FireAllClients(enemyModel, damage, isCritical, true)
			print("[WeaponManager] " .. player.Name .. " hit enemy '" .. enemyName .. "' for " .. tostring(damage) .. " damage (crit: " .. tostring(isCritical) .. ") | Enemy health: " .. tostring(enemyHealth.Value) .. "/" .. tostring(oldHealth))

			-- Handle enemy death
			if enemyHealth.Value <= 0 then
				local humanoid = enemyModel:FindFirstChild("Humanoid")
				if humanoid then humanoid.Health = 0 end
				deadEnemies[enemyModel] = true
				print("[WeaponManager] Enemy '" .. enemyName .. "' killed by " .. player.Name)
			end
		end
	end

	local touchedConn = hitPart.Touched:Connect(onTouched)
	-- Only allow hit registration for a very short window (matches animation hit frame)
	local HIT_WINDOW = 0.1 -- seconds, should match the animation marker timing
	task.delay(HIT_WINDOW, function()
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
			end
		end
		playerToolIds[userId] = {}
	end
end

-- Connect weapon/tool usage to effects and logic
function WeaponManager.ConnectTool(tool, player)
	print("[WeaponManager] ConnectTool called for tool '" .. tostring(tool and tool.Name) .. "' and player '" .. tostring(player and player.Name) .. "'")
	if not tool or not tool.Name then 
		warn("[WeaponManager] Cannot connect tool: tool is nil or has no name")
		return 
	end
	if not player then
		warn("[WeaponManager] Cannot connect tool: player is nil")
		return
	end

	-- Get or create unique ID for this tool instance
	local itemId = tool:GetAttribute("_ItemId") or ""
	local uniqueToolId = player.UserId .. "_" .. itemId
	if itemId == "" then
		uniqueToolId = player.UserId .. "_" .. tool.Name .. "_" .. tostring(tool)
	end

	-- Always cleanup any previous connection for this tool
	if toolConnections[uniqueToolId] then
		toolConnections[uniqueToolId]:Disconnect()
		toolConnections[uniqueToolId] = nil
		print("[WeaponManager] Cleaned up previous connection for tool ID '" .. uniqueToolId .. "'")
	end

	-- Remove from playerToolIds if present (avoid duplicates)
	playerToolIds[player.UserId] = playerToolIds[player.UserId] or {}
	for i = #playerToolIds[player.UserId], 1, -1 do
		if playerToolIds[player.UserId][i] == uniqueToolId then
			table.remove(playerToolIds[player.UserId], i)
		end
	end

	-- Robustly wait for SwingEvent (up to 2 seconds)
	print("[WeaponManager] Waiting for SwingEvent on tool '" .. tool.Name .. "' for player '" .. player.Name .. "'")
	local swingEvent = tool:FindFirstChild("SwingEvent")
	local maxWait = 2
	local waited = 0
	local retryDelay = 0.05
	while not swingEvent and waited < maxWait do
		waited = waited + retryDelay
		task.wait(retryDelay)
		swingEvent = tool:FindFirstChild("SwingEvent")
	end
	if not swingEvent then
		warn("[WeaponManager] Tool '" .. tool.Name .. "' does not have a SwingEvent after waiting " .. tostring(maxWait) .. " seconds")
		return
	end
	print("[WeaponManager] Found SwingEvent for tool '" .. tool.Name .. "' for player '" .. player.Name .. "'")

	-- Store player reference with the tool for validation
	tool:SetAttribute("_OwnerUserId", player.UserId)

	-- Connect the event with closure capturing tool AND player
	local function onSwingEvent(attackingPlayer)
		print("[WeaponManager] onSwingEvent fired for player '" .. tostring(attackingPlayer and attackingPlayer.Name) .. "' with tool '" .. tostring(tool and tool.Name) .. "'")
		if blockSwingEvent[attackingPlayer] then
			warn("[WeaponManager] Ignoring swing event for " .. attackingPlayer.Name .. " while equipping")
			return
		end
		local ownerUserId = tool:GetAttribute("_OwnerUserId")
		if ownerUserId and ownerUserId ~= attackingPlayer.UserId then
			warn("[WeaponManager] Player " .. attackingPlayer.Name .. " tried to use tool owned by userId " .. tostring(ownerUserId))
			return
		end
		if not tool or not tool.Parent then
			warn("[WeaponManager] Tool no longer exists")
			return
		end
		local isToolInPlayerInventory = false
		if tool.Parent == attackingPlayer or tool.Parent == attackingPlayer.Backpack or tool.Parent == attackingPlayer.Character then
			isToolInPlayerInventory = true
		end
		if not isToolInPlayerInventory then
			print("[WeaponManager] Tool parent: " .. tostring(tool.Parent) .. ", expected player/backpack/character")
			return
		end
		-- Look up weapon speed on the server for safety
		local weaponStats = WeaponData.GetWeaponStats(tool.Name)
		local weaponSpeed = weaponStats and weaponStats.speed or 1
		print("[WeaponManager] Calling PerformAttack for player '" .. attackingPlayer.Name .. "' with tool '" .. tool.Name .. "'")
		WeaponManager.PerformAttack(attackingPlayer, tool, weaponSpeed)
	end

	local connection
	local success, err = pcall(function()
		connection = swingEvent.OnServerEvent:Connect(onSwingEvent)
	end)
	if not success or not connection then
		warn("[WeaponManager] Failed to connect SwingEvent for tool '" .. tool.Name .. "': " .. tostring(err))
		return
	end

	toolConnections[uniqueToolId] = connection
	table.insert(playerToolIds[player.UserId], uniqueToolId)
	print("[WeaponManager] Connected tool '" .. tool.Name .. "' for player " .. player.Name .. " (toolId: " .. uniqueToolId .. ")")
end

-- Cleanup: Called when player respawns or disconnects
function WeaponManager.CleanupPlayerTools(player)
	if not player then return end
	cleanupPlayerToolConnections(player)
	playerToolIds[player.UserId] = nil
end

return WeaponManager
