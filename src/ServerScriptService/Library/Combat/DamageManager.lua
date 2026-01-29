-- DamageManager.lua
-- Module for calculating damage including attack, weapon damage, and critical hits

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("OrbSpiritHandler"))

-- Create EnemyDamage RemoteEvent for client notifications
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end

-- local CRITICAL_MULTIPLIER = 2 -- replaced by per-player stat
local CRITICAL_CHANCE_PER_DEX = 3 -- Every 3 Dexterity = 1% critical chance
local DamageManager = {}

-- Get weapon damage from WeaponData module
local function getWeaponDamage(weaponName)
	if not weaponName then return 0 end
	local weaponStats = WeaponData.GetWeaponStats(weaponName)
	if weaponStats and weaponStats.damage then
		return weaponStats.damage
	end
	return 0
end

-- Calculate if critical hit occurs based on dexterity
local function isCriticalHit(dexterity)
	local criticalChance = (dexterity / CRITICAL_CHANCE_PER_DEX)
	local roll = math.random(0, 10000) / 100 -- Roll 0-100 with decimals for precision
	return roll < criticalChance
end

-- Calculate total damage including weapon and critical
-- Returns: finalDamage, isCritical, baseDamage, dexterityValue
-- Damage Formula: Player Attack + Weapon Damage = Base Damage
-- If Critical: Base Damage × 2 (then randomized)
-- Randomized between 40% to 100% of calculated damage
-- 
-- IMPORTANT: ORB MULTIPLIER ARCHITECTURE
-- The ONLY place where orb multipliers are applied to damage calculations
-- This multiplies the Attack stat for damage purposes only
-- The stat value itself (in player.Stats) remains unchanged (always base)
function DamageManager.calculateDamage(player, weaponName, randomFactor)
   if not player or not weaponName then
	   return 1, false, 1, 0
   end
   local stats = player:FindFirstChild("Stats")
   if not stats then 
	   return 1, false, 1, 0
   end
   local attackStat = stats:FindFirstChild("Attack")
   local defenceStat = stats:FindFirstChild("Defence")
   local dexterityStat = stats:FindFirstChild("Dexterity")
   local critDmgStat = stats:FindFirstChild("CriticalDamage")
   if not attackStat then
	   return 1, false, 1, 0
   end
   -- Get player base attack and defence
   local baseAttack = attackStat.Value or 1
   local baseDefence = defenceStat and defenceStat.Value or 1
   local weaponDamage = getWeaponDamage(weaponName)
   local dexterity = dexterityStat and dexterityStat.Value or 0
   -- Fetch orb multipliers from OrbSpiritHandler
   local userId = player.UserId
   local orbMultipliers = OrbSpiritHandler.GetOrbMultipliers and OrbSpiritHandler.GetOrbMultipliers(userId)
   local attackMultiplier = orbMultipliers and orbMultipliers.Attack or 1
   local critChanceMultiplier = orbMultipliers and orbMultipliers.CriticalChance or 1
   local critDamageMultiplier = orbMultipliers and orbMultipliers.CriticalDamage or 1
   -- Apply orb multipliers ONLY in damage calculation
   local effectiveAttack = math.floor(baseAttack * attackMultiplier)
   local effectiveDefence = math.floor(baseDefence)
   -- Base damage = Weapon Damage × (1 + effectiveAttack/100)
   local baseDamage = math.floor(weaponDamage * (1 + (effectiveAttack / 100)))
   -- Apply orb multiplier to crit chance: (dexterity / 3) * critChanceMultiplier
   local critChance = (dexterity / CRITICAL_CHANCE_PER_DEX) * critChanceMultiplier
   -- Determine if critical hit
   local roll = math.random(0, 10000) / 100
   local critical = roll < critChance
   -- Use per-player crit multiplier (default 50% = 1.5x), then apply orb crit damage multiplier
   local critMult = 2
   if critDmgStat and critDmgStat.Value then
	   critMult = 1 + (critDmgStat.Value / 100)
   end
   critMult = critMult * critDamageMultiplier
   -- Apply critical multiplier
   local calculatedDamage = critical and math.floor(baseDamage * critMult) or baseDamage
   -- No randomization: always 100% of calculated damage
   local finalDamage = math.max(calculatedDamage, 1)
   return finalDamage, critical, baseDamage, dexterity
end

