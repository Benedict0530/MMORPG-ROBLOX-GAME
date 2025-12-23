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

local CRITICAL_MULTIPLIER = 1.5
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
-- If Critical: Base Damage × 1.5
function DamageManager.calculateDamage(player, weaponName)
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
	local finalDamage = critical and math.floor(baseDamage * CRITICAL_MULTIPLIER) or baseDamage
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

return DamageManager
