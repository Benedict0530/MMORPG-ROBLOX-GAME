-- ShopHandler.lua
-- Handles buying and selling items on the server

local ShopHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")


local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")

-- RemoteEvent for shop actions
local shopEvent = ReplicatedStorage:FindFirstChild("ShopEvent")
if not shopEvent then
    shopEvent = Instance.new("RemoteEvent")
    shopEvent.Name = "ShopEvent"
    shopEvent.Parent = ReplicatedStorage
end

local SFXEvent = ReplicatedStorage:FindFirstChild("SFXEvent")

-- Helper: Get player's money stat
local function getMoneyStat(player)
    local stats = player:FindFirstChild("Stats")
    return stats and stats:FindFirstChild("Money")
end


-- Helper: Get buy and sell price from WeaponData
local function getItemPrices(itemName)
    local weaponStats = WeaponData.GetWeaponStats(itemName)
    if not weaponStats or not weaponStats.Price then return nil end
    local buy = weaponStats.Price
    local sell = math.floor(buy * 0.4)
    return {buy = buy, sell = sell}
end


local shopDebounce = {} -- [userId] = true/false

local function generateUniqueItemId(itemName, player)
    local userId = player and player.UserId or "0"
    return itemName .. "_" .. tostring(userId) .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))
end

shopEvent.OnServerEvent:Connect(function(player, action, itemName, itemId)
    local userId = player.UserId
    if shopDebounce[userId] then return end
    shopDebounce[userId] = true
    task.delay(0.5, function() shopDebounce[userId] = false end)

    local money = getMoneyStat(player)
    if not money or not itemName then return end
    local prices = getItemPrices(itemName)
    if not prices then return end
    if action == "Buy" then
        local price = prices.buy
        if money.Value >= price then
            -- Generate unique ID for the item
            local itemId = generateUniqueItemId(itemName, player)
            -- Add item to inventory with unique ID
            local ok, newId = InventoryManager.AddItem(player, itemName)
            -- Deduct money after item is added
            if SFXEvent then
                SFXEvent:FireClient(player, "Sell")
            end
            if ok then
                money.Value = money.Value - price
                UnifiedDataStoreManager.SaveMoney(player, true)
                inventoryChangedEvent:FireClient(player)
            end
        end
    elseif action == "Sell" then
        local price = prices.sell
        -- Remove by itemId, and prevent selling equipped item
        local stats = player:FindFirstChild("Stats")
        local equippedId = nil
        if stats then
            local equippedFolder = stats:FindFirstChild("Equipped")
            if equippedFolder and equippedFolder:IsA("Folder") then
                local idValue = equippedFolder:FindFirstChild("id")
                if idValue then
                    equippedId = idValue.Value
                    inventoryChangedEvent:FireClient(player)
                end
            end
        end
        if itemId and equippedId and itemId == equippedId then
            -- Prevent selling equipped item
            return
        end
        local removed = false
        if itemId then
            removed = InventoryManager.RemoveItem(player, itemId)
        end
        if SFXEvent then
            SFXEvent:FireClient(player, "Sell")
        end
        if removed then
            money.Value = money.Value + price
            UnifiedDataStoreManager.SaveMoney(player, true)
        end
    end
end)

return ShopHandler
