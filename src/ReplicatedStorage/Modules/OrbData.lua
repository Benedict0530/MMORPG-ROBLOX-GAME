local OrbData = {}

-- Spirit Orb definitions (1 = 100%)
OrbData.Orbs = {
		       ["Normal Orb"] = {
			       chance = 0.23,
			       description = "A balanced orb that provides steady increases to all stats. Perfect for beginners.",
				       stats = {
					       Attack = 2.20,
					       CriticalChance = 2.10,
					       CriticalDamage = 2.10
				       }
		       },
		       ["Fire Orb"] = {
			       chance = 0.20,
			       description = "Harnesses the power of flames. Greatly increases attack power and physical resilience.",
				       stats = {
					       Attack = 2.50,
					       CriticalChance = 2.20,
					       CriticalDamage = 2.30
				       }
		       },

		       ["Water Orb"] = {
			       chance = 0.18,
			       description = "Controls the flow of water. Focuses on defense and crit, ideal for spellcasters.",
				       stats = {
					       Attack = 2.30,
					       CriticalChance = 2.16,
					       CriticalDamage = 2.24
				       }
		       },

		       ["Wind Orb"] = {
			       chance = 0.15,
			       description = "Channels the speed of wind. Excellent for high-speed combat and crits.",
				       stats = {
					       Attack = 2.40,
					       Dexterity = 3.00,
					       CriticalChance = 2.40,
					       CriticalDamage = 2.20
				       }
		       },

		       ["Earth Orb"] = {
			       chance = 0.12,
			       description = "Draws strength from the earth. Provides exceptional defense and crit damage.",
				       stats = {
					       Attack = 2.30,
					       Dexterity = 2.10,
					       CriticalChance = 2.10,
					       CriticalDamage = 2.40
				       }
		       },

		       ["Lightning Orb"] = {
			       chance = 0.10,
			       description = "Strikes with electrical energy. High attack, dexterity, and crit chance.",
				       stats = {
					       Attack = 2.80,
					       Dexterity = 3.00,
					       CriticalChance = 2.50,
					       CriticalDamage = 2.30
				       }
		       },

		       ["Dark Orb"] = {
			       chance = 0.09,
			       description = "Taps into shadow magic. Balanced power with exceptional crit damage.",
				       stats = {
					       Attack = 2.80,
					       CriticalChance = 2.20,
					       CriticalDamage = 2.50
				       }
		       },

		       ["Light Orb"] = {
			       chance = 0.08,
			       description = "Radiates pure light energy. Focuses on defense and crits.",
				       stats = {
					       Attack = 2.60,
					       CriticalChance = 2.36,
					       CriticalDamage = 2.36
				       }
		       },

		       ["Shadow Orb"] = {
			       chance = 0.05,
			       description = "A rare orb of shadow and darkness. Grants incredible speed, attack power, and crits.",
				       stats = {
					       Attack = 3.00,
					       Dexterity = 3.60,
					       CriticalChance = 2.60,
					       CriticalDamage = 2.60
				       }
		       },

		       ["Radiant Orb"] = {
			       chance = 0.03,
			       description = "The most powerful orb. Provides legendary increases to all stats and crits equally.",
				       stats = {
					       Attack = 3.20,
					       CriticalChance = 2.80,
					       CriticalDamage = 2.80
				       }
		       }
}

-- Get orb data by name
function OrbData.GetOrbData(orbName)
	return OrbData.Orbs[orbName]
end

-- Roll random orb
function OrbData.RollRandomOrb()
	local roll = math.random()
	local current = 0

	for name, data in pairs(OrbData.Orbs) do
		current += data.chance
		if roll <= current then
			return name, data
		end
	end
end

return OrbData
