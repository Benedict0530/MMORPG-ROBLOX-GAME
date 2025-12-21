-- EnemyStatsDataStore.server.lua
-- Universal DataStore for enemy stats (Health, Experience, Money, Drops)

local DataStoreService = game:GetService("DataStoreService")
local enemyStatsStore = DataStoreService:GetDataStore("EnemyStats")

-- Example default stats for enemies
local DEFAULT_ENEMY_STATS = {
    ["Gloop Crusher"] = {
        Health = 30,
        Attack = 1,
        Experience = 10,
        Money = 1,
        Drops = {"SlimeBall", "GloopEssence","Twig"}
    },
    ["Slime"] = {
        Health = 10,
        Attack = 1,
        Experience = 2,
        Money = 2,
        Drops = {"SlimeBall"}
    }
    -- Add more enemies here
}

-- Save or update stats for an enemy type
local function saveEnemyStats(enemyName, stats)
    pcall(function()
        enemyStatsStore:SetAsync(enemyName, stats)
    end)
end

-- Load stats for an enemy type (returns default if not found)
local function loadEnemyStats(enemyName)
    local stats
    local success, err = pcall(function()
        stats = enemyStatsStore:GetAsync(enemyName)
    end)
    if success and stats then
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
