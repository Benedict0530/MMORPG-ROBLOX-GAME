-- InventoryUI.client.lua
-- Handles displaying player inventory in the UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load WeaponData
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)

-- Wait for GameGui and InventoryUI to load
local gameGui = playerGui:WaitForChild("GameGui", 5)
if not gameGui then
	warn("[InventoryUI] GameGui not found!")
	return
end

local gameGuiFrame = gameGui:WaitForChild("Frame", 5)
if not gameGuiFrame then
	warn("[InventoryUI] Frame not found in GameGui!")
	return
end

local inventoryUI = gameGuiFrame:WaitForChild("InventoryUI", 5)
if not inventoryUI then
	warn("[InventoryUI] InventoryUI not found!")
	return
end

local scrollingFrame = inventoryUI:WaitForChild("Background", 5)
if not scrollingFrame then
	warn("[InventoryUI] Background not found in InventoryUI!")
	return
end

scrollingFrame = scrollingFrame:WaitForChild("ScrollingFrame", 5)
if not scrollingFrame then
	warn("[InventoryUI] ScrollingFrame not found in Background!")
	return
end

-- Get the Item template
local itemTemplate = scrollingFrame:WaitForChild("Item", 5)
if not itemTemplate then
	warn("[InventoryUI] Item template not found in ScrollingFrame!")
	return
end

-- Hide the template (we'll clone it to create items, but don't want to show the template itself)
itemTemplate.Visible = false

-- Get weapons folder
local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
if not weaponsFolder then
	warn("[InventoryUI] Weapons folder not found in ReplicatedStorage!")
	return
end

-- Function to get weapon image from weapon data
local function getWeaponImage(weaponName)
	local weaponStats = WeaponData.GetWeaponStats(weaponName)
	if not weaponStats then
		warn("[InventoryUI] Weapon '" .. weaponName .. "' not found in WeaponData")
		return ""
	end
	
	-- Get imageId from WeaponData
	local imageId = weaponStats.imageId
	if imageId then
		return imageId
	end
	
	-- If no imageId in WeaponData, return empty string
	warn("[InventoryUI] No imageId found for weapon '" .. weaponName .. "'")
	return ""
end

-- Function to create inventory item UI
local function createInventoryItem(itemData, index)
	print("[InventoryUI] Creating item clone for: " .. itemData.name)
	local itemClone = itemTemplate:Clone()
	print("[InventoryUI] Clone created, clone type: " .. itemClone.ClassName)
	
	itemClone.Name = "Item_" .. index
	itemClone.Visible = true
	itemClone.LayoutOrder = index
	
	print("[InventoryUI] Before parenting - scrollingFrame children: " .. #scrollingFrame:GetChildren())
	
	-- Find Item Name and Item Image elements
	local itemName = itemClone:FindFirstChild("Item Name")
	local itemImage = itemClone:FindFirstChild("Item Image")
	
	if not itemName then
		warn("[InventoryUI] 'Item Name' not found in item template!")
		itemClone:Destroy()
		return
	end
	
	if not itemImage then
		warn("[InventoryUI] 'Item Image' not found in item template!")
		itemClone:Destroy()
		return
	end
	
	-- Set the item name
	if itemName:IsA("TextLabel") or itemName:IsA("TextButton") then
		itemName.Text = itemData.name
	else
		warn("[InventoryUI] Item Name is not a TextLabel or TextButton!")
		itemClone:Destroy()
		return
	end
	
	-- Setup weapon preview in the item image
	-- Use the Item Image element directly (convert if needed)
	if itemImage:IsA("ImageLabel") then
		-- Get weapon image and set it
		local imageId = getWeaponImage(itemData.name)
		itemImage.Image = imageId
		print("[InventoryUI] Set image for " .. itemData.name .. ": " .. imageId)
	else
		warn("[InventoryUI] Item Image is not an ImageLabel!")
		itemClone:Destroy()
		return
	end
	
	-- Store item data in the clone for later reference (trading, equipping, etc.)
	itemClone:SetAttribute("ItemId", itemData.id)
	itemClone:SetAttribute("ItemName", itemData.name)
	
	print("[InventoryUI] Parenting itemClone to scrollingFrame...")
	itemClone.Parent = scrollingFrame
	print("[InventoryUI] Item parented! ScrollingFrame now has " .. #scrollingFrame:GetChildren() .. " children")
	print("[InventoryUI] Created inventory item: " .. itemData.name .. " (ID: " .. itemData.id .. ")")
	
	return itemClone
end

-- Function to refresh inventory display
local function refreshInventory()
	-- Clear existing items (keep template)
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= itemTemplate and child.Name:match("^Item_") then
			child:Destroy()
		end
	end
	
	-- Get player inventory
	local stats = player:WaitForChild("Stats", 10)
	if not stats then
		warn("[InventoryUI] Stats not found for player after 10 second timeout!")
		return
	end
	
	-- Get inventory from server via RemoteFunction (we'll create this if needed)
	-- For now, we'll access the InventoryManager via a request
	local inventoryEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
	if not inventoryEvent then
		inventoryEvent = Instance.new("RemoteFunction")
		inventoryEvent.Name = "GetPlayerInventory"
		inventoryEvent.Parent = ReplicatedStorage
	end
	
	-- Request inventory from server
	local success, inventoryData = pcall(function()
		return inventoryEvent:InvokeServer()
	end)
	
	print("[InventoryUI] Invocation success: " .. tostring(success))
	print("[InventoryUI] Inventory data type: " .. type(inventoryData))
	print("[InventoryUI] Inventory data: " .. tostring(inventoryData))
	
	if not success then
		warn("[InventoryUI] Failed to get inventory from server: " .. tostring(inventoryData))
		return
	end
	
	print("[InventoryUI] inventoryData length: " .. tostring(#inventoryData))
	
	-- Debug: Try to iterate through the table manually
	print("[InventoryUI] Attempting to iterate through inventoryData:")
	for key, value in pairs(inventoryData) do
		print("[InventoryUI] Key: " .. tostring(key) .. ", Value type: " .. type(value))
		if type(value) == "table" and value.name then
			print("[InventoryUI] Found item: " .. value.name .. " (ID: " .. value.id .. ")")
		end
	end
	
	if not inventoryData or #inventoryData == 0 then
		print("[InventoryUI] Player inventory is empty!")
		print("[InventoryUI] inventoryData value: " .. tostring(inventoryData))
		return
	end
	
	-- Create UI items for each inventory item
	for index, itemData in ipairs(inventoryData) do
		print("[InventoryUI] Processing item " .. index .. ": " .. itemData.name)
		createInventoryItem(itemData, index)
	end
	
	print(string.format("[InventoryUI] Displayed %d inventory items", #inventoryData))
	print("[InventoryUI] Final scrollingFrame children count: " .. #scrollingFrame:GetChildren())
end

-- Initial refresh
refreshInventory()

-- Listen for inventory changes (if we implement inventory updates later)
-- For now, we can refresh on demand or periodically

print("[InventoryUI] Inventory UI initialized!")
