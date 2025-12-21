local EnemiesManager = {}
local playerHP = {} -- Shared player HP table for all enemies
local DEFAULT_MAX_HEALTH = 1
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

-- Initialize collision groups once
pcall(function() PhysicsService:RegisterCollisionGroup("Env") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Coins") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)

-- Setup collision relationships for Coins (like Enemies)
PhysicsService:CollisionGroupSetCollidable("Coins", "Coins", true)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Enemies", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Players", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Coins", "Env", true) end)

-- Verify collision setup
task.wait(0.1)
local success, canCollide = pcall(function()
	return PhysicsService:CollisionGroupsAreCollidable("Coins", "Players")
end)
if success then
	print("[GloopCrusher] Coins-Players collision: " .. tostring(canCollide))
else
	warn("[GloopCrusher] Could not verify Coins-Players collision relationship")
end

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
			pcall(function() PhysicsService:CollisionGroupAddMember("Players", obj) end)
		end
		for _, child in ipairs(obj:GetChildren()) do addCharacterPartsToGroup(child) end
	end
	addCharacterPartsToGroup(character)
	
	-- Also monitor for new parts added to character (accessories, etc)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			task.wait(0.05) -- Small delay to ensure part is ready
			pcall(function() PhysicsService:CollisionGroupAddMember("Players", descendant) end)
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
	if not slime then warn("[GloopCrusher] Model not found!"); return end

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
	if not humanoid then warn("[GloopCrusher] Humanoid not found in model!") end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = slime:FindFirstChild("HumanoidRootPart")
	local defaultPosition = root and root.Position or nil
	if not root then warn("[GloopCrusher] HumanoidRootPart not found in model!") end

	-- Load all enemy stats from datastore based on enemy name
	local enemyStatsDataStore = require(script.Parent:FindFirstChild("EnemyStatsDataStore"))
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
	
	-- Create enemy health bar BillboardGui
	local function createEnemyHealthBar(enemyModel, maxHealth)
		if not head or not head.Parent then return end
		
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 0.5, 0)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
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
		if success and data and type(data["Health"]) == "number" and data["Health"] > 0 then
			updateStatsFolderFromData(player, data)
			return data["Health"]
		else
			warn("[GloopCrusher] Could not load valid max health for player " .. player.Name .. ": " .. tostring(err))
			pcall(function()
				statsStore:UpdateAsync(key, function(old)
					old = old or {}; old["Health"] = DEFAULT_MAX_HEALTH; return old
				end)
			end)
			updateStatsFolderFromData(player, {Health = DEFAULT_MAX_HEALTH})
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
					if touchDebounce[userId] then return end
					touchDebounce[userId] = true
					task.delay(1, function() touchDebounce[userId] = nil end)
					if not hitCooldowns[userId] or tick() - hitCooldowns[userId] > cooldown then
						local maxHealth = getPlayerMaxHealth(player)
						if not maxHealth then warn("[GloopCrusher] Max health not available for player " .. player.Name .. ", skipping damage."); return end
						if not playerHP[userId] then playerHP[userId] = maxHealth end
						if playerHP[userId] <= 0 then return end
						playerHP[userId] = math.max(playerHP[userId] - damage, 0)
						lastDamagedByPlayer = player -- Track who damaged this enemy
						local statsFolder = player:FindFirstChild("Stats")
						if statsFolder then
							local healthValue = statsFolder:FindFirstChild("Health")
							if healthValue and typeof(healthValue.Value) == "number" then healthValue.Value = playerHP[userId] end
						end
						hitCooldowns[userId] = tick()
						
						if playerHP[userId] <= 0 then
							if character then character:BreakJoints() end
							local refreshedMax = getPlayerMaxHealth(player)
							if refreshedMax then
								task.wait(5)
								playerHP[userId] = refreshedMax
								if statsFolder then
									local healthValue = statsFolder:FindFirstChild("Health")
									if healthValue and typeof(healthValue.Value) == "number" then healthValue.Value = refreshedMax end
								end
							else
								playerHP[userId] = nil
							end
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
			-- Disconnect the damage connection so dead slime doesn't hurt players
			if touchConnection then
				touchConnection:Disconnect()
			end
			
local parent, enemyName, respawnPosition = slime.Parent, slime.Name, defaultPosition
		
		-- Get enemy experience reward
		local enemyExperience = enemyStats and enemyStats.Experience or 0
		
		-- Award experience to the player who dealt damage to this enemy
		if lastDamagedByPlayer and enemyExperience > 0 then
			local player = lastDamagedByPlayer
			local stats = player:FindFirstChild("Stats")
			if stats then
				local experienceValue = stats:FindFirstChild("Experience")
				if experienceValue then
					experienceValue.Value = experienceValue.Value + enemyExperience
					
					-- Update datastore directly
					local key = "Player_" .. player.UserId
					pcall(function()
						statsStore:UpdateAsync(key, function(data)
							data = data or {}
							data["Experience"] = (data["Experience"] or 0) + enemyExperience
							return data
						end)
					end)
					
					print("[EnemiesManager] " .. player.Name .. " gained " .. enemyExperience .. " experience")
				end
			end
		else
			print("[EnemiesManager] No player dealt damage to " .. slime.Name .. " or no experience to award")
		end
		
			local ServerStorage = game:GetService("ServerStorage")
			local coinTemplate = ServerStorage:FindFirstChild("Coin")
			
			if coinTemplate then
				local coin = coinTemplate:Clone()
				coin.Parent = workspace
				local coinRoot = coin:FindFirstChild("HumanoidRootPart") or coin:FindFirstChild("PrimaryPart") or coin
				if coinRoot and root then
					coinRoot.CFrame = CFrame.new(root.Position + Vector3.new(0, -1, 0))
				end
				
				-- Anchor all coin parts
				local function anchorCoinParts(obj)
					if not obj then return end
					if obj:IsA("BasePart") then
						obj.Anchored = true
					end
					for _, child in ipairs(obj:GetChildren()) do anchorCoinParts(child) end
				end
				anchorCoinParts(coin)
				
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
				
				-- Destroy coin after 30 seconds if not collected
				task.delay(30, function()
					if coin and coin.Parent then
						coin:Destroy()
					end
				end)
			end
			
			-- Enable collision on all parts before breaking joints
			local function enableCollisionRecursive(obj)
				if not obj then return end
				if obj:IsA("BasePart") then obj.CanCollide = true end
				for _, child in ipairs(obj:GetChildren()) do enableCollisionRecursive(child) end
			end
			enableCollisionRecursive(slime)
			
			-- Set up collision group to prevent player collision
			pcall(function() PhysicsService:RegisterCollisionGroup("DeadEnemies") end)
			PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "DeadEnemies", true)
			pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "Players", false) end)
			
			-- Add all slime parts to DeadEnemies group
			local function addToDeadEnemiesGroup(obj)
				if not obj then return end
				if obj:IsA("BasePart") then 
					pcall(function() PhysicsService:CollisionGroupAddMember("DeadEnemies", obj) end)
				end
				for _, child in ipairs(obj:GetChildren()) do addToDeadEnemiesGroup(child) end
			end
			addToDeadEnemiesGroup(slime)
			
			slime:BreakJoints()
			task.wait(2)
			slime:Destroy()
			task.wait(15)
			local template = ServerStorage:FindFirstChild(enemyName)
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

return EnemiesManager
