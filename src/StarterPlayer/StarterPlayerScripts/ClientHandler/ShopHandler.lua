local ShopHandler = {}
-- Helper to format numbers with commas (e.g., 1000 -> 1,000)
local function formatNumberWithCommas(n)
    local str = tostring(n)
    local k
    while true do
        str, k = string.gsub(str, "^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return str
end
-- ShopHandler.client.lua
-- Handles shop UI and sends buy/sell requests to the server

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CameraFocusModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraFocusModule"))


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")
local gameGuiFrame = gameGui:WaitForChild("Frame")
local shopSelectionFrame = gameGuiFrame:WaitForChild("Shop Selection")
local shopBuy = shopSelectionFrame:WaitForChild("BuyButton")
local shopSell = shopSelectionFrame:WaitForChild("SellButton")
local ShopUI = gameGuiFrame:WaitForChild("ShopUI")
local shopUITitle = ShopUI:WaitForChild("Title")
local closeShopButton = ShopUI:WaitForChild("CloseButton")

local SellUI = gameGuiFrame:WaitForChild("SellUI")

local shopSellTitle = SellUI:WaitForChild("Title")
local closeSellButton = SellUI:WaitForChild("CloseButton")
local sellScrollingFrame = SellUI:WaitForChild("Background"):WaitForChild("ScrollingFrame", 5)
local sellItemTemplate = sellScrollingFrame:WaitForChild("Item", 5)
sellItemTemplate.Visible = false

local Shops = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shops"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
local OrbData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrbData"))
local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))

local shopScrollingFrame = ShopUI:WaitForChild("Background"):WaitForChild("ScrollingFrame", 5)
local shopItemTemplate = shopScrollingFrame:WaitForChild("Item", 5)
shopItemTemplate.Visible = false
local shopItemStats = ShopUI:WaitForChild("Background"):WaitForChild("ItemStats", 5)
if shopItemStats then shopItemStats.Visible = false end

local shopEvent = ReplicatedStorage:WaitForChild("ShopEvent")


local ShopHandler = {}

-- Helper: Get orb selling price (DISPLAY ONLY - actual prices validated on server)
local function getOrbSellingPrice(orbName)
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

-- Hide shop UI when player dies
local function setupDeathHideShopUI(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            shopSelectionFrame.Visible = false
            ShopUI.Visible = false
            SellUI.Visible = false
            CameraFocusModule.RestoreDefault()
            currentShopNpc = nil
        end)
    end
end

if player.Character then
    setupDeathHideShopUI(player.Character)
end
player.CharacterAdded:Connect(function(newCharacter)
    setupDeathHideShopUI(newCharacter)
    CameraFocusModule.HandleCharacterRespawn(newCharacter)
end)

-- Call this function to buy an item
function ShopHandler.BuyItem(itemName)
    shopEvent:FireServer("Buy", itemName)
end

-- Call this function to sell an item
function ShopHandler.SellItem(itemName, itemId)
    shopEvent:FireServer("Sell", itemName, itemId)
end


-- Helper to clear shop items

local function clearShopItems()
    for _, child in ipairs(shopScrollingFrame:GetChildren()) do
        if child ~= shopItemTemplate and child.Name:match("^Item_") then
            child:Destroy()
        end
    end
end

local function clearSellItems()
    for _, child in ipairs(sellScrollingFrame:GetChildren()) do
        if child ~= sellItemTemplate and child.Name:match("^Item_") then
            child:Destroy()
        end
    end
end
-- Helper to get player inventory from server
local function getPlayerInventory()
    local inventoryEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
    if inventoryEvent and inventoryEvent:IsA("RemoteFunction") then
        local success, result = pcall(function()
            return inventoryEvent:InvokeServer()
        end)
        if success and type(result) == "table" then
            return result
        end
    end
    return {}
end

