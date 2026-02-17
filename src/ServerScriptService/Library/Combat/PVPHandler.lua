-- PVPHandler.lua
-- Handles player-vs-player damage detection and application


--print("[PVPHandler][DEBUG] Module loaded (very top, before requires)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)
local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))
local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonsData"))
local DuelHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Player"):WaitForChild("DuelHandler"))
local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))

-- Create RemoteEvent for showing player damage text on clients
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end

local PVPHandler = {}
--print("[PVPHandler][DEBUG] Module loaded")

-- Track consecutive hits on players (stores hit count and last hit time)
local consecutiveHits = {}
local HIT_RESET_TIMEOUT = 5 -- Reset consecutive hits after 5 seconds with no new hits (allows time for combo)

-- Function to get and update consecutive hit count
local function getAndUpdateHitCount(targetUserId)
	local currentTime = tick()
	
	if not consecutiveHits[targetUserId] then
		consecutiveHits[targetUserId] = {count = 0, lastHitTime = 0}
	end
	
	-- Reset count if last hit was more than timeout seconds ago
	if currentTime - consecutiveHits[targetUserId].lastHitTime > HIT_RESET_TIMEOUT then
		consecutiveHits[targetUserId].count = 0
	end
	
	-- Increment hit count
	consecutiveHits[targetUserId].count = consecutiveHits[targetUserId].count + 1
	consecutiveHits[targetUserId].lastHitTime = currentTime
	
	return consecutiveHits[targetUserId].count
end

-- Helper function to check if target is in front of or beside the attacker
-- Uses a 360-degree cone (all directions)
local function isTargetInAttackCone(attackerRoot, targetRoot)
	-- 360 degree detection - always return true (any direction is valid)
	return true
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
		-- Check if hit part belongs to target player
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

-- Check if hit target is a player and apply PVP damage
-- Raycast-based PVP detection

