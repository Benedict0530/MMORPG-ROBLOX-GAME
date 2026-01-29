local OrbData = {}

-- Spirit Orb definitions (1 = 100%)
OrbData.Orbs = {
	       ["Normal Orb"] = {
		       chance = 0.23,
		       description = "A balanced orb that provides steady increases to all stats. Perfect for beginners.",
			       stats = {
				       Attack = 1.10,
				       CriticalChance = 1.05,
				       CriticalDamage = 1.05
			       }
	       },
	       ["Fire Orb"] = {
		       chance = 0.20,
		       description = "Harnesses the power of flames. Greatly increases attack power and physical resilience.",
			       stats = {
				       Attack = 1.25,
				       CriticalChance = 1.10,
				       CriticalDamage = 1.15
			       }
	       },

	       ["Water Orb"] = {
		       chance = 0.18,
		       description = "Controls the flow of water. Focuses on defense and crit, ideal for spellcasters.",
			       stats = {
				       Attack = 1.15,
				       CriticalChance = 1.08,
				       CriticalDamage = 1.12
			       }
	       },

	       ["Wind Orb"] = {
		       chance = 0.15,
		       description = "Channels the speed of wind. Excellent for high-speed combat and crits.",
			       stats = {
				       Attack = 1.20,
				       Dexterity = 1.50,
				       CriticalChance = 1.20,
				       CriticalDamage = 1.10
			       }
	       },

	       ["Earth Orb"] = {
		       chance = 0.12,
		       description = "Draws strength from the earth. Provides exceptional defense and crit damage.",
			       stats = {
				       Attack = 1.15,
				       Dexterity = 1.05,
				       CriticalChance = 1.05,
				       CriticalDamage = 1.20
			       }
	       },

	       ["Lightning Orb"] = {
		       chance = 0.10,
		       description = "Strikes with electrical energy. High attack, dexterity, and crit chance.",
			       stats = {
				       Attack = 1.40,
				       Dexterity = 1.50,
				       CriticalChance = 1.25,
				       CriticalDamage = 1.15
			       }
	       },

	       ["Dark Orb"] = {
		       chance = 0.09,
		       description = "Taps into shadow magic. Balanced power with exceptional crit damage.",
			       stats = {
				       Attack = 1.40,
				       CriticalChance = 1.10,
				       CriticalDamage = 1.25
			       }
	       },

	       ["Light Orb"] = {
		       chance = 0.08,
		       description = "Radiates pure light energy. Focuses on defense and crits.",
			       stats = {
				       Attack = 1.30,
				       CriticalChance = 1.18,
				       CriticalDamage = 1.18
			       }
	       },

	       ["Shadow Orb"] = {
		       chance = 0.05,
		       description = "A rare orb of shadow and darkness. Grants incredible speed, attack power, and crits.",
			       stats = {
				       Attack = 1.50,
				       Dexterity = 1.80,
				       CriticalChance = 1.30,
				       CriticalDamage = 1.30
			       }
	       },

	       ["Radiant Orb"] = {
		       chance = 0.03,
		       description = "The most powerful orb. Provides legendary increases to all stats and crits equally.",
			       stats = {
				       Attack = 1.60,
				       CriticalChance = 1.40,
				       CriticalDamage = 1.40
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
