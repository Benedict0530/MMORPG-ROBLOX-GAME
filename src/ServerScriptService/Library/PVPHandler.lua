-- PVPHandler.lua
-- Handles player-vs-player damage detection and application


print("[PVPHandler][DEBUG] Module loaded (very top, before requires)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)

-- Create RemoteEvent for showing player damage text on clients
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end

local PVPHandler = {}
print("[PVPHandler][DEBUG] Module loaded")

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
				print("[PVPHandler][DEBUG] Target is an NPC (IsNPC attribute), blocking damage")
				continue
			end
			
			local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			-- Check distance, directional cone, AND raycast line-of-sight
			if targetRoot and (targetRoot.Position - attackerPos).Magnitude <= radius and isTargetInAttackCone(charRoot, targetRoot) and raycastHitsTarget(charRoot, targetRoot, radius) then
				local skip = false
				-- Check if already hit
				if hitEnemies[targetPlayer] then
					print("[PVPHandler][DEBUG][Proximity] Already hit this player in this attack.")
					skip = true
				end

				local attackerStats = attacker:FindFirstChild("Stats")
				local targetStats = targetPlayer:FindFirstChild("Stats")
				print("[PVPHandler][DEBUG][Proximity] attackerStats:", attackerStats)
				print("[PVPHandler][DEBUG][Proximity] targetStats:", targetStats)
				if not (attackerStats and targetStats) then
					print("[PVPHandler][DEBUG][Proximity] One or both player stats missing.")
					skip = true
				end

				local attackerMap = attackerStats and attackerStats:FindFirstChild("PlayerMap")
				local targetMap = targetStats and targetStats:FindFirstChild("PlayerMap")
				print("[PVPHandler][DEBUG][Proximity] attackerMap:", attackerMap and attackerMap.Value)
				print("[PVPHandler][DEBUG][Proximity] targetMap:", targetMap and targetMap.Value)
				if not (attackerMap and targetMap) then
					print("[PVPHandler][DEBUG][Proximity] One or both player map info missing.")
					skip = true
				end
				if attackerMap and targetMap and (attackerMap.Value ~= "PVP Area" or targetMap.Value ~= "PVP Area") then
					print("[PVPHandler][DEBUG][Proximity] One or both players not in PVP Area.")
					skip = true
				end

				if not skip then
					-- Mark as hit
					hitEnemies[targetPlayer] = true
				-- Check if target player is still initializing - skip damage during spawn
				if DamageManager.IsPlayerInitializing(targetPlayer) then
					print("[PVPHandler][DEBUG][Proximity] Target player " .. targetPlayer.Name .. " is still initializing, blocking damage")
					skip = true
				end
				
				-- Check if target has equipped weapon
				local equippedFolder = targetStats:FindFirstChild("Equipped")
				if not equippedFolder or not equippedFolder:IsA("Folder") then
					print("[PVPHandler][DEBUG][Proximity] Target player has no Equipped folder, blocking damage")
					skip = true
				end
				
				local equippedId = equippedFolder and equippedFolder:FindFirstChild("id")
				if not equippedId or equippedId.Value == "" then
					print("[PVPHandler][DEBUG][Proximity] Target player has no equipped weapon ID, blocking damage")
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
							print("[PVPHandler][DEBUG][Proximity] Target player has no equipped tool in character, blocking damage")
							skip = true
						end
					else
						print("[PVPHandler][DEBUG][Proximity] Target player has no weapon name value, blocking damage")
						skip = true
					end
				end
				
				if skip then
					-- Remove the hit marker since we're not actually hitting
					hitEnemies[targetPlayer] = nil
					return
				end
					-- Calculate outgoing damage from attacker
					local outgoingDamage, isCritical = DamageManager.calculateDamage(attacker, weaponName)
					
					-- Apply target's defense reduction to get actual damage dealt
					local actualDamage = DamageManager.CalculateIncomingDamage(outgoingDamage, targetPlayer)
					
					print("[PVPHandler][DEBUG][Proximity] Outgoing damage:", outgoingDamage, "After defense:", actualDamage, "isCritical:", isCritical)
					local currentHealth = targetStats:FindFirstChild("CurrentHealth")
					print("[PVPHandler][DEBUG][Proximity] currentHealth before:", currentHealth and currentHealth.Value)

					if currentHealth then
						currentHealth.Value = math.max(0, currentHealth.Value - actualDamage)
						print("[PVPHandler][DEBUG][Proximity] currentHealth after:", currentHealth.Value)

						-- Save immediately to DataStore for PVP
						local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
						UnifiedDataStoreManager.SaveStats(targetPlayer, true)

						-- Handle death
						if currentHealth.Value <= 0 then
							local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
							print("[PVPHandler][DEBUG][Proximity] Player died, humanoid:", humanoid)
							if humanoid then
								humanoid:TakeDamage(9999)
								DamageManager.MarkPlayerInitializing(targetPlayer)
							end
						end
					else
						print("[PVPHandler][DEBUG][Proximity] currentHealth stat missing!")
					end

					-- Fire sound and damage event
					SoundModule.playSoundByName("Hit", "SFX", false, 1)
					damageEvent:FireAllClients(targetPlayer.Character, actualDamage, isCritical, false)

					print("[PVPHandler][Proximity] " .. attacker.Name .. " hit player '" .. targetPlayer.Name .. "' for " .. tostring(actualDamage) .. " damage (crit: " .. tostring(isCritical) .. ")")
				end
			end
		end
	end
	return true
end

return PVPHandler