function PVPHandler.RaycastPlayerHit(attacker, weaponName, hitEnemies, radius)
	local Players = game:GetService("Players")
	local attackerChar = attacker.Character
	if not attackerChar then return false end
	local charRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if not charRoot then return false end

	radius = radius or 5 -- Default melee range
	local attackerPos = charRoot.Position

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= attacker and targetPlayer.Character then
			-- Prevent damage to NPCs - check IsNPC attribute
			if targetPlayer.Character:GetAttribute("IsNPC") then
				--print("[PVPHandler][DEBUG] Target is an NPC (IsNPC attribute), blocking damage")
				continue
			end
			
			local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			-- Check distance, directional cone, AND raycast line-of-sight
			if targetRoot and (targetRoot.Position - attackerPos).Magnitude <= radius and isTargetInAttackCone(charRoot, targetRoot) and raycastHitsTarget(charRoot, targetRoot, radius) then
				local skip = false
				
				-- Check if attacker or target is in SafeZone - block PVP damage
				if attacker:GetAttribute("SafeZone") == true then
					--print("[PVPHandler][DEBUG] Attacker is in SafeZone, blocking PVP damage")
					skip = true
				end
				
				if targetPlayer:GetAttribute("SafeZone") == true then
					--print("[PVPHandler][DEBUG] Target is in SafeZone, blocking PVP damage")
					skip = true
				end
				
				-- Check if already hit
				if hitEnemies[targetPlayer] then
					--print("[PVPHandler][DEBUG][Proximity] Already hit this player in this attack.")
					skip = true
				end

				local attackerStats = attacker:FindFirstChild("Stats")
				local targetStats = targetPlayer:FindFirstChild("Stats")
				--print("[PVPHandler][DEBUG][Proximity] attackerStats:", attackerStats)
				--print("[PVPHandler][DEBUG][Proximity] targetStats:", targetStats)
				if not (attackerStats and targetStats) then
					--print("[PVPHandler][DEBUG][Proximity] One or both player stats missing.")
					skip = true
				end

				local attackerMap = attackerStats and attackerStats:FindFirstChild("PlayerMap")
				local targetMap = targetStats and targetStats:FindFirstChild("PlayerMap")
				--print("[PVPHandler][DEBUG][Proximity] attackerMap:", attackerMap and attackerMap.Value)
				--print("[PVPHandler][DEBUG][Proximity] targetMap:", targetMap and targetMap.Value)
				if not (attackerMap and targetMap) then
					--print("[PVPHandler][DEBUG][Proximity] One or both player map info missing.")
					skip = true
				end
				
				-- Check if players are dueling each other
				local arePlayersDueling = DuelHandler.ArePlayersDueling(attacker.UserId, targetPlayer.UserId)
				local attackerInDuel = DuelHandler.GetDuelOpponent(attacker.UserId) ~= nil
				local targetInDuel = DuelHandler.GetDuelOpponent(targetPlayer.UserId) ~= nil
				
				   if arePlayersDueling then
					   -- Block damage between duelists until countdown ends
					   if DuelHandler.IsDuelDamageLocked(attacker.UserId) or DuelHandler.IsDuelDamageLocked(targetPlayer.UserId) then
						   --print("[PVPHandler][DEBUG][Proximity] Duel countdown active, blocking damage between duelists")
						   skip = true
					   end
					   -- Otherwise, allow damage
				else
					-- Not dueling each other - check duel protection
					if attackerInDuel then
						-- Attacker is in a duel with someone else, block damage to non-opponent
						--print("[PVPHandler][DEBUG][Proximity] Attacker is in a duel with someone else, blocking damage")
						skip = true
					end
					
					if targetInDuel then
						-- Target is in a duel with someone else, block damage from non-opponent
						--print("[PVPHandler][DEBUG][Proximity] Target is in a duel with someone else, blocking damage")
						skip = true
					end
					
					-- If not in a duel, check normal PVP map restrictions
					if not skip then
						local function isPVPAllowed(mapName)
							if mapName == "PVP Area" then return true end
							local data = DungeonsData[mapName]
							return data and data.AllowPVP == true
						end
						if attackerMap and targetMap and (not isPVPAllowed(attackerMap.Value) or not isPVPAllowed(targetMap.Value)) then
							--print("[PVPHandler][DEBUG][Proximity] One or both players not in a PVP-enabled map.")
							skip = true
						end
					end
				end

				if not skip then
					-- Mark as hit
					hitEnemies[targetPlayer] = true

					-- Check if target player is still initializing - skip damage during spawn
					if DamageManager.IsPlayerInitializing(targetPlayer) then
						skip = true
					end

					-- Check if target has equipped weapon
					local equippedFolder = targetStats:FindFirstChild("Equipped")
					if not equippedFolder or not equippedFolder:IsA("Folder") then
						skip = true
					end

					local equippedId = equippedFolder and equippedFolder:FindFirstChild("id")
					if not equippedId or equippedId.Value == "" then
						skip = true
					end

					-- Check if target actually has the weapon in their character (equipped tool)
					if not skip then
						local equippedWeaponName = equippedFolder:FindFirstChild("name")
						if equippedWeaponName then
							local baseWeaponName = equippedWeaponName.Value:match("^([^_]+)") or equippedWeaponName.Value
							local hasEquippedTool = false
							for _, tool in ipairs(targetPlayer.Character:GetChildren()) do
								if tool:IsA("Tool") and tool.Name == baseWeaponName then
									hasEquippedTool = true
									break
								end
							end
							if not hasEquippedTool then
								skip = true
							end
						else
							skip = true
						end
					end

					if skip then
						hitEnemies[targetPlayer] = nil
						return
					end

					-- Check if players are dueling each other - if so, allow damage even if in same party
					local arePlayersDueling = DuelHandler.ArePlayersDueling(attacker.UserId, targetPlayer.UserId)

					-- Check if both players are in the same party (but skip if they're dueling)
					if not arePlayersDueling then
						local attackerPartyId = PartyDataStore.GetPartyId(attacker.UserId)
						local targetPartyId = PartyDataStore.GetPartyId(targetPlayer.UserId)
						if attackerPartyId and targetPartyId and attackerPartyId == targetPartyId then
							hitEnemies[targetPlayer] = nil
							return
						end
					end

					-- Calculate outgoing damage from attacker
					local outgoingDamage, isCritical = DamageManager.calculateDamage(attacker, weaponName)
					-- Apply target's defense reduction to get actual damage dealt
					local actualDamage = DamageManager.CalculateIncomingDamage(outgoingDamage, targetPlayer)
					local currentHealth = targetStats:FindFirstChild("CurrentHealth")

					-- Duel finishing logic: if this hit would kill during a duel, skip damage and fire DuelFinishingEvent
					if arePlayersDueling and currentHealth and currentHealth.Value - actualDamage <= 0 then
						-- Fire duel finishing event instead of applying damage
						DuelHandler.fireDuelFinishingEvent(attacker.UserId, targetPlayer.UserId)
						-- Optionally, mark as hit or do any other logic needed
						return
					end

					if currentHealth then
						currentHealth.Value = math.max(0, currentHealth.Value - actualDamage)
						local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
						UnifiedDataStoreManager.SaveStats(targetPlayer, false)
						if currentHealth.Value <= 0 then
							local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
							if humanoid then
								humanoid:TakeDamage(9999)
								DamageManager.MarkPlayerInitializing(targetPlayer)
							end
						end
					end

					SoundModule.playSoundByName("Hit", "SFX", false, 1)
					damageEvent:FireAllClients(targetPlayer.Character, actualDamage, isCritical, false)

					local arePlayersDueling = DuelHandler.ArePlayersDueling(attacker.UserId, targetPlayer.UserId)
					if not arePlayersDueling then
					local hitCount = getAndUpdateHitCount(targetPlayer.UserId)
					
					if hitCount == 2 then
						-- Second consecutive hit: apply knockback and ragdoll
						local KnockbackEvent = ReplicatedStorage:FindFirstChild("KnockbackEvent")
						if KnockbackEvent and charRoot and targetRoot then
							-- Calculate knockback direction (away from attacker)
							local knockbackDirection = (targetRoot.Position - charRoot.Position).Unit
							KnockbackEvent:FireClient(targetPlayer, knockbackDirection, 100) -- 50 is knockback force
							--print("[PVPHandler] Triggered knockback and ragdoll on " .. targetPlayer.Name .. " (hit count: " .. hitCount .. ")")
							
							-- Reset hit counter asynchronously after ragdoll effect (non-blocking)
							task.spawn(function()
								task.wait(1.5)
								consecutiveHits[targetPlayer.UserId] = {count = 0, lastHitTime = 0}
								--print("[PVPHandler] Reset hit counter for " .. targetPlayer.Name .. " after ragdoll")
							end)
						end
					else
						-- First hit or reset: apply normal paralysis
						local ParalysisEvent = ReplicatedStorage:FindFirstChild("ParalysisEvent")
						if ParalysisEvent then
							ParalysisEvent:FireClient(targetPlayer, 1)
							--print("[PVPHandler] Triggered paralysis effect on " .. targetPlayer.Name .. " (hit count: " .. hitCount .. ")")
							
							-- Reset hit counter asynchronously after paralysis effect (non-blocking)
							task.spawn(function()
								task.wait(1.2)
								consecutiveHits[targetPlayer.UserId] = {count = 0, lastHitTime = 0}
								--print("[PVPHandler] Reset hit counter for " .. targetPlayer.Name .. " after paralysis")
							end)
						end
					end
				else
					--print("[PVPHandler] Players are dueling - skipping paralysis/knockback effects")
				end

				-- Apply spirit orb highlight effect if attacker has spirit orb equipped
				if OrbSpiritHandler.HasSpiritOrb(attacker) then
						local orbName = OrbSpiritHandler.GetEquippedOrbName(attacker)
						if orbName and orbName ~= "" then
							-- Get orb colors table and highlight function from WeaponManager
							local orbTypeColors = {
								Fire = Color3.fromRGB(255, 102, 51),
								Wind = Color3.fromRGB(0, 85, 0),
								Water = Color3.fromRGB(0, 0, 255),
								Earth = Color3.fromRGB(83, 28, 0),
								Shadow = Color3.fromRGB(170, 0, 255),
								Dark = Color3.fromRGB(0, 0, 0),
								Light = Color3.fromRGB(255, 255, 255),
								Radiant = Color3.fromRGB(255, 250, 110),
							}
							
							local function getOrbType(orbNameStr)
								return orbNameStr:match("^(.+)%s+Orb$") or orbNameStr
							end
							
							local function applyHighlight(targetModel, orbNameStr)
								if not targetModel or not orbNameStr or orbNameStr == "" then return end
								local orbType = getOrbType(orbNameStr)
								local highlightColor = orbTypeColors[orbType]
								if not highlightColor then return end
								
								for _, part in ipairs(targetModel:GetDescendants()) do
									if part:IsA("BasePart") then
										task.spawn(function()
											local originalColor = part.Color
											part.Color = highlightColor
											task.wait(0.2)
											part.Color = originalColor
										end)
									end
								end
							end
							
							task.spawn(function()
								applyHighlight(targetPlayer.Character, orbName)
							end)
						end
					end

					--print("[PVPHandler][Proximity] " .. attacker.Name .. " hit player '" .. targetPlayer.Name .. "' for " .. tostring(actualDamage) .. " damage (crit: " .. tostring(isCritical) .. ")")
				end
			end
		end
	end
	return true
end


-- Fire damage zone logic for Workspace/Maps/PVP Area
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Maps = Workspace:FindFirstChild("Maps")
local mapList = {}
if Maps then
	local pvpArea = Maps:FindFirstChild("PVP Area")
	if pvpArea then table.insert(mapList, pvpArea) end
	local grimleaf1 = Maps:FindFirstChild("Grimleaf 1 Dungeon")
	if grimleaf1 then table.insert(mapList, grimleaf1) end
end

for _, map in ipairs(mapList) do
	for _, firePart in ipairs(map:GetChildren()) do
		if firePart.Name == "Fire" and firePart:IsA("BasePart") then
			firePart.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end
				if character:GetAttribute("_FireDamageActive") then return end -- Prevent duplicate damage loops
				character:SetAttribute("_FireDamageActive", true)
				local stats = player:FindFirstChild("Stats")
				local currentHealth = stats and stats:FindFirstChild("CurrentHealth")
				local maxHealth = stats and stats:FindFirstChild("MaxHealth")
				if not currentHealth or not maxHealth then return end
				-- Store original colors
				local originalColors = {}
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						originalColors[part] = part.Color
						part.Color = Color3.fromRGB(255,0,0)
					end
				end
				-- Damage loop
				local damageConn
				local function stopDamage()
					if damageConn then damageConn:Disconnect() end
					character:SetAttribute("_FireDamageActive", nil)
					for part, color in pairs(originalColors) do
						if part and part:IsA("BasePart") then
							part.Color = color
						end
					end
				end
				damageConn = firePart.TouchEnded:Connect(function(endedHit)
					if endedHit.Parent == character then
						stopDamage()
					end
				end)
				-- Damage every second while touching, with robust check
				task.spawn(function()
					while character:GetAttribute("_FireDamageActive") do
						-- Robust check: is character still touching firePart?
						local stillTouching = false
						for _, part in ipairs(character:GetDescendants()) do
							if part:IsA("BasePart") then
								local touching = part:GetTouchingParts()
								for _, t in ipairs(touching) do
									if t == firePart then
										stillTouching = true
										break
									end
								end
								if stillTouching then break end
							end
						end
						if not stillTouching then
							stopDamage()
							break
						end
						if currentHealth and maxHealth and currentHealth.Value > 0 then
							-- Calculate 5% of max health, but ensure at least 1 damage
							local damage = math.max(1, math.floor(maxHealth.Value * 0.05))
							local oldHealth = currentHealth.Value
							currentHealth.Value = math.max(0, currentHealth.Value - damage)
							-- Fire damage text event for UI
							local targetPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
							if targetPart then
								damageEvent:FireClient(player, targetPart, damage, false, false)
							end
							-- Kill player if HP reaches 0
							if currentHealth.Value <= 0 then
								local humanoid = character:FindFirstChild("Humanoid")
								if humanoid then
									humanoid:TakeDamage(9999)
								end
								stopDamage()
								break
							end
						end
						task.wait(1)
					end
				end)
			end)
		end
	end
end

return PVPHandler