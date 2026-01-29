-- EnemyStatsDataStore.lua
-- Enemy stats management - now delegates saving to UnifiedDataStoreManager

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- Example default stats for enemies
-- Drops format: { itemName = "Twig", chance = 0.5 } means 50% chance to drop
local DEFAULT_ENEMY_STATS = {
    ["Gloop Crusher"] = {
        Health = 15,
        Attack = 5,
        Experience = 1,
        Money = 1,
        Drops = {
            { itemName = "Wooden Sword", chance = 0.1 },  -- 10% chance to drop WoodenSword
            { itemName = "Twig", chance = 0.3 },
            { itemName = "Brown Armor Helmet", chance = 0.02 }, -- 2% chance
            { itemName = "Brown Armor Suit", chance = 0.01 },   -- 1% chance
            { itemName = "Brown Armor Legs", chance = 0.015 },  -- 1.5% chance
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["Red Gloop Crusher"] = {
        Health = 180,
        Attack = 15,
        Experience = 5,
        Money = 5,
        Drops = {
            { itemName = "Wooden Sword", chance = 0.25 },  -- 25% chance to drop WoodenSword
            { itemName = "Plastic Sword", chance = 0.02 },        
            { itemName = "Iron Sword", chance = 0.01 },
            { itemName = "Brown Armor Helmet", chance = 0.05 }, -- 5% chance
            { itemName = "Brown Armor Suit", chance = 0.03 },   -- 3% chance
            { itemName = "Brown Armor Legs", chance = 0.04 },  -- 4% chance
            { itemName = "Iron Armor Helmet", chance = 0.01 },
            { itemName = "Iron Armor Suit", chance = 0.008 },
            { itemName = "Iron Armor Legs", chance = 0.009 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["Ice Gloop Crusher"] = {
        Health = 350,
        Attack = 25,
        Experience = 10,
        Money = 10,
        Drops = {
            { itemName = "Stone Sword", chance = 0.1 },  -- 10% chance to drop Stone Sword
            { itemName = "Iron Sword", chance = 0.05 },
            { itemName = "Brown Armor Helmet", chance = 0.1 }, -- 10% chance
            { itemName = "Brown Armor Suit", chance = 0.07 },   -- 7% chance
            { itemName = "Brown Armor Legs", chance = 0.08 },  -- 8% chance
            { itemName = "Iron Armor Helmet", chance = 0.02 },
            { itemName = "Iron Armor Suit", chance = 0.015 },
            { itemName = "Iron Armor Legs", chance = 0.017 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["Giant Gloop Crusher"] = {
        Health = 1000,
        Attack = 50,
        Experience = 100,
        Money = 100,
        SpawnDelay = 600, -- 10 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 0.01 },  -- 1% chance to drop Grimleaf Sword
            { itemName = "Iron Sword", chance = 0.5 },
            { itemName = "Wooden Sword", chance = 1},
            { itemName = "Iron Armor Helmet", chance = 0.03 },
            { itemName = "Iron Armor Suit", chance = 0.025 },
            { itemName = "Iron Armor Legs", chance = 0.027 },
            { itemName = "Stone Armor Helmet", chance = 0.01 },
            { itemName = "Stone Armor Suit", chance = 0.008 },
            { itemName = "Stone Armor Legs", chance = 0.009 },
            { itemName = "Osmium Armor Helmet", chance = 0.002 },
            { itemName = "Osmium Armor Suit", chance = 0.0015 },
            { itemName = "Osmium Armor Legs", chance = 0.0017 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["Red Giant Gloop Crusher"] = {
        Health = 2000,
        Attack = 100,
        Experience = 200,
        Money = 200,
        SpawnDelay = 600, -- 10 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 0.5 },  -- 50% chance to drop Grimleaf Sword
            { itemName = "Iron Sword", chance = 0.75 },
            { itemName = "Plastic Sword", chance = 1},
            { itemName = "Iron Armor Helmet", chance = 0.04 },
            { itemName = "Iron Armor Suit", chance = 0.03 },
            { itemName = "Iron Armor Legs", chance = 0.035 },
            { itemName = "Stone Armor Helmet", chance = 0.012 },
            { itemName = "Stone Armor Suit", chance = 0.01 },
            { itemName = "Stone Armor Legs", chance = 0.011 },
            { itemName = "Osmium Armor Helmet", chance = 0.003 },
            { itemName = "Osmium Armor Suit", chance = 0.002 },
            { itemName = "Osmium Armor Legs", chance = 0.0022 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["Ice Giant Gloop Crusher"] = {
        Health = 3000,
        Attack = 150,
        Experience = 300,
        Money = 300,
        SpawnDelay = 600, -- 10 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 0.75 },  -- 75% chance to drop Grimleaf Sword
            { itemName = "Iron Sword", chance = 1 },
            { itemName = "Iron Armor Helmet", chance = 0.05 },
            { itemName = "Iron Armor Suit", chance = 0.04 },
            { itemName = "Iron Armor Legs", chance = 0.045 },
            { itemName = "Stone Armor Helmet", chance = 0.015 },
            { itemName = "Stone Armor Suit", chance = 0.012 },
            { itemName = "Stone Armor Legs", chance = 0.013 },
            { itemName = "Osmium Armor Helmet", chance = 0.004 },
            { itemName = "Osmium Armor Suit", chance = 0.003 },
            { itemName = "Osmium Armor Legs", chance = 0.0035 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["3 Head Green Gloop"] = {
        Health = 5000,
        Attack = 50,
        Experience = 500,
        Money = 500,
        SpawnDelay = 5, -- 20 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 0.75 },
            { itemName = "Wind Orb", chance = 0.01 },
            { itemName = "Normal Orb", chance = 0.03 },
            { itemName = "Fire Orb", chance = 0.02 },
            { itemName = "Water Orb", chance = 0.02 },
            { itemName = "Stone Armor Helmet", chance = 0.02 },
            { itemName = "Stone Armor Suit", chance = 0.018 },
            { itemName = "Stone Armor Legs", chance = 0.019 },
            { itemName = "Osmium Armor Helmet", chance = 0.008 },
            { itemName = "Osmium Armor Suit", chance = 0.007 },
            { itemName = "Osmium Armor Legs", chance = 0.0075 },
            { itemName = "Red Osmium Armor Helmet", chance = 0.002 },
            { itemName = "Red Osmium Armor Suit", chance = 0.0015 },
            { itemName = "Red Osmium Armor Legs", chance = 0.0017 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["3 Head Red Gloop"] = {
        Health = 8000,
        Attack = 100,
        Experience = 800,
        Money = 800,
        SpawnDelay = 1200, -- 20 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 0.1 },  -- 10% chance to drop Grimleaf Sword
            { itemName = "Stone Armor Helmet", chance = 0.025 },
            { itemName = "Stone Armor Suit", chance = 0.022 },
            { itemName = "Stone Armor Legs", chance = 0.023 },
            { itemName = "Osmium Armor Helmet", chance = 0.01 },
            { itemName = "Osmium Armor Suit", chance = 0.009 },
            { itemName = "Osmium Armor Legs", chance = 0.0095 },
            { itemName = "Red Osmium Armor Helmet", chance = 0.003 },
            { itemName = "Red Osmium Armor Suit", chance = 0.0025 },
            { itemName = "Red Osmium Armor Legs", chance = 0.0027 },
            { itemName = "Wind Orb", chance = 0.01 },
            { itemName = "Fire Orb", chance = 0.025 },
            { itemName = "Water Orb", chance = 0.025 },
            { itemName = "Earth Orb", chance = 0.02 },
            { itemName = "Lightning Orb", chance = 0.01 },
            { itemName = "Dark Orb", chance = 0.008 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    ["3 Head Ice Gloop"] = {
        Health = 12000,
        Attack = 150,
        Experience = 1200,
        Money = 1200,
        SpawnDelay = 1200, -- 20 minutes
        Drops = {
            { itemName = "Grimleaf Sword", chance = 1 },
            { itemName = "Stone Armor Helmet", chance = 0.03 },
            { itemName = "Stone Armor Suit", chance = 0.025 },
            { itemName = "Stone Armor Legs", chance = 0.027 },
            { itemName = "Osmium Armor Helmet", chance = 0.012 },
            { itemName = "Osmium Armor Suit", chance = 0.011 },
            { itemName = "Osmium Armor Legs", chance = 0.0115 },
            { itemName = "Red Osmium Armor Helmet", chance = 0.004 },
            { itemName = "Red Osmium Armor Suit", chance = 0.003 },
            { itemName = "Red Osmium Armor Legs", chance = 0.0035 },
            { itemName = "Wind Orb", chance = 0.01 },
            { itemName = "Fire Orb", chance = 0.03 },
            { itemName = "Water Orb", chance = 0.03 },
            { itemName = "Earth Orb", chance = 0.025 },
            { itemName = "Lightning Orb", chance = 0.02 },
            { itemName = "Dark Orb", chance = 0.015 },
            { itemName = "Light Orb", chance = 0.01 },
            { itemName = "Shadow Orb", chance = 0.005 },
            { itemName = "Radiant Orb", chance = 0.002 },
            { itemName = "Gloop Spike", chance = 0.05 },  -- 5% chance to drop Gloop Spike
        }
    },
    -- Add more enemies here
}

-- Save or update stats for an enemy type
local function saveEnemyStats(enemyName, stats)
    -- Delegate to UnifiedDataStoreManager
    UnifiedDataStoreManager.SaveEnemyStats(enemyName, stats)
end

-- Load stats for an enemy type (returns default if not found)

-- In-memory cache for enemy stats (per server session)
local enemyStatsCache = {}

local function loadEnemyStats(enemyName)
    -- Check cache first
    if enemyStatsCache[enemyName] then
        return enemyStatsCache[enemyName]
    end
    -- Delegate to UnifiedDataStoreManager
    local stats = UnifiedDataStoreManager.LoadEnemyStats(enemyName)
    if stats then
        enemyStatsCache[enemyName] = stats
        return stats
    else
        -- Fallback to default, but also cache it
        local defaultStats = DEFAULT_ENEMY_STATS[enemyName]
        if defaultStats then
            enemyStatsCache[enemyName] = defaultStats
        end
        return defaultStats
    end
end

-- Initialize DataStore with default stats if missing
for enemyName, stats in pairs(DEFAULT_ENEMY_STATS) do
    local existing = loadEnemyStats(enemyName)
    if not existing then
        saveEnemyStats(enemyName, stats)
    end
end

return {
    saveEnemyStats = saveEnemyStats,
    loadEnemyStats = loadEnemyStats
}
