local WeaponData = {}

-- Weapon definitions with their attributes
WeaponData.Weapons = {
    ["Twig"] = {
		damage = 5,
		speed = 1.4,
		imageId = "rbxassetid://127490675569703",
		type = "One-Handed",
		rarity = "Common",
		levelRequirement = 1,
		itemType = "weapon",
		Description = "\"A small, twig.\"",
		Price = 25
	},
	["Wooden Sword"] = {
		damage = 8,
		speed = 1.4,
		imageId = "rbxassetid://111528850194920",
		type = "One-Handed",
		rarity = "Uncommon",
		levelRequirement = 10,
		itemType = "weapon",
		Description = "\"A basic wooden sword.\"",
		Price = 50
	},
	["Plastic Sword"] = {
		damage = 10,
		speed = 1.4,
		imageId = "rbxassetid://127720248767523",
		type = "One-Handed",
		rarity = "Rare",
		levelRequirement = 15,
		itemType = "weapon",
		Description = "\"A sturdy plastic sword.\"",
		Price = 125
	},
	["Stone Sword"] = {
		damage = 20,
		speed = 1.4,
		imageId = "rbxassetid://127720248767523",
		type = "One-Handed",
		rarity = "Rare",
		levelRequirement = 20,
		itemType = "weapon",
		Description = "\"A heavy stone sword.\"",
		Price = 500
	},
	["Iron Sword"] = {
		damage = 30,
		speed = 1.4,
		imageId = "rbxassetid://127720248767523",
		type = "One-Handed",
		rarity = "Epic",
		levelRequirement = 25,
		itemType = "weapon",
		Description = "\"A sharp iron sword.\"",
		Price = 1000
	},
	["Grimleaf Sword"] = {
		damage = 50,
		speed = 1.4,
		imageId = "rbxassetid://127720248767523",
		type = "One-Handed",
		rarity = "Legendary",
		levelRequirement = 1,
		itemType = "weapon",
		Description = "\"A sword forged from the leaves of Grimleaf.\"",
		Price = 5000
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
