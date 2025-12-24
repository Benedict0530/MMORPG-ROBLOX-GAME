local WeaponData = {}

-- Weapon definitions with their attributes
WeaponData.Weapons = {
    ["Twig"] = {
		damage = 5,
		speed = 0.5,
		imageId = "rbxassetid://127490675569703",
		type = "One-Handed",
		rarity = "Common",
		levelRequirement = 1,
		Description = "\"A small, twig.\""
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
