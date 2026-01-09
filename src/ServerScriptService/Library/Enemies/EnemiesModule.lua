local EnemiesManager = {}
local playerHP = {} -- Shared player HP table for all enemies
local DEFAULT_MAX_HEALTH = 1
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Load DamageManager for incoming damage calculations
local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))

-- Load ItemDropManager for handling drops
local ItemDropManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ItemDropManager"))

local SoundModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("SoundModule"))

-- Add all Map folder parts to "Env" collision group once at startup
local function initializeMapCollision()
	local mapFolder = workspace:FindFirstChild("Map")
	if mapFolder then
		local function addMapToEnvironment(obj)
			if not obj then return end
			if obj:IsA("BasePart") then
				pcall(function() PhysicsService:CollisionGroupAddMember("Env", obj) end)
			end
			for _, child in ipairs(obj:GetChildren()) do addMapToEnvironment(child) end
		end
		addMapToEnvironment(mapFolder)
	end
end

-- Initialize map collision on module load
task.defer(initializeMapCollision)

-- Monitor for new parts added to Map folder
local mapFolder = workspace:FindFirstChild("Map")
if mapFolder then
	mapFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			task.wait(0.1) -- Small delay to ensure part is fully initialized
			pcall(function() PhysicsService:CollisionGroupAddMember("Env", descendant) end)
		end
	end)
end

-- Add player characters to Players collision group
local function addCharacterPartsToCollisionGroup(character)
	if not character then return end
	task.wait(0.1) -- Wait for character to fully load
	local function addCharacterPartsToGroup(obj)
		if not obj then return end
		if obj:IsA("BasePart") then
			obj.CollisionGroup = "Players"
		end
		for _, child in ipairs(obj:GetChildren()) do addCharacterPartsToGroup(child) end
	end
	addCharacterPartsToGroup(character)
	
	-- Also monitor for new parts added to character (accessories, etc)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			task.wait(0.05) -- Small delay to ensure part is ready
			descendant.CollisionGroup = "Players"
		end
	end)
end

local function addPlayerToGroup(player)
	-- Add current character if it exists
	if player.Character then
		addCharacterPartsToCollisionGroup(player.Character)
	end
	-- Add future characters
	player.CharacterAdded:Connect(function(character)
		addCharacterPartsToCollisionGroup(character)
	end)
end

-- Add existing players
for _, player in ipairs(Players:GetPlayers()) do
	addPlayerToGroup(player)
end

-- Monitor new players
Players.PlayerAdded:Connect(function(player)
	addPlayerToGroup(player)
end)


