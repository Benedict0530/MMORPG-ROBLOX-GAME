-- DungeonsData.lua
-- Place in ReplicatedStorage/Modules
-- Contains dungeon name, exp multiplier, gold multiplier, and story description

local DungeonsData = {
	["Grimleaf 1 Dungeon"] = {
		Name = "Grimleaf 1 Dungeon",
		ExpMultiplier = 4,
		GoldMultiplier = 3,
		Story = "Deep within Grimleaf Forest lies a dungeon filled with ancient secrets and powerful foes. Only the bravest adventurers dare to enter.",
		EntryLevelRequirement = 1,
		EntryItemRequirement = "Gloop Spike",
		TimeLimitMinutes = 30,
		OutMap = "Grimleaf 1",
		OutSpawn = "DungeonExitSpawn",
		AllowPVP = true,
		DropsText = [[
Dungeon Drops
- Grimleaf Sword
- Wind Orb
- Normal Orb
- Fire Orb
- Water Orb
- Stone Armor Helmet
- Stone Armor Suit
- Stone Armor Legs
- Osmium Armor Helmet
- Osmium Armor Suit
- Osmium Armor Legs
- Red Osmium Armor Helmet
- Red Osmium Armor Suit
- Red Osmium Armor Legs
- Earth Orb
- Lightning Orb
- Dark Orb
- Light Orb
- Shadow Orb
- Radiant Orb
]],
	},
	["Frozen Cavern"] = {
		Name = "Frozen Cavern",
		ExpMultiplier = 2.5,
		GoldMultiplier = 2.0,
		Story = "The Frozen Cavern is a chilling maze of ice and danger, where only the strongest survive the cold and the monsters within.",
		EntryLevelRequirement = 20,
		EntryItemRequirement = "Ice Key",
		TimeLimitMinutes = 30
	},
	-- Add more dungeons as needed
}

return DungeonsData
