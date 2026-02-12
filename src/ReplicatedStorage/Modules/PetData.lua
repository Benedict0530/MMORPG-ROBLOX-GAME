local PetData = {
	["Gloop Crusher Pet"] = {
		Name = "Companion Wolf",
		IdleAnimationId = "rbxassetid://72661521565750",
		WalkAnimationId = "rbxassetid://93147234083168",
		StatBonuses = {
			Health = 50,
			Damage = 10,
			Defense = 5
		},
		Description = "A loyal wolf companion that fights by your side"
	},
	
	["Spirit Fox"] = {
		Name = "Spirit Fox",
		IdleAnimationId = "rbxassetid://0000000000", -- Replace with actual animation ID
		WalkAnimationId = "rbxassetid://0000000000", -- Replace with actual animation ID
		StatBonuses = {
			Health = 30,
			Damage = 15,
			ManaRegen = 2
		},
		Description = "A mystical fox that enhances magical abilities"
	},
	
	["Stone Golem"] = {
		Name = "Stone Golem",
		IdleAnimationId = "rbxassetid://0000000000", -- Replace with actual animation ID
		WalkAnimationId = "rbxassetid://0000000000", -- Replace with actual animation ID
		StatBonuses = {
			Health = 100,
			Defense = 20,
			Damage = 5
		},
		Description = "A sturdy golem that provides exceptional defense"
	},
}

-- Get pet data by name
function PetData:GetPetData(petName)
	return self[petName]
end

-- Get all pet names
function PetData:GetAllPetNames()
	local names = {}
	for petName, _ in pairs(self) do
		if type(self[petName]) == "table" then
			table.insert(names, petName)
		end
	end
	return names
end

-- Check if pet exists
function PetData:PetExists(petName)
	return self[petName] ~= nil and type(self[petName]) == "table"
end

return PetData