-- Track players still initializing after spawn
local initializingPlayers = {}
local disconnectedPlayers = {} -- Track disconnected players

-- Mark a player as initializing (call when character spawns)
function DamageManager.MarkPlayerInitializing(player)
	initializingPlayers[player.UserId] = true
	print("[DamageManager] Player " .. player.Name .. " marked as initializing")
end

-- Mark a player as fully loaded (call when equipment is equipped)
function DamageManager.MarkPlayerLoaded(player)
	initializingPlayers[player.UserId] = nil
	print("[DamageManager] Player " .. player.Name .. " marked as fully loaded")
end

-- Mark a player as disconnected (call when player leaves)
function DamageManager.MarkPlayerDisconnected(player)
	disconnectedPlayers[player.UserId] = true
	print("[DamageManager] Player " .. player.Name .. " marked as disconnected - cannot receive damage")
end

-- Check if player is still initializing
local function isPlayerInitializing(player)
	return initializingPlayers[player.UserId] == true
end

-- Check if player is disconnected
local function isPlayerDisconnected(player)
	return disconnectedPlayers[player.UserId] == true
end

-- Public function to check if player is initializing (for use in other modules)
function DamageManager.IsPlayerInitializing(player)
	return isPlayerInitializing(player)
end

-- Get damage range for UI display (min damage to max damage with critical)
function DamageManager.getDamageRange(player, weaponName)
   if not player or not weaponName then
	   return 1, 2
   end
   local stats = player:FindFirstChild("Stats")
   if not stats then
	   return 1, 2
   end
   local attackStat = stats:FindFirstChild("Attack")
   local critDmgStat = stats:FindFirstChild("CriticalDamage")
   local dexterityStat = stats:FindFirstChild("Dexterity")
   if not attackStat then
	   return 1, 2
   end
   local attackDamage = attackStat.Value or 1
   local weaponDamage = getWeaponDamage(weaponName)
   local dexterity = dexterityStat and dexterityStat.Value or 0
   -- APPLY ORB MULTIPLIER TO ATTACK STAT FOR DAMAGE RANGE
   local orbMultipliers = OrbSpiritHandler.GetOrbMultipliers(player)
   local attackMultiplier = orbMultipliers and orbMultipliers.Attack or 1
   local critChanceMultiplier = orbMultipliers and orbMultipliers.CriticalChance or 1
   local critDamageMultiplier = orbMultipliers and orbMultipliers.CriticalDamage or 1
   attackDamage = math.floor(attackDamage * attackMultiplier)
   -- Base damage = Weapon Damage × (1 + Attack/100)
   local baseDamage = math.floor(weaponDamage * (1 + (attackDamage / 100)))
   -- Crit chance (for display): (dexterity / 3) * critChanceMultiplier
   local critChance = (dexterity / CRITICAL_CHANCE_PER_DEX) * critChanceMultiplier
   -- Crit multiplier
   local critMult = 2
   if critDmgStat and critDmgStat.Value then
	   critMult = 1 + (critDmgStat.Value / 100)
   end
   critMult = critMult * critDamageMultiplier
   local minDamage = baseDamage
   local maxDamage = math.floor(baseDamage * critMult)
   return minDamage, maxDamage, critChance
end

------- INCOMING DAMAGE (Defense-based reduction with Armor) -------


-- Helper: Calculate total armor defense from equipped armor
local function getEquippedArmorDefense(stats)
	if not stats then return 0 end
	local total = 0
	local function getArmorDef(slotName)
		local slot = stats:FindFirstChild(slotName)
		if slot and slot:IsA("Folder") then
			local nameValue = slot:FindFirstChild("name")
			local armorName = nameValue and nameValue.Value or ""
			if armorName ~= "" and ArmorData[armorName] and ArmorData[armorName].Defense then
				return ArmorData[armorName].Defense
			end
		end
		return 0
	end
	total = total + getArmorDef("EquippedHelmet")
	total = total + getArmorDef("EquippedSuit")
	total = total + getArmorDef("EquippedLegs")
	total = total + getArmorDef("EquippedShoes")
	return total
end

-- Defensive Output = sqrt(Defence * ArmorDefence) / 1.5 (diminishing returns)
local function calculateDefensiveOutput(defense, armorDefense)
	local defensiveOutput = math.sqrt(defense * armorDefense) / 1.5
	return defensiveOutput
