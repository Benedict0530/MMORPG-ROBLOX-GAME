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
            { itemName = "Twig", chance = 0.3 }
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
            { itemName = "Iron Sword", chance = 0.01 }
        }
    }
    -- Add more enemies here
}

-- Save or update stats for an enemy type
local function saveEnemyStats(enemyName, stats)
    -- Delegate to UnifiedDataStoreManager
    UnifiedDataStoreManager.SaveEnemyStats(enemyName, stats)
end

-- Load stats for an enemy type (returns default if not found)
local function loadEnemyStats(enemyName)
    -- Delegate to UnifiedDataStoreManager
    local stats = UnifiedDataStoreManager.LoadEnemyStats(enemyName)
    if stats then
        return stats
    else
        return DEFAULT_ENEMY_STATS[enemyName]
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