-- Helper to get equipped item ids from player stats
local function getEquippedItemIds()
    local statsFolder = player:FindFirstChild("Stats")
    if not statsFolder then
        -- Wait indefinitely for Stats to appear
        while true do
            statsFolder = player:FindFirstChild("Stats")
            if statsFolder then break end
            player.ChildAdded:Wait()
        end
    end
    if not statsFolder then
        warn("[ShopHandler] Stats folder not found after waiting!")
        return
    end
    local equippedIds = {}
    if statsFolder then
        -- Weapon
        local equippedFolder = statsFolder:FindFirstChild("Equipped")
        if equippedFolder and equippedFolder:IsA("Folder") then
            local idValue = equippedFolder:FindFirstChild("id")
            if idValue and idValue:IsA("StringValue") then
                equippedIds[idValue.Value] = true
            end
        end
        -- Secondary Weapon
        local secondaryEquippedFolder = statsFolder:FindFirstChild("SecondaryEquipped")
        if secondaryEquippedFolder and secondaryEquippedFolder:IsA("Folder") then
            local idValue = secondaryEquippedFolder:FindFirstChild("id")
            if idValue and idValue:IsA("StringValue") then
                equippedIds[idValue.Value] = true
            end
        end
        -- Orb
        local equippedOrbFolder = statsFolder:FindFirstChild("EquippedOrb")
        if equippedOrbFolder and equippedOrbFolder:IsA("Folder") then
            local idValue = equippedOrbFolder:FindFirstChild("id")
            if idValue and idValue:IsA("StringValue") then
                equippedIds[idValue.Value] = true
            end
        end
        -- Armors (including shoes)
        for _, armorSlot in ipairs({"EquippedHelmet", "EquippedSuit", "EquippedLegs", "EquippedShoes"}) do
            local slotFolder = statsFolder:FindFirstChild(armorSlot)
            if slotFolder and slotFolder:IsA("Folder") then
                local idValue = slotFolder:FindFirstChild("id")
                if idValue and idValue:IsA("StringValue") then
                    equippedIds[idValue.Value] = true
                end
            end
        end
    end
    return equippedIds
end

-- Helper to create sell item UI
local sellItemStats = SellUI:FindFirstChild("Background") and SellUI.Background:FindFirstChild("ItemStats")
if sellItemStats then sellItemStats.Visible = false end

