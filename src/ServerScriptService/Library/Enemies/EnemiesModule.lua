local EnemiesManager = {}
local playerHP = {} -- Shared player HP table for all enemies
local DEFAULT_MAX_HEALTH = 1
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")


-- Load DamageManager for incoming damage calculations
local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))

-- Load ItemDropManager for handling drops
local ItemDropManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("ItemDropManager"))

-- Load QuestDataStore for quest progress tracking
local QuestDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("QuestDataStore"))

-- Load UnifiedDataStoreManager for saving quest progress
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- Load NpcQuestData for quest objectives
local NpcQuestData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("NpcQuestData"))

-- Load PartyDataStore for party tracking
local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))

-- Load LevelSystem for level up checks
local LevelSystem = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("LevelSystem"))
local DungeonsData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("DungeonsData"))

local SoundModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("SoundModule"))

-- Create or get QuestComplete RemoteEvent for notifying client about quest completion
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local questCompleteEvent = ReplicatedStorage:FindFirstChild("QuestComplete")
if not questCompleteEvent then
	questCompleteEvent = Instance.new("RemoteEvent")
	questCompleteEvent.Name = "QuestComplete"
	questCompleteEvent.Parent = ReplicatedStorage
end

-- Helper: Recursively add parts to a collision group
local function addToCollisionGroupRecursive(obj, groupName)
	if not obj then return end
	if obj:IsA("BasePart") then
		pcall(function() 
			obj.CollisionGroup = groupName
		end)
	end
	for _, child in ipairs(obj:GetChildren()) do 
		addToCollisionGroupRecursive(child, groupName) 
	end
end

-- Add all Map folder parts to "Env" collision group once at startup
local function initializeMapCollision()
	local mapFolder = workspace:FindFirstChild("Map")
	if mapFolder then
		addToCollisionGroupRecursive(mapFolder, "Env")
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
-- PlayerAdded handler moved to Init.server.lua for centralized initialization
-- addPlayerToGroup is called from Init.server.lua

-- Make addPlayerToGroup public so Init can call it
EnemiesManager.addPlayerToGroup = addPlayerToGroup

