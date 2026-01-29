-- ShopHandler.lua
-- Handles buying and selling items on the server

local ShopHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")


local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
local OrbData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrbData"))
local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
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


-- Helper: Get buy and sell price from WeaponData or ArmorData
local function getItemPrices(itemName)
    local weaponStats = WeaponData.GetWeaponStats(itemName)
    if weaponStats and weaponStats.Price then
        local buy = weaponStats.Price
        local sell = math.floor(buy * 0.4)
        return {buy = buy, sell = sell, itemType = "weapon"}
    end
    local armorStats = ArmorData[itemName]
    if armorStats and armorStats.Price then
        local buy = armorStats.Price
        local sell = math.floor(buy * 0.4)
        return {buy = buy, sell = sell, itemType = "armor"}
    end
    return nil
end

-- Helper: Get selling price for orbs
local function getOrbSellingPrice(orbName)
    -- Orb selling prices: Normal = 0, then 10k, 20k, 30k, 40k, 50k, 60k, 70k, 80k, 90k
    local orbPrices = {
        ["Normal Orb"] = 0,
        ["Fire Orb"] = 10000,
        ["Wind Orb"] = 20000,
        ["Water Orb"] = 30000,
        ["Earth Orb"] = 40000,
        ["Lightning Orb"] = 50000,
        ["Dark Orb"] = 60000,
        ["Light Orb"] = 70000,
        ["Shadow Orb"] = 80000,
        ["Radiant Orb"] = 90000
    }
    return orbPrices[orbName] or 0
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
    
    -- Try to get prices from weapons, armors, then orbs
    local prices = getItemPrices(itemName)
    local isOrb = false
    if not prices then
        -- Check if it's an orb
        if OrbData.GetOrbData(itemName) then
            isOrb = true
            prices = {buy = 0, sell = getOrbSellingPrice(itemName), itemType = "orb"}
        else
            return
        end
    end
    if action == "Buy" then
        local price = prices.buy
        if money.Value >= price then
            -- Generate unique ID for the item
            local itemId = generateUniqueItemId(itemName, player)
            -- Add item to inventory with unique ID and itemType if armor/weapon/orb
            local ok, newId = InventoryManager.AddItem(player, itemName, prices.itemType)
            -- Deduct money after item is added
            if SFXEvent then
                SFXEvent:FireClient(player, "Sell")
            end
            if ok then
                money.Value = money.Value - price
                UnifiedDataStoreManager.SaveMoney(player, false)
                inventoryChangedEvent:FireClient(player)
            end
        end
    elseif action == "Sell" then
        local price = prices.sell
        -- Remove by itemId, and prevent selling equipped item
        local stats = player:FindFirstChild("Stats")
        local equippedId = nil
        local equippedOrbId = nil
        local equippedArmorIds = {}
        if stats then
            -- Check equipped weapons
            local equippedFolder = stats:FindFirstChild("Equipped")
            if equippedFolder and equippedFolder:IsA("Folder") then
                local idValue = equippedFolder:FindFirstChild("id")
                if idValue then
                    equippedId = idValue.Value
                end
            end
            -- Check equipped orbs
            local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
            if equippedOrbFolder and equippedOrbFolder:IsA("Folder") then
                local idValue = equippedOrbFolder:FindFirstChild("id")
                if idValue then
                    equippedOrbId = idValue.Value
                end
            end
            -- Check equipped armors (Helmet, Suit, Legs)
            for _, armorSlot in ipairs({"EquippedHelmet", "EquippedSuit", "EquippedLegs", "EquippedShoes"}) do
                local slotFolder = stats:FindFirstChild(armorSlot)
                if slotFolder and slotFolder:IsA("Folder") then
                    local idValue = slotFolder:FindFirstChild("id")
                    if idValue then
                        table.insert(equippedArmorIds, idValue.Value)
                    end
                end
            end
            inventoryChangedEvent:FireClient(player)
        end
        -- Prevent selling equipped weapons
        if itemId and equippedId and itemId == equippedId then
            return
        end
        -- Prevent selling equipped orbs
        if itemId and equippedOrbId and itemId == equippedOrbId then
            return
        end
        -- Prevent selling equipped armors
        for _, armorId in ipairs(equippedArmorIds) do
            if itemId and armorId and itemId == armorId then
                return
            end
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
            UnifiedDataStoreManager.SaveMoney(player, false)
        end
    end
end)

return ShopHandler
