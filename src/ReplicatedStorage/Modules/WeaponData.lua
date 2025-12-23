local WeaponData = {}

-- Weapon definitions with their attributes
WeaponData.Weapons = {
    ["Twig"] = {
		damage = 5,
		speed = 0.5,
		imageId = "rbxassetid://127490675569703",
		type = "One-Handed",
		rarity = "Common"
	},
	["Sword"] = {
		damage = 10,
		speed = 1.5,
		type = "One-Handed",
		rarity = "Common"
	},
	["BigTwig"] = {
		damage = 15,
		speed = 1.1,
		type = "Two-Handed",
		rarity = "Common"
	},
	["Dual Daggers"] = {
		damage = 8,
		speed = 1.8,
		type = "Dual-Wield",
		rarity = "Uncommon"
	},
	["Gladius"] = {
		damage = 12,
		speed = 1.4,
		type = "One-Handed",
		rarity = "Common"
	},
	["Claymore"] = {
		damage = 25,
		speed = 0.8,
		type = "Two-Handed",
		rarity = "Rare"
	},
	["Katana"] = {
		damage = 18,
		speed = 1.2,
		type = "Two-Handed",
		rarity = "Rare"
	},
	["Dual Scimitars"] = {
		damage = 14,
		speed = 1.3,
		type = "Dual-Wield",
		rarity = "Rare"
	},
	["Rapier"] = {
		damage = 11,
		speed = 1.5,
		type = "One-Handed",
		rarity = "Uncommon"
	},
	["Greatsword"] = {
		damage = 30,
		speed = 0.7,
		type = "Two-Handed",
		rarity = "Epic"
	},
	["Dual Swords"] = {
		damage = 16,
		speed = 1.25,
		type = "Dual-Wield",
		rarity = "Epic"
	},
	["Excalibur"] = {
		damage = 40,
		speed = 0.9,
		type = "Two-Handed",
		rarity = "Legendary"
	},
	["Shadow Blades"] = {
		damage = 22,
		speed = 1.0,
		type = "Dual-Wield",
		rarity = "Legendary"
	}
}

-- Get weapon stats by name
function WeaponData.GetWeaponStats(weaponName)
	return WeaponData.Weapons[weaponName]
end

-- Get all weapons of a specific type
function WeaponData.GetWeaponsByType(weaponType)
	local weapons = {}
	for name, stats in pairs(WeaponData.Weapons) do
		if stats.type == weaponType then
			weapons[name] = stats
		end
	end
	return weapons
end

return WeaponData
