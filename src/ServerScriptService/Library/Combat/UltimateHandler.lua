-- UltimateHandler.lua
-- Server-side handler for Ultimate abilities

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
local EnemyStatsDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("EnemyStatsDataStore"))
local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))
local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonsData"))
local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundModule"))
local DuelHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("DuelHandler"))


local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local Players = game:GetService("Players")
local ultimateSkillRemote = ReplicatedStorage:WaitForChild("UltimateSkill")

local UltimateHandler = {}

local ULTIMATE_CHARGE_READY = 100 -- Indicator value for ultimate availability
local playerUltimateCharge = {}

function UltimateHandler.AddUltimateCharge(player, amount)
    if not player or not player.UserId then return end
    -- Always sync from Stats before adding
    local stats = player:FindFirstChild("Stats")
    if stats then
        local ultimateStat = stats:FindFirstChild("UltimateCharge")
        if ultimateStat then
            playerUltimateCharge[player.UserId] = ultimateStat.Value
        end
    end
    local prev = playerUltimateCharge[player.UserId] or 0
    playerUltimateCharge[player.UserId] = prev + (amount or 1)
    if playerUltimateCharge[player.UserId] > ULTIMATE_CHARGE_READY then
        playerUltimateCharge[player.UserId] = ULTIMATE_CHARGE_READY
    end
    local newVal = playerUltimateCharge[player.UserId]
    -- Update Stats folder for persistence
    if stats then
        local ultimateStat = stats:FindFirstChild("UltimateCharge")
        if ultimateStat then
            ultimateStat.Value = newVal
        end
    end
    --print("[UltimateHandler] Player " .. player.Name .. " ultimate charge: " .. tostring(newVal) .. "/" .. tostring(ULTIMATE_CHARGE_READY))
    if prev < ULTIMATE_CHARGE_READY and newVal >= ULTIMATE_CHARGE_READY then
        --print("[UltimateHandler] Player " .. player.Name .. " ULTIMATE READY!")
    end
end

-- Save ultimate charge to DataStore on leave
local function saveUltimateCharge(player)
	local stats = player:FindFirstChild("Stats")
	if stats then
		local ultimateStat = stats:FindFirstChild("UltimateCharge")
		if ultimateStat then
			--print("[UltimateHandler] Saving ultimate charge for " .. player.Name .. ": " .. tostring(ultimateStat.Value))
			UnifiedDataStoreManager.SaveStats(player, true)
		end
	end
end

Players.PlayerRemoving:Connect(saveUltimateCharge)

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

-- Check if map allows PVP
local function isPVPAllowed(mapName)
	if mapName == "PVP Area" then return true end
	local data = DungeonsData[mapName]
	return data and data.AllowPVP == true
end