local sellButtonConn
local function createSellItem(item, index)
    local equippedIds = getEquippedItemIds()
    local isEquipped = (item.id and equippedIds[item.id])

    local itemClone = sellItemTemplate:Clone()
    itemClone.Name = "Item_" .. index
    itemClone.Visible = true
    itemClone.LayoutOrder = index

    local itemNameLabel = itemClone:FindFirstChild("Item Name")
    local itemImage = itemClone:FindFirstChild("Item Image")
    local sellButton = itemClone:FindFirstChild("SellButton")
    local priceLabel = itemClone:FindFirstChild("Price")

    if itemNameLabel and (itemNameLabel:IsA("TextLabel") or itemNameLabel:IsA("TextButton")) then
        itemNameLabel.Text = item.name
        if isEquipped then
            itemNameLabel.Text = item.name .. " (Equipped)"
            itemNameLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color for equipped
        end
    end
    if itemImage and itemImage:IsA("ImageLabel") then
        -- Replace image with ViewportFrame preview
        local viewport = Instance.new("ViewportFrame")
        viewport.Size = itemImage.Size
        viewport.Position = itemImage.Position
        viewport.AnchorPoint = itemImage.AnchorPoint
        viewport.BackgroundTransparency = 1
        viewport.Name = "ItemViewport"
        viewport.Parent = itemClone
        itemImage.Visible = false

        local for2dImageFolder = workspace:FindFirstChild("For2dImage")
        if for2dImageFolder then
            local tool = for2dImageFolder:FindFirstChild(item.name)
            if tool then
                local toolClone = tool:Clone()
                toolClone.Parent = viewport

                -- Lighting
                local light = Instance.new("PointLight")
                light.Brightness = 2
                light.Range = 16
                light.Color = Color3.new(1, 1, 1)
                local lightParent = nil
                if toolClone:IsA("Model") and toolClone.PrimaryPart then
                    lightParent = toolClone.PrimaryPart
                else
                    for _, child in ipairs(toolClone:GetDescendants()) do
                        if child:IsA("BasePart") then
                            lightParent = child
                            break
                        end
                    end
                end
                if lightParent then
                    light.Parent = lightParent
                end

                -- Camera setup
                local focusCFrame = nil
                local size = 2
                local foundModel = nil
                for _, child in ipairs(toolClone:GetChildren()) do
                    if child:IsA("Model") then
                        foundModel = child
                        break
                    end
                end
                if foundModel then
                    if foundModel.GetPivot then
                        focusCFrame = foundModel:GetPivot()
                    elseif foundModel.PrimaryPart then
                        focusCFrame = foundModel.PrimaryPart.CFrame
                    end
                    size = (foundModel:GetExtentsSize() or Vector3.new(2,2,2)).Magnitude
                else
                    for _, child in ipairs(toolClone:GetChildren()) do
                        if child:IsA("BasePart") then
                            focusCFrame = child.CFrame
                            size = child.Size.Magnitude
                            break
                        end
                    end
                end
                local camera = Instance.new("Camera")
                camera.FieldOfView = 35
                viewport.CurrentCamera = camera
                camera.Parent = viewport
                if focusCFrame then
                    local camDistance = size * 1.2
                    local camPos = focusCFrame.Position + Vector3.new(0, 0, camDistance)
                    camera.CFrame = CFrame.new(camPos, focusCFrame.Position)
                    camera.Focus = CFrame.new(focusCFrame.Position)
                else
                    camera.CFrame = CFrame.new(0, 0, 1)
                    camera.Focus = CFrame.new(0, 0, 0)
                end
            end
        end
    end
    if priceLabel then
        local weaponStats = WeaponData.GetWeaponStats(item.name)
        local orbStats = OrbData.GetOrbData(item.name)
        local armorStats = ArmorData[item.name]
        local price = 0
        if orbStats then
            price = getOrbSellingPrice(item.name)
        elseif weaponStats then
            price = weaponStats.Price and math.floor(weaponStats.Price * 0.4) or 0
        elseif armorStats then
            price = armorStats.Price and math.floor(armorStats.Price * 0.4) or 0
        end
        priceLabel.Text = "Sell: $" .. formatNumberWithCommas(price)
    end

    -- Hide or disable sell button for equipped item
    if sellButton then
        sellButton.Visible = not isEquipped
        sellButton.Active = not isEquipped
        if isEquipped then
            sellButton.AutoButtonColor = false
        end
    end

    itemClone.MouseButton1Click:Connect(function()
        if isEquipped then return end -- Prevent showing sell UI for equipped item
        if not sellItemStats then return end
        local statsDescription = sellItemStats:FindFirstChild("Description")
        if not statsDescription then return end
        local weaponStats = WeaponData.GetWeaponStats(item.name)
        local orbStats = OrbData.GetOrbData(item.name)
        local armorStats = ArmorData[item.name]
        local descText = ""
        if orbStats then
            -- Format orb description (matching inventory UI style)
            descText = item.name .. "\n"
            if orbStats.description then
                descText = descText .. "\n" .. orbStats.description .. "\n"
            end
            descText = descText .. "\n📊 Stat Bonuses:\n"
            if orbStats.stats then
                for statName, multiplier in pairs(orbStats.stats) do
                    local bonus = math.floor((multiplier - 1) * 100)
                    if bonus > 0 then
                        descText = descText .. "+" .. bonus .. "% " .. statName .. "\n"
                    end
                end
            end
            if orbStats.chance then
                descText = descText .. "\nDrop Rate: " .. tostring(math.floor(orbStats.chance * 100)) .. "%"
            end
            local sellingPrice = getOrbSellingPrice(item.name)
            descText = descText .. "\n\nSelling Price: $" .. formatNumberWithCommas(sellingPrice)
        elseif weaponStats then
            -- Format weapon description (matching inventory UI style)
            descText = item.name .. "\n"
            if weaponStats.Description then
                descText = descText .. "\n" .. weaponStats.Description .. "\n"
            end
            descText = descText .. "\n⚔️ Weapon Stats:\n"
            descText = descText .. "Damage: " .. tostring(weaponStats.damage) .. "\n"
            descText = descText .. "Level Requirement: " .. tostring(weaponStats.levelRequirement or "N/A") .. "\n"
            local price = weaponStats.Price or 0
            local sellingPrice = math.floor(price * 0.4)
            descText = descText .. "Selling Price: $" .. formatNumberWithCommas(sellingPrice)
        elseif armorStats then
            -- Format armor description (matching inventory UI style)
            descText = item.name .. "\n"
            if armorStats.Description then
                descText = descText .. "\n" .. armorStats.Description .. "\n"
            end
            descText = descText .. "\n🛡️ Armor Stats:\n"
            descText = descText .. "Type: " .. tostring(armorStats.Type or "N/A") .. "\n"
            descText = descText .. "Defense: " .. tostring(armorStats.Defense or "N/A") .. "\n"
            local price = armorStats.Price or 0
            local sellingPrice = math.floor(price * 0.4)
            descText = descText .. "Selling Price: $" .. formatNumberWithCommas(sellingPrice)
        end
        statsDescription.Text = descText
        local sellButtonStats = sellItemStats:FindFirstChild("SellButton")
        if sellButtonStats then
            sellButtonStats.Visible = true
            if sellButtonConn then
                sellButtonConn:Disconnect()
            end
            sellButtonConn = sellButtonStats.MouseButton1Click:Connect(function()
                ShopHandler.SellItem(item.name, item.id)
                itemClone:Destroy()
                sellItemStats.Visible = false
            end)
        end
        sellItemStats.Visible = true
    end)

    itemClone.Parent = sellScrollingFrame
    return itemClone
