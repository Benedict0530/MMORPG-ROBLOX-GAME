-- DamageManager.lua
-- Module for calculating damage including attack, weapon damage, and critical hits

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))

-- Create EnemyDamage RemoteEvent for client notifications
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end

local CRITICAL_MULTIPLIER = 2
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
-- Randomized between 40% to 70% of calculated damage
function DamageManager.calculateDamage(player, weaponName, randomFactor)
	if not player or not weaponName then
		return 1, false, 1, 0
	end
	
	local stats = player:FindFirstChild("Stats")
	if not stats then 
		return 1, false, 1, 0
	end
	
	local attackStat = stats:FindFirstChild("Attack")
	local dexterityStat = stats:FindFirstChild("Dexterity")
	
	if not attackStat then
		return 1, false, 1, 0
	end
	
	-- Get player attack and weapon damage
	local attackDamage = attackStat.Value or 1
	local weaponDamage = getWeaponDamage(weaponName)
	local dexterity = dexterityStat and dexterityStat.Value or 0
	
	-- Base damage = Player Attack + Weapon Damage
	local baseDamage = attackDamage + weaponDamage
	
	-- Determine if critical hit
	local critical = isCriticalHit(dexterity)
	
	-- Apply critical multiplier
	local calculatedDamage = critical and math.floor(baseDamage * CRITICAL_MULTIPLIER) or baseDamage
	
	-- Randomize damage between 40% to 100% of calculated damage
	-- If randomFactor not provided, generate random between 0.4 and 1.0
	if not randomFactor then
		randomFactor = 0.4 + (math.random() * 0.6) -- Random between 0.4 and 1.0
	end
	
	local finalDamage = math.floor(calculatedDamage * randomFactor)
	finalDamage = math.max(finalDamage, 1) -- Ensure minimum damage of 1
	
	return finalDamage, critical, baseDamage, dexterity
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
	if not attackStat then
		return 1, 2
	end
	
	local attackDamage = attackStat.Value or 1
	local weaponDamage = getWeaponDamage(weaponName)
	local baseDamage = attackDamage + weaponDamage
	
	local minDamage = baseDamage
	local maxDamage = math.floor(baseDamage * CRITICAL_MULTIPLIER)
	
	return minDamage, maxDamage
end

------- INCOMING DAMAGE (Defense-based reduction with Armor) -------

-- Defensive Output = √(Player Defence × Player Armor Defence)
-- This creates a meaningful benefit from stacking both Defence and Armor
-- Damage taken = Enemy damage roll - Defensive Output (minimum 1)
local function calculateDefensiveOutput(defense, armorDefense)
	-- Square root of (Defence × Armor Defence)
	local defensiveOutput = math.sqrt(defense * armorDefense)
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
	
	-- Get Defence and Armor Defence stats
	local defenseValue = stats:FindFirstChild("Defence")
	local defence = defenseValue and defenseValue.Value or 0
	
	-- Armor Defence defaults to Defence value if not present (same defensive power)
	-- Players can allocate extra to ArmorDefence for more defense
	local armorDefenseValue = stats:FindFirstChild("ArmorDefence")
	local armorDefense = (armorDefenseValue and armorDefenseValue.Value > 0) and armorDefenseValue.Value or defence
	
	-- Calculate defensive output
	local defensiveOutput = calculateDefensiveOutput(defence, armorDefense)
	
	-- Randomize enemy damage between 40% to 100% of base damage
	-- If randomFactor not provided, generate random between 0.4 and 1.0
	if not randomFactor then
		randomFactor = 0.4 + (math.random() * 0.6) -- Random between 0.4 and 1.0
	end
	
	local enemyDamage = baseDamage * randomFactor
	
	-- Apply defensive reduction: Damage - DefensiveOutput
	local reducedDamage = enemyDamage - defensiveOutput
	
	-- Damage can go to 0 if defence is high enough
	return math.max(0, math.floor(reducedDamage))
end

-- Get defense bonus information (for debugging or UI display)
function DamageManager.GetDefenseInfo(player)
	if not player then return 0, 0, 0 end
	
	local stats = player:FindFirstChild("Stats")
	if not stats then return 0, 0, 0 end
	
	local defenseValue = stats:FindFirstChild("Defence")
	local defence = defenseValue and defenseValue.Value or 0
	
	local armorDefenseValue = stats:FindFirstChild("ArmorDefence")
	local armorDefense = (armorDefenseValue and armorDefenseValue.Value > 0) and armorDefenseValue.Value or defence
	
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
	
	local stats = player:FindFirstChild("Stats")
	if not stats then return 0 end
	
	local currentHealth = stats:FindFirstChild("CurrentHealth")
	if not currentHealth then return 0 end
	
	-- Calculate reduced damage based on defense and armor
	local actualDamage = DamageManager.CalculateIncomingDamage(baseDamage, player, randomFactor)
	
	-- Apply the damage
	currentHealth.Value = math.max(0, currentHealth.Value - actualDamage)
	
	return actualDamage
end

return DamageManager
