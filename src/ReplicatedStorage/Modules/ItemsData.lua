-- ItemsData.lua
-- Place in ReplicatedStorage/Modules
-- Contains items for dungeon entry, type questItem, with Name and Description

local ItemsData = {
    ["Gloop Spike"] = {
        Name = "Gloop Spike",
        Type = "questItem",
        Description = "A rare spike dropped by Gloop monsters. Used to unlock the Grimleaf 1 Dungeon."
    },
    ["Ice Key"] = {
        Name = "Ice Key",
        Type = "questItem",
        Description = "A mystical key forged from enchanted ice. Required to enter the Frozen Cavern."
    },
    -- Add more dungeon entry items as needed
}

return ItemsData