function EnemiesManager.Start(model)
	local slime = model
	-- DEBUG: Print all children and part info for this enemy model
	print("[EnemyInit] Initializing enemy:", slime.Name)
	local function printChildren(obj, indent)
		indent = indent or ""
		for _, child in ipairs(obj:GetChildren()) do
			local info = indent .. "- " .. child.Name .. " (" .. child.ClassName .. ")"
			if child:IsA("BasePart") then
				info = info .. string.format(" [CanCollide=%s, Anchored=%s, CollisionGroup=%s]", tostring(child.CanCollide), tostring(child.Anchored), child.CollisionGroup)
			end
			print(info)
			printChildren(child, indent .. "  ")
		end
	end
	printChildren(slime)
	if not slime then warn("[EnemiesModule] Model not found!"); return end
	
	-- Prevent double initialization (might be called from both DescendantAdded and respawn code)
	if slime:GetAttribute("_EnemyInitialized") then
		return
	end
	slime:SetAttribute("_EnemyInitialized", true)
	
	local COLLISION_GROUP = "Enemies"
	pcall(function() PhysicsService:RegisterCollisionGroup(COLLISION_GROUP) end)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Env", true) end)

	local function setCollisionGroupRecursive(obj)
		if not obj then return end
		if obj:IsA("BasePart") then obj.CollisionGroup = COLLISION_GROUP end
		for _, child in ipairs(obj:GetChildren()) do setCollisionGroupRecursive(child) end
	end
	setCollisionGroupRecursive(slime)

	local humanoid = slime:FindFirstChild("Humanoid")
	if not humanoid then warn("[EnemiesModule] Humanoid not found in model!") end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = slime:FindFirstChild("HumanoidRootPart")
	if not root then warn("[EnemiesModule] HumanoidRootPart not found in model!"); return end
		
	-- Wait a bit for the model to settle into its position before capturing spawn location
	task.wait(0.1)
	local defaultPosition = root and root.Position or nil

	-- Load all enemy stats from datastore based on enemy name
	local enemyStatsDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("EnemyStatsDataStore"))
	local enemyStats = enemyStatsDataStore.loadEnemyStats(slime.Name)
	
	-- Map stats from datastore
	local maxEnemyHealth = enemyStats and enemyStats.Health or 1
	local damage = enemyStats and enemyStats.Attack or 1
	local coinValue = enemyStats and enemyStats.Money or 1
	local drops = enemyStats and enemyStats.Drops or {}
	
	-- Combat parameters
	local jumpPower, detectionRange = 5, 30
	local head = slime:FindFirstChild("Head")
	if not head then warn("[GloopCrusher] Head not found in model!") end
	local cooldown = 1
	local hitCooldowns, touchDebounce = {}, {}
	local touchConnection -- Store the connection to disconnect later

	local statsStore = game:GetService("DataStoreService"):GetDataStore("PlayerStats")
	local lastDamagedByPlayer = nil -- Track which player dealt damage to this enemy
	local playerStatConnections = {} -- Store connections to player stat changes for cleanup
	local playerDamage = {} -- Track damage dealt by each player for experience distribution
	
	-- Get DamageEvent to notify clients of damage
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
	if not damageEvent then
		damageEvent = Instance.new("RemoteEvent")
		damageEvent.Name = "EnemyDamage"
		damageEvent.Parent = ReplicatedStorage
	end
	
	-- Setup real-time listener for player stat changes
	local function setupPlayerStatListener(player)
		local userId = player.UserId
		local stats = player:FindFirstChild("Stats")
		if not stats then return end
		
		-- Listen to MaxHealth changes to update player's actual max capacity
		local maxHealth = stats:FindFirstChild("MaxHealth")
		if maxHealth and not playerStatConnections[userId] then
			playerStatConnections[userId] = maxHealth.Changed:Connect(function(newMaxHealth)
				-- When player allocates to MaxHealth, update our tracking
				if not playerHP[userId] then
					playerHP[userId] = newMaxHealth
				end
		end)
		end
	end
	
	-- Create enemy health bar BillboardGui
	local function createEnemyHealthBar(enemyModel, maxHealth)
		if not head or not head.Parent then return end
		
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 0.5, 0)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.MaxDistance = 100
		billboard.Parent = head
		
		-- Background frame for health bar
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, 0, 1, 0)
		barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		barBg.BackgroundTransparency = 0.5
		barBg.BorderSizePixel = 1
		barBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
		barBg.Parent = billboard
		barBg.Name = "HealthBarBG"
		
		-- Add corner to background
		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 10)
		bgCorner.Parent = barBg
		
		-- Health bar fill
		local healthBar = Instance.new("Frame")
		healthBar.Size = UDim2.new(1, 0, 1, 0)
		healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green
		healthBar.BackgroundTransparency = 0.5
		healthBar.BorderSizePixel = 0
		healthBar.Parent = barBg
		healthBar.Name = "HealthBarFill"
		
		-- Add corner to health fill
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 10)
		fillCorner.Parent = healthBar
		
		return billboard, barBg
	end

	local function updateStatsFolderFromData(player, data)
		if not player or not data then return end
		local statsFolder = player:FindFirstChild("Stats")
		if not statsFolder then
			statsFolder = Instance.new("Folder")
			statsFolder.Name = "Stats"
			statsFolder.Parent = player
		end
		for statName, value in pairs(data) do
			local statObj = statsFolder:FindFirstChild(statName)
			if not statObj then
				statObj = Instance.new("IntValue")
				statObj.Name = statName
				statObj.Parent = statsFolder
			end
			statObj.Value = value
		end
	end

	local function getPlayerMaxHealth(player)
		local userId, key = player.UserId, "Player_" .. player.UserId
		local data; local success, err = pcall(function() data = statsStore:GetAsync(key) end)
		if success and data and type(data["MaxHealth"]) == "number" and data["MaxHealth"] > 0 then
			updateStatsFolderFromData(player, data)
			return data["MaxHealth"]
		else
			warn("[GloopCrusher] Could not load valid max health for player " .. player.Name .. ": " .. tostring(err))
			pcall(function()
				statsStore:UpdateAsync(key, function(old)
					old = old or {}; old["MaxHealth"] = DEFAULT_MAX_HEALTH; return old
				end)
			end)
			updateStatsFolderFromData(player, {MaxHealth = DEFAULT_MAX_HEALTH})
			return DEFAULT_MAX_HEALTH
		end
	end

	if head then
		touchConnection = head.Touched:Connect(function(hit)
			local character = hit.Parent
			if character and character:FindFirstChild("Humanoid") then
				local player = Players:GetPlayerFromCharacter(character)
				if player then
					local userId = player.UserId
					-- Setup real-time listener for this player's stats if not already done
					if not playerStatConnections[userId] then
						setupPlayerStatListener(player)
					end
					if touchDebounce[userId] then return end
					touchDebounce[userId] = true
					task.delay(1, function() touchDebounce[userId] = nil end)
				if not hitCooldowns[userId] or tick() - hitCooldowns[userId] > cooldown then
					-- Always get current health from player's Stats folder (DataStore source of truth)
					local statsFolder = player:FindFirstChild("Stats")
					if not statsFolder then return end
					
					local currentHealthValue = statsFolder:FindFirstChild("CurrentHealth")
					local maxHealthValue = statsFolder:FindFirstChild("MaxHealth")
					if not currentHealthValue or not maxHealthValue then return end
					
					-- Check if player is already dead
					if currentHealthValue.Value <= 0 then return end
					
					-- Calculate actual damage after player's defense reduction
					local actualDamage = DamageManager.CalculateIncomingDamage(damage, player)
					
					-- Apply damage directly to the DataStore-synced CurrentHealth
					currentHealthValue.Value = math.max(currentHealthValue.Value - actualDamage, 0)
					lastDamagedByPlayer = player -- Track who damaged this enemy
					
					-- Track damage dealt by this player for experience distribution
					playerDamage[userId] = (playerDamage[userId] or 0) + actualDamage
					
					hitCooldowns[userId] = tick()
					
					-- Show damage text on client (even if 0 damage, shows "-0") (false = enemy damage, red)
					local character = player.Character
					if character then
						local targetPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
						if targetPart then
							damageEvent:FireClient(player, targetPart, actualDamage, false, false)
						end
					end
					
					-- Debug: Show defense reduction with proper stats
					local defence, armorDefense, defensiveOutput = DamageManager.GetDefenseInfo(player)
					
					-- If player died from this hit
					if currentHealthValue.Value <= 0 then
						if character then character:BreakJoints() end
					end
				end
				end
			end
		end)
	end

	local function findNearestPlayer()
		local nearest, shortestDistance = nil, detectionRange
		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local playerRoot = player.Character.HumanoidRootPart
				local distance = (playerRoot.Position - root.Position).Magnitude
				if distance < shortestDistance then
					shortestDistance = distance
					nearest = player.Character
				end
			end
		end
		return nearest
	end
	
	-- Create enemy health bar
	local healthBarBillboard = createEnemyHealthBar(slime, maxEnemyHealth)
	local currentHealth = maxEnemyHealth
	
	-- Create health value if it doesn't exist
	local enemyHealth = slime:FindFirstChild("Health")
	if not enemyHealth then
		enemyHealth = Instance.new("IntValue")
		enemyHealth.Name = "Health"
		enemyHealth.Value = maxEnemyHealth
		enemyHealth.Parent = slime
	else
		-- If health already exists, update it to max
		enemyHealth.Value = maxEnemyHealth
	end
	
	local isDead = false -- Flag to prevent damage after death
	local parent, enemyName, respawnPosition = slime.Parent, slime.Name, nil
	
	-- Function to update health bar
	local function updateEnemyHealthBar()
		if not healthBarBillboard or not healthBarBillboard.Parent then return end
		
		-- Find the background frame first
		local barBg = healthBarBillboard:FindFirstChild("HealthBarBG")
		if not barBg then return end
		
		-- Now find the health fill inside the background
		local healthBarFill = barBg:FindFirstChild("HealthBarFill")
		local newHealth = enemyHealth.Value
		
		if healthBarFill then
			local healthPercent = math.max(0, math.min(newHealth / maxEnemyHealth, 1))
			healthBarFill.Size = UDim2.new(healthPercent, 0, 1, 0)
			
			-- Change color based on health
			if healthPercent > 0.5 then
				healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green
			elseif healthPercent > 0.25 then
				healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
			else
				healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
			end
						
			-- Flash animation when taking damage
			task.spawn(function()
				local originalColor = healthBarFill.BackgroundColor3
				healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White flash
				task.wait(0.05)
				healthBarFill.BackgroundColor3 = originalColor
			end)
		end
	end
	
	-- Update health bar when enemy health changes
	enemyHealth.Changed:Connect(function(newHealth)
		-- Ignore all health changes after enemy dies
		if isDead then return end
		
		currentHealth = newHealth
		updateEnemyHealthBar()
		
		-- Trigger hit particle effect
		local hitParticle = slime:FindFirstChild("Hit particle")
		if hitParticle then
			local attachment = hitParticle:FindFirstChildOfClass("Attachment")
			if attachment then
				local particleEmitter = attachment:FindFirstChildOfClass("ParticleEmitter")
				if particleEmitter then
					particleEmitter.Enabled = true
					particleEmitter:Emit(10)
					task.wait(0.5)
					particleEmitter.Enabled = false
				end
			end
		end
	end)

	local desiredFacingCFrame = root and root.CFrame or CFrame.new()
	local desiredVelocity = Vector3.new(0, 0, 0)
	local groundedFrames = 0
	
	task.spawn(function()
		while humanoid and humanoid.Health > 0 do
			if root and desiredFacingCFrame then
				root.CFrame = root.CFrame:Lerp(desiredFacingCFrame, 0.1)  -- Smoother rotation
			end
			task.wait(0.016)  -- ~60fps for smoother updates
		end
	end)

	local function isGrounded()
		if not root then return false end
		local rayOrigin, rayDirection = root.Position, Vector3.new(0, -3.5, 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {root.Parent}
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		return result ~= nil
	end

	local function moveTowardsTarget()
		while humanoid and humanoid.Health > 0 do
			local isOnGround = isGrounded()
			
			-- Find target and move towards it
			local target = findNearestPlayer()
			local targetDirection = Vector3.new(0, 0, 0)
			local distanceToPlayer = math.huge
			
			if target then
				local targetRoot = target:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					-- Calculate direction to player
					targetDirection = (targetRoot.Position - root.Position).unit
					distanceToPlayer = (targetRoot.Position - root.Position).Magnitude
					desiredFacingCFrame = CFrame.new(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
				end
			elseif defaultPosition then
				local direction = (defaultPosition - root.Position)
				if direction.Magnitude > 1 then
					targetDirection = direction.unit
					desiredFacingCFrame = CFrame.new(root.Position, defaultPosition)
				end
			end
			
			-- Move towards target (walk, no jumping)
			if targetDirection.Magnitude > 0 then
				local currentVel = root.Velocity
				-- Keep current Y velocity (gravity), add horizontal movement
				root.Velocity = Vector3.new(targetDirection.X * 20, currentVel.Y, targetDirection.Z * 20)
			else
				-- No target, apply friction
				local currentVel = root.Velocity
				root.Velocity = Vector3.new(currentVel.X * 0.95, currentVel.Y, currentVel.Z * 0.95)
			end
			
			-- Jump continuously while touching/very close to player (attack range ~5 studs)
			if distanceToPlayer < 5 and isOnGround then
				root.Velocity = Vector3.new(root.Velocity.X, jumpPower, root.Velocity.Z)
			end
			
			task.wait(0.016)  -- Consistent 60fps update
		end
	end

	if humanoid then
		humanoid.Died:Connect(function()
			isDead = true -- Mark enemy as dead to prevent further damage
			enemyHealth.Value = 0 -- Ensure health is 0
			
			-- IMMEDIATELY set up collision group to prevent dead enemy from hitting players
			pcall(function() PhysicsService:RegisterCollisionGroup("DeadEnemies") end)
			PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "DeadEnemies", true)
			
			-- Add all slime parts to DeadEnemies group immediately
			local function addToDeadEnemiesGroup(obj)
				if not obj then return end
				if obj:IsA("BasePart") then 
					obj.CollisionGroup = "DeadEnemies"
				end
				for _, child in ipairs(obj:GetChildren()) do addToDeadEnemiesGroup(child) end
			end
			addToDeadEnemiesGroup(slime)
			
			-- Disconnect the damage connection so dead slime doesn't hurt players
			if touchConnection then
				touchConnection:Disconnect()
			end
			
			-- Cleanup all player stat listeners
			for userId, connection in pairs(playerStatConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(playerStatConnections)
			
			respawnPosition = defaultPosition  -- Save the spawn position for respawn
		
		-- Get enemy experience reward
		local enemyExperience = enemyStats and enemyStats.Experience or 0
		
		-- Calculate total damage dealt by all players
		local totalDamage = 0
		for userId, damage in pairs(playerDamage) do
			totalDamage = totalDamage + damage
		end
		
		-- Debug: Log experience distribution
		print("[EnemiesModule] Enemy died:", enemyName, "| Experience:", enemyExperience, "| Total Damage:", totalDamage, "| Players who damaged:", table.getn(playerDamage))
		
		-- Distribute experience to all players who dealt damage, proportional to their damage
		if enemyExperience > 0 then
			if totalDamage > 0 then
				-- Normal case: distribute proportionally based on damage dealt
				for userId, damageDealt in pairs(playerDamage) do
					local player = Players:GetPlayerByUserId(userId)
					if player then
						local stats = player:FindFirstChild("Stats")
						if stats then
							-- Calculate this player's share of experience
							local damagePercentage = damageDealt / totalDamage
							local playerExperience = math.floor(enemyExperience * damagePercentage)
							
							-- Award experience (minimum 1 XP per damaging player, or proportional if small amounts)
							local xpToAward = math.max(playerExperience, 1)
							
							local experienceValue = stats:FindFirstChild("Experience")
							if experienceValue then
								experienceValue.Value = experienceValue.Value + xpToAward
								print("[EnemiesModule] Awarded", xpToAward, "XP to", player.Name)
								
								-- NO LONGER writing directly to DataStore on every XP gain
								-- LevelSystem.server.lua will handle throttled saves when Experience changes
							end
						end
					end
				end
			else
				-- Fallback: no damage tracked but players might be nearby, find nearest players and award them
				print("[EnemiesModule] WARNING: No damage tracked for", enemyName, "! Finding nearby players...")
				local nearbyPlayers = {}
				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						local playerRoot = player.Character.HumanoidRootPart
						local distance = (playerRoot.Position - root.Position).Magnitude
						if distance < 100 then -- Award XP to players within 100 studs
							table.insert(nearbyPlayers, {player = player, distance = distance})
						end
					end
				end
				
				-- Award XP equally to nearby players (or full amount if only one)
				if #nearbyPlayers > 0 then
					local xpPerPlayer = math.floor(enemyExperience / #nearbyPlayers)
					xpPerPlayer = math.max(xpPerPlayer, 1)
					
					for _, entry in ipairs(nearbyPlayers) do
						local player = entry.player
						local stats = player:FindFirstChild("Stats")
						if stats then
							local experienceValue = stats:FindFirstChild("Experience")
							if experienceValue then
								experienceValue.Value = experienceValue.Value + xpPerPlayer
								print("[EnemiesModule] Awarded", xpPerPlayer, "XP to nearby player", player.Name, "(distance:", math.floor(entry.distance), "studs)")
							end
						end
					end
				else
					print("[EnemiesModule] WARNING: No nearby players found for", enemyName, "!")
				end
			end
		end
	
	local ServerStorage = game:GetService("ServerStorage")
	
	-- Determine spawn position for drops
	local dropSpawnPosition = root.Position + Vector3.new(0, -2, 0)
	if lastDamagedByPlayer and lastDamagedByPlayer.Character then
		local playerRoot = lastDamagedByPlayer.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			dropSpawnPosition = Vector3.new(playerRoot.Position.X, root.Position.Y, playerRoot.Position.Z)
		end
	end
	
	-- Spawn coins
	local coinTemplate = ServerStorage:FindFirstChild("Coin")
	
	if coinTemplate then
		-- Store template's original CFrame before cloning
		local templateRoot = coinTemplate:FindFirstChild("HumanoidRootPart") or coinTemplate:FindFirstChild("PrimaryPart") or coinTemplate
		local originalCFrame = templateRoot.CFrame
		
		local coin = coinTemplate:Clone()
		coin.Parent = workspace
		local coinRoot = coin:FindFirstChild("HumanoidRootPart") or coin:FindFirstChild("PrimaryPart") or coin
		
		-- Spawn coin at drop position
		if coinRoot then
			coinRoot.CFrame = CFrame.fromMatrix(dropSpawnPosition, originalCFrame.RightVector, originalCFrame.UpVector)
		end
		
		-- Anchor all coin parts
		local function anchorCoinParts(obj)
			if not obj then return end
			if obj:IsA("BasePart") then
				obj.Anchored = true
			end
			for _, child in ipairs(obj:GetChildren()) do anchorCoinParts(child) end
		end
		-- anchorCoinParts(coin)
		
		-- Apply coin collision group (same as enemies)
		local COIN_GROUP = "Coins"
		local function setCoinCollisionGroup(obj)
			if not obj then return end
			if obj:IsA("BasePart") then 
				obj.CollisionGroup = COIN_GROUP
				-- Don't set CanCollide to false - let collision groups handle it
			end
			for _, child in ipairs(obj:GetChildren()) do setCoinCollisionGroup(child) end
		end
		setCoinCollisionGroup(coin)
		
		-- Store coin value and mark as collectible item
		local coinValueObj = coin:FindFirstChild("Value")
		if not coinValueObj then
			coinValueObj = Instance.new("IntValue")
			coinValueObj.Name = "Value"
			coinValueObj.Parent = coin
		end
		coinValueObj.Value = coinValue
		
		-- Tag coin so collection script knows to process it
		local tag = Instance.new("StringValue")
		tag.Name = "CoinType"
		tag.Value = "EnemyDrop"
		tag.Parent = coin
		
		-- Store owner (player who dealt most damage) and drop time for pickup restriction
		if lastDamagedByPlayer then
			local ownerValue = Instance.new("ObjectValue")
			ownerValue.Name = "DropOwner"
			ownerValue.Value = lastDamagedByPlayer
			ownerValue.Parent = coin
			
			local dropTimeValue = Instance.new("NumberValue")
			dropTimeValue.Name = "DropTime"
			dropTimeValue.Value = tick()
			dropTimeValue.Parent = coin
		end
		
		-- Transparency is handled client-side by ItemTransparencyHandler.client.lua
		-- This allows each player to see different transparency based on ownership
		
		-- Destroy coin after 120 seconds if not collected
		task.delay(120, function()
			if coin and coin.Parent then
				coin:Destroy()
			end
		end)
	end
	
	-- Spawn item drops from enemy stats BEFORE destroying the enemy
	if enemyStats and enemyStats.Drops then
		local success, err = pcall(function()
			local spawnedItems = ItemDropManager.SpawnEnemyDrops(enemyStats, dropSpawnPosition, lastDamagedByPlayer)
		end)
		if not success then
			warn("[EnemiesModule] Failed to spawn item drops: " .. tostring(err))
		end
	end
	
	-- Wait a bit to ensure items are properly spawned before destroying the enemy
	
	-- -- Destroy humanoid and joints
	-- if slime.Humanoid then
	-- 	slime.Humanoid:Disconnect()
	-- end
	slime:BreakJoints()
	SoundModule.playSoundInRange("DiedAudio", root.Position, "SFX", 100, false, 1)
	task.wait(0.5)
	slime:Destroy()
	task.wait(15)
			local template = ServerStorage:WaitForChild("Enemies"):FindFirstChild(enemyName)
			if template then
				local newSlime = template:Clone()
				newSlime.Parent = parent
				local newRoot = newSlime:FindFirstChild("HumanoidRootPart")
				if newRoot and respawnPosition then newRoot.CFrame = CFrame.new(respawnPosition) end
				task.wait(0.1)  -- Wait for model to fully initialize in workspace
				task.spawn(EnemiesManager.Start, newSlime)
			else
				warn("[GloopCrusher] Could not find template '" .. enemyName .. "' in ServerStorage for respawn!")
			end
		end)
	end
	task.spawn(moveTowardsTarget)

end

-- Auto-initialize all enemies in the workspace when module loads
local Workspace = game:GetService("Workspace")
local EnemiesFolder = Workspace:FindFirstChild("Enemies")

local function findAndInitializeEnemies(parent)
	for _, model in ipairs(parent:GetChildren()) do
		-- Only initialize enemies inside workspace.Enemies
		if model:IsDescendantOf(EnemiesFolder) or model == EnemiesFolder then
			local hasHumanoid = model:FindFirstChild("Humanoid") ~= nil
			local hasRootPart = model:FindFirstChild("HumanoidRootPart") ~= nil
			if hasHumanoid and hasRootPart then
				local isPlayer = Players:FindFirstChild(model.Name) and Players:FindFirstChild(model.Name).Character == model
				if not isPlayer then
					local humanoid = model:FindFirstChild("Humanoid")
					if humanoid and humanoid:IsA("Humanoid") then
						task.spawn(function()
							if model and model.Parent and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
								EnemiesManager.Start(model)
							end
						end)
					end
				end
			end
			findAndInitializeEnemies(model)
		end
	end
end

if EnemiesFolder then
	findAndInitializeEnemies(EnemiesFolder)
end

-- Also monitor for new models added to workspace (spawned enemies)
Workspace.DescendantAdded:Connect(function(model)
	-- Only initialize if model is inside workspace.Enemies
	if not EnemiesFolder or not model:IsDescendantOf(EnemiesFolder) then return end
	local hasHumanoid = model:FindFirstChild("Humanoid") ~= nil
	local hasRootPart = model:FindFirstChild("HumanoidRootPart") ~= nil
	if hasHumanoid and hasRootPart then
		local isPlayer = Players:FindFirstChild(model.Name) and Players:FindFirstChild(model.Name).Character == model
		if not isPlayer then
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid and humanoid:IsA("Humanoid") then
				task.wait(0.1)
				task.spawn(function()
					if model and model.Parent and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
						EnemiesManager.Start(model)
					end
				end)
			end
		end
	end
end)

return EnemiesManager