function EnemiesManager.Start(model)
	local slime = model
	-- DEBUG: Print all children and part info for this enemy model
	--print("[EnemyInit] Initializing enemy:", slime.Name)
	local function printChildren(obj, indent)
		indent = indent or ""
		for _, child in ipairs(obj:GetChildren()) do
			local info = indent .. "- " .. child.Name .. " (" .. child.ClassName .. ")"
			if child:IsA("BasePart") then
				info = info .. string.format(" [CanCollide=%s, Anchored=%s, CollisionGroup=%s]", tostring(child.CanCollide), tostring(child.Anchored), child.CollisionGroup)
			end
			--print(info)
			-- printChildren(child, indent .. "  ")
		end
	end
	-- printChildren(slime)
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
	pcall(function() PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", true) end)

	addToCollisionGroupRecursive(slime, COLLISION_GROUP)

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
	local mostDamageDealer = nil -- Track player who dealt the MOST total damage
	local mostDamageAmount = 0 -- Track the highest damage amount
	
	-- Get DamageEvent to notify clients of damage
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
	if not damageEvent then
		damageEvent = Instance.new("RemoteEvent")
		damageEvent.Name = "EnemyDamage"
		damageEvent.Parent = ReplicatedStorage
	end
	
	-- Animation loop for attack and idle
	local function attackAndIdleLoop(enemyModel, currentlyTouching, userId)
		repeat
			-- Play Attack1 for 1 second
			local humanoid = enemyModel:FindFirstChild("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local attackAnim = enemyModel:FindFirstChild("Attack1")
			local upperTorso = enemyModel:FindFirstChild("UpperTorso")
			local slash1 = upperTorso and upperTorso:FindFirstChild("Slash1")
			if animator and attackAnim then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				local track = animator:LoadAnimation(attackAnim)
				track:Play(0, 1, track.Length)
				track:AdjustSpeed(track.Length > 0 and (track.Length / 1) or 1)
				-- Enable Slash1 only while Attack1 is playing
				if slash1 then
					slash1.Enabled = true
					task.delay(track.Length, function()
						slash1.Enabled = false
					end)
				end
			end

			task.wait(1)
			-- Play Idle
			local idleAnim = enemyModel:FindFirstChild("Idle")
			if animator and idleAnim then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				local idleTrack = animator:LoadAnimation(idleAnim)
				idleTrack:Play()
			end
			task.wait(0.1)
		until not currentlyTouching[userId]
	end

	-- Helper: Play animation by name on enemy's Animator (prevents overlap)
	local function playEnemyAnimation(enemyModel, animName, forceLength, stateTable)
		local humanoid = enemyModel:FindFirstChild("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end
		if stateTable and stateTable.lastAnim == animName then return end
		local anim = enemyModel:FindFirstChild(animName)
		if anim and anim:IsA("Animation") then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
			local track = animator:LoadAnimation(anim)
			if animName == "Attack1" and forceLength then
				track:Play(0, 1, track.Length)
				track:AdjustSpeed(track.Length > 0 and (track.Length / forceLength) or 1)
			else
				track:Play()
			end
			if stateTable then stateTable.lastAnim = animName end
		end
	end

	local animState = {lastAnim = nil}
	playEnemyAnimation(slime, "Idle", nil, animState)

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
		billboard.Size = UDim2.new(2, 0, 1, 0)
		-- Adjust Y offset and size for 'giant' or '3 head' enemies
		local yOffset = 5
		local lowerName = string.lower(enemyModel.Name)
		if string.find(lowerName, "giant") then
			yOffset = yOffset + 18
			billboard.Size = UDim2.new(20, 0, 5, 0) -- Make billboard bigger
		elseif string.find(lowerName, "3 head") then
			yOffset = yOffset + 5 -- Lower than giant
			billboard.Size = UDim2.new(20, 0, 5, 0) -- Still big
		end
		billboard.StudsOffset = Vector3.new(0, yOffset, 0)
		billboard.MaxDistance = 100
		billboard.Parent = head

		-- Enemy name label on top (bigger)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = enemyModel.Name
		nameLabel.Parent = billboard
		nameLabel.Name = "EnemyNameLabel"
		
		-- Add UIStroke for text outline
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 2
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Transparency = 0
		textStroke.Parent = nameLabel

		-- Background frame for health bar (below name)
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, 0, 0.6, 0)
		barBg.Position = UDim2.new(0, 0, 0.4, 0)
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

	local currentlyTouching = {} -- Track players currently touching (userId -> character reference)
	local damageLoopRunning = {} -- Track if damage loop already running for a player
	local touchDebounce = {} -- Debounce to prevent multiple parts from triggering simultaneously
	
	-- Function to clean up player tracking when they die or leave
	local function cleanupPlayerTracking(userId)
		-- print(string.format("[Cleanup] Clearing tracking for userId %s", tostring(userId)))
		currentlyTouching[userId] = nil
		damageLoopRunning[userId] = nil
		touchDebounce[userId] = nil
	end
	
	local function applyDamageToPlayer(player, expectedCharacter)
		if not player or not player.Character then 
			cleanupPlayerTracking(player and player.UserId)
			return 
		end
		
		-- Verify it's still the same character that touched the enemy
		if player.Character ~= expectedCharacter then
			cleanupPlayerTracking(player.UserId)
			return
		end
		
		local userId = player.UserId
		local statsFolder = player:FindFirstChild("Stats")
		if not statsFolder then 
			cleanupPlayerTracking(userId)
			return 
		end
		
		local currentHealthValue = statsFolder:FindFirstChild("CurrentHealth")
		local maxHealthValue = statsFolder:FindFirstChild("MaxHealth")
		if not currentHealthValue or not maxHealthValue then 
			cleanupPlayerTracking(userId)
			return 
		end
		
		-- Check if player is already dead or character humanoid is dead
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 or currentHealthValue.Value <= 0 then 
			cleanupPlayerTracking(userId)
			return 
		end
		
		-- Calculate actual damage after player's defense reduction
		local actualDamage = DamageManager.CalculateIncomingDamage(damage, player)
		
		-- print(string.format("[Damage] %s damaged %s for %d HP (Time: %.2f)", slime.Name, player.Name, actualDamage, tick()))
		
		-- Apply damage directly to the DataStore-synced CurrentHealth
		currentHealthValue.Value = math.max(currentHealthValue.Value - actualDamage, 0)
		lastDamagedByPlayer = player -- Track who damaged this enemy
		
		-- Show damage text on client (even if 0 damage, shows "-0") (false = enemy damage, red)
		local character = player.Character
		if character then
			local targetPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if targetPart then
				damageEvent:FireClient(player, targetPart, actualDamage, false, false)
			end
		end

		-- If player died from this hit
		if currentHealthValue.Value <= 0 then
			local character = player.Character
			if character then character:BreakJoints() end
			cleanupPlayerTracking(userId)
		end
	end
	
	-- Setup character cleanup for all players
	local playerCharacterConnections = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not playerCharacterConnections[player.UserId] then
			playerCharacterConnections[player.UserId] = player.CharacterRemoving:Connect(function()
				cleanupPlayerTracking(player.UserId)
			end)
		end
	end
	
	-- Monitor new players
	Players.PlayerAdded:Connect(function(player)
		if not playerCharacterConnections[player.UserId] then
			playerCharacterConnections[player.UserId] = player.CharacterRemoving:Connect(function()
				cleanupPlayerTracking(player.UserId)
			end)
		end
	end)
	
	-- Connect Touched and TouchEnded to all BasePart children of the enemy
	local touchConnections = {}
	local touchEndConnections = {}
	for _, part in ipairs(slime:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(touchConnections, part.Touched:Connect(function(hit)
				local character = hit.Parent
				if character and character:FindFirstChild("Humanoid") then
					local player = Players:GetPlayerFromCharacter(character)
					if player then
						local userId = player.UserId
						local characterHumanoid = character:FindFirstChild("Humanoid")
						
						-- Don't damage if player is already dead
						if not characterHumanoid or characterHumanoid.Health <= 0 then return end
						
					-- Prevent multiple parts from triggering damage - check debounce first
					if touchDebounce[userId] then 
						-- print(string.format("[Touch] BLOCKED by debounce for %s", player.Name))
						return 
					end
					
					-- ATOMIC: Set debounce flag IMMEDIATELY to block other parts
					touchDebounce[userId] = true
					
					-- Double-check after debounce to prevent race conditions
					if currentlyTouching[userId] or damageLoopRunning[userId] then 
						-- print(string.format("[Touch] BLOCKED by tracking flags for %s", player.Name))
						touchDebounce[userId] = nil -- Clear debounce if we exit early
						return 
					end
					
					-- CRITICAL: Set tracking flags IMMEDIATELY to claim this player
					currentlyTouching[userId] = character
					damageLoopRunning[userId] = true
					
					-- print(string.format("[Touch] %s touched %s - Starting damage loops", player.Name, slime.Name))
					
					-- Setup real-time listener for this player's stats if not already done
					if not playerStatConnections[userId] then
						setupPlayerStatListener(player)
					end
						
					-- Start animation loop (runs independently from damage loop)
					task.spawn(function()
						repeat
							-- Play Attack1 for 1 second
							local humanoid = slime:FindFirstChild("Humanoid")
							local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
							local attackAnim = slime:FindFirstChild("Attack1")
							local upperTorso = slime:FindFirstChild("UpperTorso")
							local slash1 = upperTorso and upperTorso:FindFirstChild("Slash1")
							if animator and attackAnim then
								for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
									track:Stop()
								end
								local track = animator:LoadAnimation(attackAnim)
								track:Play(0, 1, track.Length)
								track:AdjustSpeed(track.Length > 0 and (track.Length / 1) or 1)
								-- Enable Slash1 only while Attack1 is playing
								if slash1 then
									slash1.Enabled = true
									task.delay(track.Length, function()
										slash1.Enabled = false
									end)
								end
							end

							task.wait(1)
							-- Play Idle
							local idleAnim = slime:FindFirstChild("Idle")
							if animator and idleAnim then
								for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
									track:Stop()
								end
								local idleTrack = animator:LoadAnimation(idleAnim)
								idleTrack:Play()
							end
							task.wait(0.1)
						until not currentlyTouching[userId]
					end)
					
					-- Start continuous damage loop (applies damage immediately, then every 1 second)
					-- print(string.format("[Loop] Starting continuous damage loop for %s", player.Name))
					task.spawn(function()
						local trackedCharacter = character
						local loopCount = 0
						
						-- Apply first damage immediately
						-- print(string.format("[Loop] First damage application for %s", player.Name))
						applyDamageToPlayer(player, trackedCharacter)
						local lastDamageTime = tick() -- Record time AFTER first damage
						
						while player.Character == trackedCharacter do
							task.wait(1) -- Wait full second
							loopCount = loopCount + 1
							
							-- Check distance to enemy to determine if still in combat
							local playerRoot = trackedCharacter and trackedCharacter:FindFirstChild("HumanoidRootPart")
							local enemyRoot = slime:FindFirstChild("HumanoidRootPart")
							local distanceToEnemy = math.huge
							
							if playerRoot and enemyRoot then
								distanceToEnemy = (playerRoot.Position - enemyRoot.Position).Magnitude
							end
							
							-- Stop loop if player moved far away (> 10 studs)
							if distanceToEnemy > 10 then
								-- print(string.format("[Loop] %s moved away (distance: %.1f studs) - ending loop", player.Name, distanceToEnemy))
								break
							end
							
							local currentTime = tick()
							local timeSinceLastDamage = currentTime - lastDamageTime
							
							-- Apply damage if enough time has passed
							if (currentTime - lastDamageTime) >= 0.95 then
								-- print(string.format("[Loop] Iteration %d - Applying damage to %s (Dist: %.1f)", loopCount, player.Name, distanceToEnemy))
								applyDamageToPlayer(player, trackedCharacter)
								lastDamageTime = currentTime
							end
							
							-- Check if player died
							if not currentlyTouching[userId] then
								-- print(string.format("[Loop] %s died or was cleaned up - ending loop", player.Name))
								break
							end
							end
							
							-- print(string.format("[Loop] Ending damage loop for %s after %d iterations", player.Name, loopCount))
							cleanupPlayerTracking(userId)
					end)
					end
				end
			end))
			table.insert(touchEndConnections, part.TouchEnded:Connect(function(hit)
				-- TouchEnd fires constantly during movement - don't cleanup here
				-- Let the damage loop handle distance checking and cleanup
			end))
		end
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
	local lastRecordedHealth = maxEnemyHealth -- Track previous health for damage calculation (MUST be before Changed event)
	
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
		
		-- Track damage dealt by players (only when health decreases)
		if newHealth < lastRecordedHealth then
			-- Find which player dealt the most damage to this enemy
			local maxPlayerDamage = 0
			local maxPlayerUserId = nil
			
			-- Check all player damage attributes on this enemy
			local attributes = slime:GetAttributes()
			for attrName, damageAmount in pairs(attributes) do
				if string.find(attrName, "^PlayerDamageTracker_") then
					local userId = tonumber(string.match(attrName, "PlayerDamageTracker_(.+)$"))
					
					if userId and damageAmount and damageAmount > maxPlayerDamage then
						maxPlayerDamage = damageAmount
						maxPlayerUserId = userId
					end
				end
			end
			
			-- Update most damage dealer if we found one
			if maxPlayerUserId then
				local player = Players:GetPlayerByUserId(maxPlayerUserId)
				if player then
					if maxPlayerDamage > mostDamageAmount then
						mostDamageAmount = maxPlayerDamage
						mostDamageDealer = player
						--print("[EnemiesModule] 💥 Most damage dealer updated:", player.Name, "with", maxPlayerDamage, "total damage")
					end
					
					-- Track for experience distribution
					playerDamage[maxPlayerUserId] = maxPlayerDamage
				end
			end
		end
		lastRecordedHealth = newHealth
		
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
	
	-- Cache raycast params to avoid recreation every frame
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {slime}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local rayDirection = Vector3.new(0, -3.5, 0)
	
	local function isGrounded()
		if not root then return false end
		local result = workspace:Raycast(root.Position, rayDirection, raycastParams)
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
					local rootPos = root.Position
					local targetPos = targetRoot.Position
					targetDirection = (targetPos - rootPos).unit
					distanceToPlayer = (targetPos - rootPos).Magnitude
					desiredFacingCFrame = CFrame.new(rootPos, Vector3.new(targetPos.X, rootPos.Y, targetPos.Z))
				end
			elseif defaultPosition then
				local direction = (defaultPosition - root.Position)
				if direction.Magnitude > 1 then
					targetDirection = direction.unit
					desiredFacingCFrame = CFrame.new(root.Position, defaultPosition)
				end
			end
			
			-- Smooth rotation
			if desiredFacingCFrame then
				root.CFrame = root.CFrame:Lerp(desiredFacingCFrame, 0.1)
			end
			
			-- Move towards target (walk, no jumping)
			if targetDirection.Magnitude > 0 then
				local currentVel = root.Velocity
				-- Keep current Y velocity (gravity), add horizontal movement
				root.Velocity = Vector3.new(targetDirection.X * 20, currentVel.Y, targetDirection.Z * 20)
				playEnemyAnimation(slime, "Walk", nil, animState)
			else
				-- No target, apply friction
				local currentVel = root.Velocity
				root.Velocity = Vector3.new(currentVel.X * 0.95, currentVel.Y, currentVel.Z * 0.95)
				playEnemyAnimation(slime, "Idle", nil, animState)
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
			-- Ensure DeadEnemies cannot collide with Players
			pcall(function() PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "Players", false) end)
			PhysicsService:CollisionGroupSetCollidable("DeadEnemies", "DeadEnemies", true)

			-- Add all slime parts to DeadEnemies group immediately
			addToCollisionGroupRecursive(slime, "DeadEnemies")

			-- Disconnect all damage connections so dead slime doesn't hurt players
			for _, conn in ipairs(touchConnections) do
				if conn then conn:Disconnect() end
			end
			for _, conn in ipairs(touchEndConnections) do
				if conn then conn:Disconnect() end
			end
			if touchConnection then touchConnection:Disconnect() end

			-- Stop all damage loops for players
			for userId, _ in pairs(currentlyTouching) do
				currentlyTouching[userId] = nil
			end
			for userId, _ in pairs(damageLoopRunning) do
				damageLoopRunning[userId] = nil
			end

			-- Cleanup all player stat listeners
			for userId, connection in pairs(playerStatConnections) do
				if connection then connection:Disconnect() end
			end
			table.clear(playerStatConnections)
			
			-- Cleanup all player character removal listeners
			for userId, connection in pairs(playerCharacterConnections) do
				if connection then connection:Disconnect() end
			end
			table.clear(playerCharacterConnections)

			respawnPosition = defaultPosition  -- Save the spawn position for respawn

			-- ====== DESTROY ENEMY AND SCHEDULE RESPAWN FIRST ======
			slime:BreakJoints()
			SoundModule.playSoundInRange("DiedAudio", root.Position, "SFX", 100, false, 1)
			task.wait(0.5)
			slime:Destroy()

			-- Schedule respawn asynchronously so other death logic can run
			task.spawn(function()
				local spawnDelay = (enemyStats and enemyStats.SpawnDelay) or 15
				task.wait(spawnDelay)
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
		
		-- Get enemy experience reward
		local enemyExperience = enemyStats and enemyStats.Experience or 0
		
		-- Calculate total damage dealt by all players
		local totalDamage = 0
		for userId, damage in pairs(playerDamage) do
			totalDamage = totalDamage + damage
		end
		
		-- Debug: Log experience distribution and damage breakdown
		-- Debug logging
		if #playerDamage > 0 then
			--print("[EnemiesModule] ====== ENEMY DIED ======")
			--print("[EnemiesModule] Enemy:", enemyName, "| XP:", enemyExperience, "| Total Damage:", totalDamage)
			--print("[EnemiesModule] Most damage dealer:", mostDamageDealer and mostDamageDealer.Name or "NONE", "with", mostDamageAmount, "damage")
			--print("[EnemiesModule] ====== END ======")
		end
		
		-- Distribute experience to all players who dealt damage, proportional to their damage
		if enemyExperience > 0 then
			if totalDamage > 0 then
				-- Get PartyDataStore for party-based experience sharing
				local PartyDataStore = require(script.Parent.Parent:WaitForChild("Party"):WaitForChild("PartyDataStore"))
				
				-- Build a map of players by party to handle party-based experience division
				local playersByParty = {} -- partyId -> {players with damage}
				local partyMembers = {} -- partyId -> {all members including those without damage}
				local soloPlayers = {} -- players not in a party
				
				-- First pass: collect all players who dealt damage and categorize them
				for userId, damageDealt in pairs(playerDamage) do
					local player = Players:GetPlayerByUserId(userId)
					if player then
						local partyId = PartyDataStore.GetPartyId(player.UserId)
						if partyId then
							-- Player is in a party
							if not playersByParty[partyId] then
								playersByParty[partyId] = {}
							end
							table.insert(playersByParty[partyId], {player = player, damage = damageDealt})
						else
							-- Player is solo
							table.insert(soloPlayers, {player = player, damage = damageDealt})
						end
					end
				end
				
				-- Second pass: get ALL members of parties that had damage, not just those who dealt damage
				for partyId, _ in pairs(playersByParty) do
					local party = PartyDataStore.GetParty(nil) -- This won't work, need different approach
					-- Get any player from this party to fetch the full party
					for _, entry in ipairs(playersByParty[partyId]) do
						local party = PartyDataStore.GetParty(entry.player.UserId)
						if party then
							partyMembers[partyId] = party.members
							break
						end
					end
				end
				
				   -- Distribute experience and gold to solo players (proportional, with dungeon multipliers)
				   for _, entry in ipairs(soloPlayers) do
					   local player = entry.player
					   local damageDealt = entry.damage
					   if player then
						   local stats = player:FindFirstChild("Stats")
						   if stats then
							   -- Calculate solo player's share based on damage percentage
							   local damagePercentage = damageDealt / totalDamage
							   -- Get dungeon multipliers if in a dungeon
							   local playerMap = stats:FindFirstChild("PlayerMap")
							   local mapName = playerMap and playerMap.Value
							   local xpMultiplier, goldMultiplier = 1, 1
							   if mapName and DungeonsData[mapName] then
								   xpMultiplier = DungeonsData[mapName].ExpMultiplier or 1
								   goldMultiplier = DungeonsData[mapName].GoldMultiplier or 1
							   end
							   local playerExperience = math.floor((enemyExperience * damagePercentage) * xpMultiplier)
							   local xpToAward = math.max(playerExperience, 1)
							   local playerGold = math.floor((coinValue * damagePercentage) * goldMultiplier)
							   local goldToAward = math.max(playerGold, 0)
							   local experienceValue = stats:FindFirstChild("Experience")
							   if experienceValue then
								   experienceValue.Value = experienceValue.Value + xpToAward
								   --print("[EnemiesModule] Awarded", xpToAward, "XP to SOLO player", player.Name, "(multiplier:", xpMultiplier, ")")
								   LevelSystem.checkLevelUp(player)
								   --print("[EnemiesModule] 🆙 Level-up check triggered for", player.Name)
							   end
							   -- Award gold (Money stat)
							   if goldToAward > 0 then
								   local moneyValue = stats:FindFirstChild("Money")
								   if moneyValue then
									   moneyValue.Value = moneyValue.Value + goldToAward
									   --print("[EnemiesModule] Awarded", goldToAward, "Gold to SOLO player", player.Name, "(multiplier:", goldMultiplier, ")")
								   end
							   end
						   end
					   end
				   end
				
				   -- Distribute experience and gold to party members (divide equally, with dungeon multipliers)
				   for partyId, partyDamages in pairs(playersByParty) do
					   -- Calculate total damage for this party
					   local partyTotalDamage = 0
					   for _, entry in ipairs(partyDamages) do
						   partyTotalDamage = partyTotalDamage + entry.damage
					   end
					   -- Calculate this party's share of total experience/gold (based on party's total damage)
					   local partyDamagePercentage = partyTotalDamage / totalDamage
					   -- Use the first online member's map for multiplier (assume all in same map)
					   local firstOnlineMember = nil
					   local allPartyMembers = partyMembers[partyId] or {}
					   for _, member in ipairs(allPartyMembers) do
						   if member and member.Parent then
							   firstOnlineMember = member
							   break
						   end
					   end
					   local xpMultiplier, goldMultiplier = 1, 1
					   if firstOnlineMember then
						   local stats = firstOnlineMember:FindFirstChild("Stats")
						   local playerMap = stats and stats:FindFirstChild("PlayerMap")
						   local mapName = playerMap and playerMap.Value
						   if mapName and DungeonsData[mapName] then
							   xpMultiplier = DungeonsData[mapName].ExpMultiplier or 1
							   goldMultiplier = DungeonsData[mapName].GoldMultiplier or 1
						   end
					   end
					   local partyTotalExperience = math.floor((enemyExperience * partyDamagePercentage) * xpMultiplier)
					   local partyTotalGold = math.floor((coinValue * partyDamagePercentage) * goldMultiplier)
					   -- Count online members (members whose characters exist)
					   local onlineMemberCount = 0
					   for _, member in ipairs(allPartyMembers) do
						   if member and member.Parent then
							   onlineMemberCount = onlineMemberCount + 1
						   end
					   end
					   if onlineMemberCount == 0 then
						   onlineMemberCount = #partyDamages
					   end
					   -- Divide equally among ALL online party members (including those who didn't deal damage)
					   local experiencePerMember = math.floor(partyTotalExperience / onlineMemberCount)
					   local xpPerMember = math.max(experiencePerMember, 1)
					   local goldPerMember = math.floor(partyTotalGold / onlineMemberCount)
					   local goldPerMemberFinal = math.max(goldPerMember, 0)
					   --print("[EnemiesModule] 👥 Party", partyId, "gets", partyTotalExperience, "XP total, divided equally =", xpPerMember, "each to", onlineMemberCount, "online members (multiplier:", xpMultiplier, ")")
					   --print("[EnemiesModule] 👥 Party", partyId, "gets", partyTotalGold, "Gold total, divided equally =", goldPerMemberFinal, "each to", onlineMemberCount, "online members (multiplier:", goldMultiplier, ")")
					   -- Award experience and gold to ALL online party members
					   for _, member in ipairs(allPartyMembers) do
						   if member and member.Parent then
							   local stats = member:FindFirstChild("Stats")
							   if stats then
								   local experienceValue = stats:FindFirstChild("Experience")
								   if experienceValue then
									   experienceValue.Value = experienceValue.Value + xpPerMember
									   -- Check if member dealt damage
									   local dealtDamage = false
									   for _, entry in ipairs(partyDamages) do
										   if entry.player == member then
											   dealtDamage = true
											   break
										   end
									   end
									   local damageNote = dealtDamage and "(dealt damage)" or "(no damage - party support)"
									   --print("[EnemiesModule] Awarded", xpPerMember, "XP to PARTY member", member.Name, damageNote, "(party:", partyId .. ")")
									   LevelSystem.checkLevelUp(member)
									   --print("[EnemiesModule] 🆙 Level-up check triggered for", member.Name)
								   end
								   -- Award gold (Money stat)
								   if goldPerMemberFinal > 0 then
									   local moneyValue = stats:FindFirstChild("Money")
									   if moneyValue then
										   moneyValue.Value = moneyValue.Value + goldPerMemberFinal
										   --print("[EnemiesModule] Awarded", goldPerMemberFinal, "Gold to PARTY member", member.Name, "(party:", partyId .. ")")
									   end
								   end
							   end
						   end
					   end
				   end
			else
				-- No damage tracked - don't award XP to anyone
				--print("[EnemiesModule] WARNING: No damage tracked for", enemyName, "! No XP awarded.")
			end
		end
		
		-- ====== SPAWN ITEM DROPS FIRST ======
		-- Determine spawn position for drops
		local dropSpawnPosition = root.Position + Vector3.new(0, -2, 0)
		if mostDamageDealer and mostDamageDealer.Character then
			local playerRoot = mostDamageDealer.Character:FindFirstChild("HumanoidRootPart")
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
			
			-- Apply coin collision group (same as enemies)
			local COIN_GROUP = "Coins"
			addToCollisionGroupRecursive(coin, COIN_GROUP)
			
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
			if mostDamageDealer then
				local ownerValue = Instance.new("ObjectValue")
				ownerValue.Name = "DropOwner"
				ownerValue.Value = mostDamageDealer
				ownerValue.Parent = coin
				
				local dropTimeValue = Instance.new("NumberValue")
				dropTimeValue.Name = "DropTime"
				dropTimeValue.Value = tick()
				dropTimeValue.Parent = coin
				
				local pickupRestrictionValue = Instance.new("NumberValue")
				pickupRestrictionValue.Name = "PickupRestrictionDuration"
				pickupRestrictionValue.Value = 10 -- 10 second exclusive ownership window
				pickupRestrictionValue.Parent = coin
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
				local spawnedItems = ItemDropManager.SpawnEnemyDrops(enemyStats, dropSpawnPosition, mostDamageDealer)
			end)
			if not success then
				warn("[EnemiesModule] Failed to spawn item drops: " .. tostring(err))
			end
		end
		
		-- ====== QUEST PROGRESS TRACKING (ASYNC) ======
		-- Move quest progress checking to async task to prevent freezing
		if totalDamage > 0 then
			task.spawn(function()
				for userId, damageDealt in pairs(playerDamage) do
					local player = Players:GetPlayerByUserId(userId)
					if player and player.Parent then
						-- Get the enemy type/name to find matching quests
						-- Normalize enemy name by removing trailing numbers (e.g., "Giant Gloop Crusher1" -> "Giant Gloop Crusher")
						local enemyType = slime.Name
						enemyType = string.gsub(enemyType, "%d+$", "") -- Remove trailing digits
						enemyType = string.gsub(enemyType, "%s+$", "") -- Remove trailing spaces
						--print("[EnemiesModule] 🎯 Original name:", slime.Name, "| Normalized:", enemyType)
						local matchingQuests = QuestDataStore.GetQuestsByEnemyType(enemyType)
						
						if #matchingQuests > 0 then
							-- Collect all players to update: the damager + their party members
							local playersToUpdate = {player}
							
							-- Get player's party to share quest progress
							local party = PartyDataStore.GetParty(player.UserId)
							if party then
								for _, memberPlayer in ipairs(party.members) do
									if memberPlayer and memberPlayer.Parent and memberPlayer ~= player then
										table.insert(playersToUpdate, memberPlayer)
										--print("[EnemiesModule] 👥 Added party member", memberPlayer.Name, "to quest progress update")
									end
								end
							end
							
							-- Update quest progress for all players (damager + party members)
							for _, targetPlayer in ipairs(playersToUpdate) do
								if targetPlayer and targetPlayer.Parent then
									local questsFolder = targetPlayer:FindFirstChild("Quests")
									if questsFolder then
										for _, questId in ipairs(matchingQuests) do
											local questFolder = questsFolder:FindFirstChild("Quest_" .. questId)
											if questFolder then
												-- Check if quest is accepted
												local statusValue = questFolder:FindFirstChild("status")
												if statusValue and statusValue.Value == "accepted" then
													-- Use the new function that tracks progress by enemy type for multi-objective quests
													QuestDataStore.UpdateQuestProgressByEnemyType(targetPlayer, questId, enemyType, 1)
												--print("[EnemiesModule] 📊 Quest", questId, "progress updated for", targetPlayer.Name, "| Enemy:", enemyType)
													local questData = NpcQuestData.GetQuest(questId)
													if questData and questData.objectives then
														local allObjectivesComplete = true
														
														-- Check each objective to see if ALL are at their targets
														for objectiveIdx, objective in ipairs(questData.objectives) do
															local progressValueName = "ObjectiveProgress_" .. objectiveIdx
															local objProgressValue = questFolder:FindFirstChild(progressValueName)
															local currentProgress = objProgressValue and objProgressValue.Value or 0
															
															--print("[EnemiesModule] 🔍 Quest", questId, "Objective", objectiveIdx, "(", objective.enemyType, "): ", currentProgress, "/", objective.target)
															
															-- Check if this objective is not yet complete
															if currentProgress < objective.target then
																allObjectivesComplete = false
																break
															end
														end
														
														-- If all objectives complete, mark quest as completed
														if allObjectivesComplete then
															statusValue.Value = "completed"
													--print("[EnemiesModule] ✅ Quest", questId, "FULLY COMPLETED for", targetPlayer.Name, "!")
															local questData = NpcQuestData.GetQuest(questId)
															if questData and questData.rewards then
																-- Award experience
																if questData.rewards.experience and questData.rewards.experience > 0 then
																	local stats = targetPlayer:FindFirstChild("Stats")
																	if stats then
																		local experienceValue = stats:FindFirstChild("Experience")
																		if experienceValue then
																			experienceValue.Value = experienceValue.Value + questData.rewards.experience
																			--print("[EnemiesModule] 🎉 Awarded", questData.rewards.experience, "XP for quest completion to", targetPlayer.Name)
																			
																			-- CRITICAL: Check for level-up after adding quest experience
																			LevelSystem.checkLevelUp(targetPlayer)
																			--print("[EnemiesModule] 🆙 Level-up check triggered for", targetPlayer.Name)
																		end
																	end
																end
																
																-- Award gold/coins (use "Money" stat, not "Coins")
																if questData.rewards.gold and questData.rewards.gold > 0 then
																	local stats = targetPlayer:FindFirstChild("Stats")
																	if stats then
																		local moneyValue = stats:FindFirstChild("Money")
																		if moneyValue then
																			moneyValue.Value = moneyValue.Value + questData.rewards.gold
																			--print("[EnemiesModule] 🎉 Awarded", questData.rewards.gold, "Gold for quest completion to", targetPlayer.Name)
																		end
																	end
																end
																
																-- Notify client about quest completion with rewards
																questCompleteEvent:FireClient(targetPlayer, questData.questName, questData.rewards.experience, questData.rewards.gold)
																local SFXEvent = game:GetService("ReplicatedStorage"):FindFirstChild("SFXEvent")
																if SFXEvent then
																	SFXEvent:FireClient(targetPlayer, "LevelUp")
																end
																--print("[EnemiesModule] 📤 Sent quest completion notification to", targetPlayer.Name)
															end
														else
															--print("[EnemiesModule] ⏳ Quest", questId, "NOT complete yet - waiting for all objectives")
														end
														
														-- Save quest progress to DataStore (async, no force immediate)
														UnifiedDataStoreManager.SaveQuestData(targetPlayer, false)
														--print("[EnemiesModule] 💾 Quest progress saved for", targetPlayer.Name)
														
														-- Save player experience to DataStore (async, no force immediate)
														UnifiedDataStoreManager.SaveLevelData(targetPlayer, false)
														--print("[EnemiesModule] 💾 Player experience saved to DataStore for", targetPlayer.Name)
														
														-- Save player money to DataStore (async, no force immediate)
														UnifiedDataStoreManager.SaveMoney(targetPlayer, false)
														--print("[EnemiesModule] 💾 Player money saved to DataStore for", targetPlayer.Name)
													else
														--print("[EnemiesModule] ⚠️ Quest", questId, "has no objectives data!")
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end)
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
			if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
				local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
				if not isPlayer then
					task.spawn(EnemiesManager.Start, model)
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
	if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
		local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
		if not isPlayer then
			task.wait(0.1)
			task.spawn(EnemiesManager.Start, model)
		end
	end
end)

-- Failsafe: Heartbeat cleanup for stuck dead enemies
game:GetService("RunService").Heartbeat:Connect(function()
	local Workspace = game:GetService("Workspace")
	local EnemiesFolder = Workspace:FindFirstChild("Enemies")
	if not EnemiesFolder then return end
	for _, model in ipairs(EnemiesFolder:GetDescendants()) do
		if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
			local humanoid = model:FindFirstChild("Humanoid")
			local health = humanoid and humanoid.Health or 0
			if health <= 0 and model.Parent then
				-- Failsafe: forcibly disconnect all connections and destroy the model
				-- Remove all Touched/TouchEnded connections by cloning and replacing parts
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						local clone = part:Clone()
						clone.Parent = part.Parent
						part:Destroy()
					end
				end
				-- Destroy the model after a short delay to allow part cleanup
				task.delay(0.2, function()
					if model and model.Parent then
						model:Destroy()
					end
				end)
			end
		end
	end
end)

return EnemiesManager