-- Deal damage to all enemies and players in radius
local function dealUltimateDamage(player, centerPos, radius)
	local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
	if not damageEvent then
		damageEvent = Instance.new("RemoteEvent")
		damageEvent.Name = "EnemyDamage"
		damageEvent.Parent = ReplicatedStorage
	end
	
	-- Get ultimate damage for PRIMARY weapon (use weapon damage calculation)
	local stats = player:FindFirstChild("Stats")
	local equippedFolder = stats and stats:FindFirstChild("Equipped")
	local weaponName = equippedFolder and equippedFolder:FindFirstChild("name")
	local weaponNameStr = weaponName and weaponName.Value or "DefaultWeapon"
	
	local primaryUltimateDamage, primaryIsCritical = DamageManager.calculateDamage(player, weaponNameStr)
	primaryUltimateDamage = primaryUltimateDamage * 3 -- Ultimate does 3x weapon damage
	
	--print("[UltimateHandler] PRIMARY weapon ultimate damage: " .. primaryUltimateDamage .. " (weapon: " .. weaponNameStr .. ")")
	
	-- Check if player has SECONDARY weapon equipped
	local secondaryUltimateDamage = 0
	local secondaryIsCritical = false
	local hasSecondary = false
	
	if stats then
		local secondaryEquipped = stats:FindFirstChild("SecondaryEquipped")
		if secondaryEquipped and secondaryEquipped:IsA("Folder") then
			local secondaryName = secondaryEquipped:FindFirstChild("name")
			if secondaryName and secondaryName.Value ~= "" then
				hasSecondary = true
				secondaryUltimateDamage, secondaryIsCritical = DamageManager.calculateDamage(player, secondaryName.Value)
				secondaryUltimateDamage = secondaryUltimateDamage * 3 -- Ultimate does 3x weapon damage
				--print("[UltimateHandler] SECONDARY weapon ultimate damage: " .. secondaryUltimateDamage .. " (weapon: " .. secondaryName.Value .. ")")
			end
		end
	end
	
	local totalUltimateDamage = primaryUltimateDamage + secondaryUltimateDamage
	--print("[UltimateHandler] TOTAL ultimate damage: " .. totalUltimateDamage .. " (Primary: " .. primaryUltimateDamage .. " + Secondary: " .. secondaryUltimateDamage .. ")")
	
	--print("[UltimateHandler] Dealing ultimate damage in " .. radius .. " radius")
	
	-- Damage enemies in radius (similar to WeaponManager but using distance check)
	for _, descendant in pairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:FindFirstChild("Humanoid") then
			-- Skip players
			if Players:GetPlayerFromCharacter(descendant) then
				continue
			end
			
			-- Skip NPCs
			if descendant:GetAttribute("IsNPC") then
				continue
			end
			
			-- Check distance
			local enemyRoot = descendant:FindFirstChild("HumanoidRootPart") or descendant.PrimaryPart
			if enemyRoot and (enemyRoot.Position - centerPos).Magnitude <= radius then
				local enemyName = descendant.Name
				local enemyStats = EnemyStatsDataStore.loadEnemyStats(enemyName)
				local enemyHealth = getOrCreateEnemyHealth(descendant, enemyStats)
				
				if enemyHealth and enemyHealth:IsA("IntValue") then
					local oldHealth = enemyHealth.Value
					
					-- Apply PRIMARY weapon damage
					enemyHealth.Value = math.max(0, enemyHealth.Value - primaryUltimateDamage)
					local currentDamage = descendant:GetAttribute("PlayerDamageTracker_" .. player.UserId) or 0
					descendant:SetAttribute("PlayerDamageTracker_" .. player.UserId, currentDamage + primaryUltimateDamage)
					damageEvent:FireAllClients(descendant, primaryUltimateDamage, primaryIsCritical, true)
					--print("[UltimateHandler] Hit enemy '" .. enemyName .. "' with PRIMARY for " .. primaryUltimateDamage .. " damage | Health: " .. tostring(enemyHealth.Value) .. "/" .. tostring(oldHealth))
					
					-- Apply SECONDARY weapon damage if equipped
					if hasSecondary and enemyHealth.Value > 0 then
						local oldHealthAfterPrimary = enemyHealth.Value
						enemyHealth.Value = math.max(0, enemyHealth.Value - secondaryUltimateDamage)
						local currentDamage2 = descendant:GetAttribute("PlayerDamageTracker_" .. player.UserId) or 0
						descendant:SetAttribute("PlayerDamageTracker_" .. player.UserId, currentDamage2 + secondaryUltimateDamage)
						damageEvent:FireAllClients(descendant, secondaryUltimateDamage, secondaryIsCritical, true)
						--print("[UltimateHandler] Hit enemy '" .. enemyName .. "' with SECONDARY for " .. secondaryUltimateDamage .. " damage | Health: " .. tostring(enemyHealth.Value) .. "/" .. tostring(oldHealthAfterPrimary))
					end
					
					-- Handle enemy death
					if enemyHealth.Value <= 0 then
						local humanoid = descendant:FindFirstChild("Humanoid")
						if humanoid then
							humanoid.Health = 0
						end
						--print("[UltimateHandler] Enemy '" .. enemyName .. "' killed by ultimate (total damage: " .. totalUltimateDamage .. ")")
					end
				end
			end
		end
	end
	
	-- Damage players in PVP areas (similar to PVPHandler.RaycastPlayerHit)
	local attackerStats = player:FindFirstChild("Stats")
	local attackerMap = attackerStats and attackerStats:FindFirstChild("PlayerMap")
	
	if attackerMap and isPVPAllowed(attackerMap.Value) then
		for _, targetPlayer in pairs(Players:GetPlayers()) do
			if targetPlayer ~= player and targetPlayer.Character then
				-- Skip NPCs
				if targetPlayer.Character:GetAttribute("IsNPC") then
					continue
				end
				
				local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
				local targetStats = targetPlayer:FindFirstChild("Stats")
				local targetMap = targetStats and targetStats:FindFirstChild("PlayerMap")
				
				-- Check distance
				if targetRoot and (targetRoot.Position - centerPos).Magnitude <= radius then
					-- Check if players are dueling each other
					local arePlayersDueling = DuelHandler.ArePlayersDueling(player.UserId, targetPlayer.UserId)
					local attackerInDuel = DuelHandler.GetDuelOpponent(player.UserId) ~= nil
					local targetInDuel = DuelHandler.GetDuelOpponent(targetPlayer.UserId) ~= nil
					local shouldDamage = false
					
					if arePlayersDueling then
						-- Players are dueling each other - ALWAYS allow damage regardless of map
						--print("[UltimateHandler] Players are dueling each other, allowing ultimate damage")
						shouldDamage = true
					else
						-- Not dueling each other - check duel protection
						if attackerInDuel then
							-- Attacker is in a duel with someone else, block damage to non-opponent
							--print("[UltimateHandler] Attacker is in a duel with someone else, blocking damage")
							continue
						end
						
						if targetInDuel then
							-- Target is in a duel with someone else, block damage from non-opponent
							--print("[UltimateHandler] Target is in a duel with someone else, blocking damage")
							continue
						end
						
						-- If not in a duel, check normal PVP map restrictions
						if targetMap and isPVPAllowed(targetMap.Value) then
							shouldDamage = true
						end
					end
					
					if shouldDamage then
						-- Check if in same party
						local attackerPartyId = PartyDataStore.GetPartyId(player.UserId)
						local targetPartyId = PartyDataStore.GetPartyId(targetPlayer.UserId)
						if attackerPartyId and targetPartyId and attackerPartyId == targetPartyId then
							--print("[UltimateHandler] Skipping party member: " .. targetPlayer.Name)
							continue
						end
						
						-- Check if target is initializing
						if DamageManager.IsPlayerInitializing(targetPlayer) then
							--print("[UltimateHandler] Skipping initializing player: " .. targetPlayer.Name)
							continue
						end
						
						-- Check if target has equipped weapon
						local equippedFolder = targetStats:FindFirstChild("Equipped")
						if not equippedFolder or not equippedFolder:IsA("Folder") then
							--print("[UltimateHandler] Target player has no Equipped folder, blocking damage")
							continue
						end
						
						local equippedId = equippedFolder:FindFirstChild("id")
						if not equippedId or equippedId.Value == "" then
							--print("[UltimateHandler] Target player has no equipped weapon, blocking damage")
							continue
						end
						
						-- Apply defense reduction for PRIMARY weapon
						local actualPrimaryDamage = DamageManager.CalculateIncomingDamage(primaryUltimateDamage, targetPlayer)
						
						local currentHealth = targetStats:FindFirstChild("CurrentHealth")
						if currentHealth then
							currentHealth.Value = math.max(0, currentHealth.Value - actualPrimaryDamage)
							damageEvent:FireAllClients(targetPlayer.Character, actualPrimaryDamage, primaryIsCritical, false)
							--print("[UltimateHandler] Hit player '" .. targetPlayer.Name .. "' with PRIMARY for " .. actualPrimaryDamage .. " damage")
							
							-- Apply SECONDARY weapon damage if equipped and target still alive
							if hasSecondary and currentHealth.Value > 0 then
								local actualSecondaryDamage = DamageManager.CalculateIncomingDamage(secondaryUltimateDamage, targetPlayer)
								currentHealth.Value = math.max(0, currentHealth.Value - actualSecondaryDamage)
								damageEvent:FireAllClients(targetPlayer.Character, actualSecondaryDamage, secondaryIsCritical, false)
								--print("[UltimateHandler] Hit player '" .. targetPlayer.Name .. "' with SECONDARY for " .. actualSecondaryDamage .. " damage")
							end
							
							-- Save immediately
							UnifiedDataStoreManager.SaveStats(targetPlayer, false)
							
							-- Handle death
							if currentHealth.Value <= 0 then
								local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
								if humanoid then
									humanoid:TakeDamage(9999)
									DamageManager.MarkPlayerInitializing(targetPlayer)
								end
								--print("[UltimateHandler] Player '" .. targetPlayer.Name .. "' killed by ultimate (total damage: " .. totalUltimateDamage .. ")")
							end
						end
					end
				end
			end
		end
	end