end

local function populateSellUI()
    clearSellItems()
    local inventory = getPlayerInventory()
    local layout = sellScrollingFrame:FindFirstChildOfClass("UIListLayout") or sellScrollingFrame:FindFirstChildOfClass("UIGridLayout")
    local runService = game:GetService("RunService")
    for i, item in ipairs(inventory) do
        createSellItem(item, i)
        -- Force layout update after each clone to ensure correct order and click organization
        if layout then
            runService.RenderStepped:Wait()
            local contentX = layout.AbsoluteContentSize.X
            local contentY = layout.AbsoluteContentSize.Y
            local frameX = sellScrollingFrame.AbsoluteSize.X
            local frameY = sellScrollingFrame.AbsoluteSize.Y
            -- Always set CanvasSize to content size, not max(content, frame)
            sellScrollingFrame.CanvasSize = UDim2.new(0, contentX, 0, contentY)
        end
    end
end

-- Helper to create shop item UI
local purchaseButtonConn
local function createShopItem(itemName, index)
    local itemClone = shopItemTemplate:Clone()
    itemClone.Name = "Item_" .. index
    itemClone.Visible = true
    itemClone.LayoutOrder = index

    local itemNameLabel = itemClone:FindFirstChild("Item Name")
    local itemImage = itemClone:FindFirstChild("Item Image")
    if itemNameLabel and (itemNameLabel:IsA("TextLabel") or itemNameLabel:IsA("TextButton")) then
        itemNameLabel.Text = itemName
    end
    if itemImage and itemImage:IsA("ImageLabel") then
        -- Replace image with ViewportFrame preview
        local viewport = Instance.new("ViewportFrame")
        viewport.Size = itemImage.Size
        viewport.Position = itemImage.Position
        viewport.AnchorPoint = itemImage.AnchorPoint
        viewport.BackgroundTransparency = 1
        viewport.Name = "ItemViewport"
        viewport.Parent = itemClone
        itemImage.Visible = false

        local for2dImageFolder = workspace:FindFirstChild("For2dImage")
        if for2dImageFolder then
            local tool = for2dImageFolder:FindFirstChild(itemName)
            if tool then
                local toolClone = tool:Clone()
                toolClone.Parent = viewport

                -- Lighting
                local light = Instance.new("PointLight")
                light.Brightness = 2
                light.Range = 16
                light.Color = Color3.new(1, 1, 1)
                local lightParent = nil
                if toolClone:IsA("Model") and toolClone.PrimaryPart then
                    lightParent = toolClone.PrimaryPart
                else
                    for _, child in ipairs(toolClone:GetDescendants()) do
                        if child:IsA("BasePart") then
                            lightParent = child
                            break
                        end
                    end
                end
                if lightParent then
                    light.Parent = lightParent
                end

                -- Camera setup
                local focusCFrame = nil
                local size = 2
                local foundModel = nil
                for _, child in ipairs(toolClone:GetChildren()) do
                    if child:IsA("Model") then
                        foundModel = child
                        break
                    end
                end
                if foundModel then
                    if foundModel.GetPivot then
                        focusCFrame = foundModel:GetPivot()
                    elseif foundModel.PrimaryPart then
                        focusCFrame = foundModel.PrimaryPart.CFrame
                    end
                    size = (foundModel:GetExtentsSize() or Vector3.new(2,2,2)).Magnitude
                else
                    for _, child in ipairs(toolClone:GetChildren()) do
                        if child:IsA("BasePart") then
                            focusCFrame = child.CFrame
                            size = child.Size.Magnitude
                            break
                        end
                    end
                end
                local camera = Instance.new("Camera")
                camera.FieldOfView = 35
                viewport.CurrentCamera = camera
                camera.Parent = viewport
                if focusCFrame then
                    local camDistance = size * 1.2
                    local camPos = focusCFrame.Position + Vector3.new(0, 0, camDistance)
                    camera.CFrame = CFrame.new(camPos, focusCFrame.Position)
                    camera.Focus = CFrame.new(focusCFrame.Position)
                else
                    camera.CFrame = CFrame.new(0, 0, 1)
                    camera.Focus = CFrame.new(0, 0, 0)
                end
            end
        end
    end

    itemClone.MouseButton1Click:Connect(function()
        if not shopItemStats then return end
        local weaponStats = WeaponData.GetWeaponStats(itemName)
        local orbStats = OrbData.GetOrbData(itemName)
        local armorStats = ArmorData[itemName]
        local statsDescription = shopItemStats:FindFirstChild("Description")
        if statsDescription then
            if orbStats then
                local sellingPrice = getOrbSellingPrice(itemName)
                statsDescription.Text = itemName .. "\n" .. (orbStats.description or "") .. "\n\n📊 Stat Bonuses:\n" .. (function()
                    local t = ""
                    if orbStats.stats then
                        for statName, multiplier in pairs(orbStats.stats) do
                            local bonus = math.floor((multiplier - 1) * 100)
                            if bonus > 0 then
                                t = t .. "+" .. bonus .. "% " .. statName .. "\n"
                            end
                        end
                    end
                    return t
                end)() .. (orbStats.chance and ("\nDrop Rate: " .. tostring(math.floor(orbStats.chance * 100)) .. "%") or "") .. "\n\nPrice: $" .. formatNumberWithCommas(sellingPrice)
            elseif weaponStats then
                local price = weaponStats.Price or 0
                statsDescription.Text = itemName .. "\n" .. (weaponStats.Description or "") .. "\n\n⚔️ Weapon Stats:\n" .. "Damage: " .. tostring(weaponStats.damage) .. "\nLevel Requirement: " .. tostring(weaponStats.levelRequirement or "N/A") .. "\nPrice: $" .. formatNumberWithCommas(price)
            elseif armorStats then
                local price = armorStats.Price or 0
                statsDescription.Text = itemName .. "\n" .. (armorStats.Description or "") .. "\n\n🛡️ Armor Stats:\n" .. "Type: " .. tostring(armorStats.Type or "N/A") .. "\nDefense: " .. tostring(armorStats.Defense or "N/A") .. "\nPrice: $" .. formatNumberWithCommas(price)
            end
        end
        local purchaseButton = shopItemStats:FindFirstChild("PurchaseButton")
        if purchaseButton then
            purchaseButton.Visible = true
            if purchaseButton:IsA("ImageButton") then
                if purchaseButtonConn then
                    purchaseButtonConn:Disconnect()
                end
                purchaseButtonConn = purchaseButton.MouseButton1Click:Connect(function()
                    --print("[ShopUI] PurchaseButton clicked for", itemName)
                    shopEvent:FireServer("Buy", itemName)
                    shopItemStats.Visible = false
                end)
            end
        end
        shopItemStats.Visible = true
    end)

    itemClone.Parent = shopScrollingFrame
    return itemClone