end

-- Calculate incoming damage after defense reduction
-- baseDamage: Base damage from enemy (e.g., 5 from enemy stat)
-- player: The player taking damage
-- randomFactor: Optional damage variance (0.4 to 0.7 range, default random)
-- returns: Reduced damage amount after defense calculation
function DamageManager.CalculateIncomingDamage(baseDamage, player, randomFactor)
	if not player or not baseDamage or baseDamage <= 0 then
		return 0
	end

	local stats = player:FindFirstChild("Stats")
	if not stats then
		-- No stats folder, return base damage (shouldn't happen but safe default)
		return baseDamage
	end

	-- Get Defence stat
	local defenseValue = stats:FindFirstChild("Defence")
	local defence = defenseValue and defenseValue.Value or 0

	-- Calculate armor defense dynamically from equipped armor
	local armorDefense = getEquippedArmorDefense(stats)

	-- Calculate defensive output (diminishing returns)
	local defensiveOutput = calculateDefensiveOutput(defence, armorDefense)

	-- Randomize enemy damage between 40% to 100% of base damage
	if not randomFactor then
		randomFactor = 0.4 + (math.random() * 0.6) -- Random between 0.4 and 1.0
	end

	local enemyDamage = baseDamage * randomFactor

	-- Apply defensive reduction: Damage - DefensiveOutput
	local reducedDamage = enemyDamage - defensiveOutput

	-- Allow 0 damage if fully absorbed
	return math.max(0, math.floor(reducedDamage))
end

-- Get defense bonus information (for debugging or UI display)
function DamageManager.GetDefenseInfo(player)
	if not player then return 0, 0, 0 end
    
	local stats = player:FindFirstChild("Stats")
	if not stats then return 0, 0, 0 end
    
	local defenseValue = stats:FindFirstChild("Defence")
	local defence = defenseValue and defenseValue.Value or 0
    
	local armorDefense = getEquippedArmorDefense(stats)
	local defensiveOutput = calculateDefensiveOutput(defence, armorDefense)
    
	return defence, armorDefense, defensiveOutput
end

-- Apply damage to a player and update their health
-- baseDamage: The base damage being dealt
-- player: The player taking damage
-- randomFactor: Optional damage variance (for consistent testing)
-- returns: Actual damage dealt after defense reduction
function DamageManager.DamagePlayer(baseDamage, player, randomFactor)
	if not player then return 0 end
	
	-- Check if player is disconnected - skip damage
	if isPlayerDisconnected(player) then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - player disconnected")
		return 0
	end
	
	-- Check if player is still initializing - skip damage during spawn
	if isPlayerInitializing(player) then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - player still initializing")
		return 0
	end
	
	local stats = player:FindFirstChild("Stats")
	if not stats then return 0 end
	
	-- Check if player has equipped weapon
	local equippedFolder = stats:FindFirstChild("Equipped")
	if not equippedFolder or not equippedFolder:IsA("Folder") then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - no Equipped folder")
		return 0
	end
	
	local equippedId = equippedFolder:FindFirstChild("id")
	if not equippedId or equippedId.Value == "" then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - no equipped weapon ID")
		return 0
	end
	
	-- Check if player has a character with humanoid
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - no character or humanoid")
		return 0
	end
	
	-- Check if player actually has the weapon in their hand (equipped tool in character)
	local equippedWeaponName = equippedFolder:FindFirstChild("name")
	if not equippedWeaponName then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - no weapon name value")
		return 0
	end
	
	local baseWeaponName = equippedWeaponName.Value:match("^([^_]+)") or equippedWeaponName.Value
	local hasEquippedTool = false
	for _, tool in ipairs(player.Character:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == baseWeaponName then
			hasEquippedTool = true
			break
		end
	end
	
	if not hasEquippedTool then
		print("[DamageManager] Blocked damage to " .. player.Name .. " - weapon not in character hand")
		return 0
	end
	
	local currentHealth = stats:FindFirstChild("CurrentHealth")
	if not currentHealth then return 0 end
	
	-- Calculate reduced damage based on defense and armor
	local actualDamage = DamageManager.CalculateIncomingDamage(baseDamage, player, randomFactor)
	
	-- Apply the damage
	currentHealth.Value = math.max(0, currentHealth.Value - actualDamage)
	
	return actualDamage
end

return DamageManager