end

-- Handle ultimate skill activation from client
ultimateSkillRemote.OnServerEvent:Connect(function(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	
	local ultimateStat = stats:FindFirstChild("UltimateCharge")
	if not ultimateStat then return end
	
	-- Check if player is alive
	local character = player.Character
	if not character then 
		--print("[UltimateHandler] " .. player.Name .. " tried to use ultimate but has no character")
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		--print("[UltimateHandler] " .. player.Name .. " tried to use ultimate but is dead")
		return
	end
	
	-- Check if ultimate charge is actually 100
	if ultimateStat.Value >= ULTIMATE_CHARGE_READY then
		--print("[UltimateHandler] " .. player.Name .. " activated ultimate skill! Charge was: " .. tostring(ultimateStat.Value))
		
		-- Reset ultimate charge to 0
		ultimateStat.Value = 0
		playerUltimateCharge[player.UserId] = 0
		
		-- Get the Ultimate model from ServerStorage
		local ultimateModel = ServerStorage:FindFirstChild("Ultimate")
		if not ultimateModel then
			warn("[UltimateHandler] Ultimate model not found in ServerStorage")
			return
		end
		
		-- Get player's equipped orb color
		local orbName = OrbSpiritHandler.GetEquippedOrbName(player)
		local orbColor = Color3.fromRGB(255, 255, 255) -- Default white
		
		if orbName and orbName ~= "" then
			-- Find the orb in ServerStorage to get its color
			local orbsFolder = ServerStorage:FindFirstChild("Orbs")
			local orbTemplate = nil
			
			if orbsFolder then
				orbTemplate = orbsFolder:FindFirstChild(orbName)
			end
			
			-- Also check OrbItems folder
			if not orbTemplate then
				local orbItemsFolder = ServerStorage:FindFirstChild("OrbItems")
				if orbItemsFolder then
					orbTemplate = orbItemsFolder:FindFirstChild(orbName)
				end
			end
			
			if orbTemplate then
				local handle = orbTemplate:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					orbColor = handle.Color
					--print("[UltimateHandler] Using orb color: " .. tostring(orbColor))
				end
			else
				warn("[UltimateHandler] Orb template not found for: " .. orbName)
			end
		end
		
		-- Clone the ultimate model
		local ultimateClone = ultimateModel:Clone()
		
		-- Change all particles to match orb color
		for _, descendant in ipairs(ultimateClone:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
				if descendant:IsA("ParticleEmitter") then
					descendant.Color = ColorSequence.new(orbColor)
				elseif descendant:IsA("Beam") or descendant:IsA("Trail") then
					descendant.Color = ColorSequence.new(orbColor)
				end
			end
		end
		
		   -- Position at player's torso
		   local character = player.Character
		   if character then
			   local humanoid = character:FindFirstChild("Humanoid")
			   local head = character:FindFirstChild("Head")
			   if humanoid and humanoid.Health > 0 then
				   -- Make the player jump before ultimate
				   humanoid.Jump = true
			   end
			   if head then
				   -- Play Light Explosion sound
				   SoundModule.playSoundInRange("Light Explosion", head.Position, "SFX", 100, false)
               
				   ultimateClone.Parent = workspace
               
				   -- Set position to head
				   if ultimateClone.PrimaryPart then
					   ultimateClone:SetPrimaryPartCFrame(head.CFrame)
				   elseif ultimateClone:FindFirstChildWhichIsA("BasePart") then
					   local firstPart = ultimateClone:FindFirstChildWhichIsA("BasePart")
					   firstPart.CFrame = head.CFrame
				   end
               
				   -- Anchor all parts in the model
				   for _, part in ipairs(ultimateClone:GetDescendants()) do
					   if part:IsA("BasePart") then
						   part.Anchored = true
					   end
				   end
               
				   -- Scale the model x3 over 0.2 seconds using ScaleTo
				   task.spawn(function()
					   local duration = 0.2
					   local startScale = 0.054
					   local targetScale = 3
					   local startTime = tick()
                   
					   while tick() - startTime < duration do
						   local elapsed = tick() - startTime
						   local alpha = elapsed / duration
						   local currentScale = startScale + (targetScale - startScale) * alpha
                       
						   ultimateClone:ScaleTo(currentScale)
						   task.wait()
					   end
                   
					   -- Ensure final scale is exact
					   ultimateClone:ScaleTo(targetScale)
				   end)
               
				   -- Deal damage to nearby enemies and players
				   dealUltimateDamage(player, head.Position, 50)
               
				   -- Destroy after 2 seconds
				   task.delay(2, function()
					   ultimateClone:Destroy()
					   --print("[UltimateHandler] Ultimate effect destroyed")
				   end)
			   end
		   end
		
		--print("[UltimateHandler] " .. player.Name .. " ultimate charge reset to 0")
	else
		--print("[UltimateHandler] " .. player.Name .. " tried to use ultimate but charge is only: " .. tostring(ultimateStat.Value) .. "/" .. tostring(ULTIMATE_CHARGE_READY))
	end
end)

function UltimateHandler.Init()
	--print("[UltimateHandler] ✓ Ultimate system initialized")
end

return UltimateHandler