end

local function populateShopUI(mapName)
    clearShopItems()
    if not mapName then return end
    local items = Shops.GetItemsForMap(mapName)
    local layout = shopScrollingFrame:FindFirstChildOfClass("UIListLayout") or shopScrollingFrame:FindFirstChildOfClass("UIGridLayout")
    local runService = game:GetService("RunService")
    for i, itemName in ipairs(items) do
        createShopItem(itemName, i)
        -- Force layout update after each clone to ensure correct order and click organization
        if layout then
            runService.RenderStepped:Wait()
            local contentX = layout.AbsoluteContentSize.X
            local contentY = layout.AbsoluteContentSize.Y
            local frameX = shopScrollingFrame.AbsoluteSize.X
            local frameY = shopScrollingFrame.AbsoluteSize.Y
            -- Always set CanvasSize to content size, not max(content, frame)
            shopScrollingFrame.CanvasSize = UDim2.new(0, contentX, 0, contentY)
        end
    end
end

-- Only show ShopUI on BuyButton click
shopBuy.MouseButton1Click:Connect(function()
    --print("Buy button clicked, showing shop UI")
    shopUITitle.Text = ShopHandler._lastMapName.." Shop"
    ShopUI.Visible = true
    shopSelectionFrame.Visible = false
    -- Use last mapName from lastShopPrompt if needed, or store it on event
    if ShopHandler._lastMapName then
        populateShopUI(ShopHandler._lastMapName)
    end
end)


shopSell.MouseButton1Click:Connect(function()
    --print("Sell button clicked, showing sell UI")
    shopSellTitle.Text = "Sell Items"
    SellUI.Visible = true
    shopSelectionFrame.Visible = false
    -- Always fetch latest inventory before showing sell UI
    clearSellItems()
    local inventoryEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
    local inventory = {}
    if inventoryEvent and inventoryEvent:IsA("RemoteFunction") then
        local success, result = pcall(function()
            return inventoryEvent:InvokeServer()
        end)
        if success and type(result) == "table" then
            inventory = result
        end
    end
    local layout = sellScrollingFrame:FindFirstChildOfClass("UIListLayout") or sellScrollingFrame:FindFirstChildOfClass("UIGridLayout")
    local runService = game:GetService("RunService")
    for i, item in ipairs(inventory) do
        createSellItem(item, i)
        if layout then
            runService.RenderStepped:Wait()
            local contentX = layout.AbsoluteContentSize.X
            local contentY = layout.AbsoluteContentSize.Y
            local frameX = sellScrollingFrame.AbsoluteSize.X
            local frameY = sellScrollingFrame.AbsoluteSize.Y
            -- Always set CanvasSize to content size, not max(content, frame)
            sellScrollingFrame.CanvasSize = UDim2.new(0, contentX, 0, contentY)
        end
    end
end)

-- Track the last prompt for re-enabling
local lastShopPrompt = nil
local currentShopNpc = nil -- Store the shop NPC for camera focus


shopEvent.OnClientEvent:Connect(function(command, prompt, mapName)
    if command == "Show" then
        --print("[ShopHandler] Shop prompt triggered for map/shop:", mapName)
        shopSelectionFrame.Visible = true
        ShopHandler._lastMapName = mapName
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.Enabled = false
            lastShopPrompt = prompt
            -- Get the shop NPC for camera focus (prompt.Parent is npc, prompt.Parent.Parent is Shop)
            local shopModel = prompt.Parent and prompt.Parent.Parent
            if shopModel and shopModel:IsA("Model") then
                local npc = shopModel:FindFirstChild("npc")
                if npc then
                    currentShopNpc = npc
                    CameraFocusModule.FocusOn(npc, 1.5)
                end
            end
        end
    elseif command == "Hide" then
        --print("[ShopHandler] Hiding shop UI")
        shopSelectionFrame.Visible = false
        ShopUI.Visible = false
        CameraFocusModule.RestoreDefault()
        currentShopNpc = nil
        if lastShopPrompt and lastShopPrompt:IsA("ProximityPrompt") then
            lastShopPrompt.Enabled = true
            lastShopPrompt = nil
        end
    end
end)


-- Hide ShopUI and re-enable prompt on close button click
closeShopButton.MouseButton1Click:Connect(function()
    ShopUI.Visible = false
    shopSelectionFrame.Visible = false
    CameraFocusModule.RestoreDefault()
    currentShopNpc = nil
    if lastShopPrompt and lastShopPrompt:IsA("ProximityPrompt") then
        lastShopPrompt.Enabled = true
        lastShopPrompt = nil
    end
end)


closeSellButton.MouseButton1Click:Connect(function()
    SellUI.Visible = false
    shopSelectionFrame.Visible = false
    CameraFocusModule.RestoreDefault()
    currentShopNpc = nil
    if lastShopPrompt and lastShopPrompt:IsA("ProximityPrompt") then
        lastShopPrompt.Enabled = true
        lastShopPrompt = nil
    end
end)


return ShopHandler
