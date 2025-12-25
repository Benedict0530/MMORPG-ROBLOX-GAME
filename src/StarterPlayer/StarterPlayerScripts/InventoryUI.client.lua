-- InventoryUI.client.lua
-- Handles displaying player inventory in the UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load WeaponData
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)

-- Track event connections for cleanup
local connections = {}

local function disconnectAll()
	for _, connection in pairs(connections) do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(connections)
end

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

-- Get ItemStats panel
local itemStats = inventoryUI:WaitForChild("Background"):WaitForChild("ItemStats", 10)
if not itemStats then
	warn("[InventoryUI] ItemStats not found in InventoryUI after 10 second wait - will skip stats display")
	itemStats = nil
else
	itemStats.Visible = false -- Initially hidden
end

-- Get weapons folder
local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
if not weaponsFolder then
	warn("[InventoryUI] Weapons folder not found in ReplicatedStorage!")
	return
end

-- Function to get weapon image from weapon data
local function getWeaponImage(weaponName)
	if not weaponName then
		warn("[InventoryUI] Weapon name is nil!")
		return ""
	end
	
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
	
	local itemClone = itemTemplate:Clone()
	
	itemClone.Name = "Item_" .. index
	itemClone.Visible = true
	itemClone.LayoutOrder = index
	
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
	else
		warn("[InventoryUI] Item Image is not an ImageLabel!")
		itemClone:Destroy()
		return
	end
	
	-- Store item data in the clone for later reference (trading, equipping, etc.)
	itemClone:SetAttribute("ItemId", itemData.id)
	itemClone:SetAttribute("ItemName", itemData.name)
	
	-- Add click handler to show item stats
	itemClone.MouseButton1Click:Connect(function()
		
		-- Use the itemStats reference from module scope
		if not itemStats then 
			warn("[InventoryUI] ItemStats not available")
			return 
		end
		
		-- Get weapon stats from WeaponData
		local weaponStats = WeaponData.GetWeaponStats(itemData.name)
		
		if not weaponStats then
			warn("[InventoryUI] Could not find weapon stats for " .. itemData.name)
			return
		end
		
		-- Update ItemStats Description with all weapon information
		local statsDescription = itemStats:FindFirstChild("Description")
		
		if statsDescription then
			if statsDescription:IsA("TextLabel") or statsDescription:IsA("TextButton") then
				local descText = itemData.name .. "\n" ..
					"Damage: " .. tostring(weaponStats.damage) .. "\n" ..
					"Level Requirement: " .. tostring(weaponStats.levelRequirement or "N/A") .. "\n" ..
					(weaponStats.Description or "No description available")
				statsDescription.Text = descText

			end
		end
		
		-- Toggle ItemStats panel visibility
		itemStats.Visible = true
	end)
	
	itemClone.Parent = scrollingFrame
	
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
	
	-- Get inventory from server via RemoteFunction with retry logic
	local inventoryEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
	if not inventoryEvent then
		inventoryEvent = ReplicatedStorage:WaitForChild("GetPlayerInventory", 10)
		if not inventoryEvent then
			warn("[InventoryUI] GetPlayerInventory RemoteFunction never appeared!")
			return
		end
	end
	
	-- Request inventory from server with retry
	local inventoryData = nil
	local retries = 0
	local maxRetries = 10
	
	while not inventoryData and retries < maxRetries do
		local success, result = pcall(function()
			return inventoryEvent:InvokeServer()
		end)
		
		if success and result then
			inventoryData = result
			break
		else
			retries = retries + 1
			if retries < maxRetries then
				task.wait(0.2)
			else
				warn("[InventoryUI] Failed to get inventory after " .. maxRetries .. " attempts: " .. tostring(result))
				return
			end
		end
	end
	
	if not inventoryData or #inventoryData == 0 then
		return
	end
		
	-- Create UI items for each inventory item
	for index, itemData in ipairs(inventoryData) do
		if itemData and itemData.name then
			createInventoryItem(itemData, index)
		else
			warn("[InventoryUI] Invalid item data at index " .. index)
		end
	end
	
end

-- Initial refresh (wait a moment for server to be ready)
task.wait(1)
refreshInventory()

-- Setup inventory change listener
local function setupInventoryListener()
	disconnectAll()
	
	local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
	if inventoryChangedEvent then
		connections.inventoryChanged = inventoryChangedEvent.OnClientEvent:Connect(function()
			refreshInventory()
		end)
	else
		warn("[InventoryUI] InventoryChanged event not found - UI won't auto-update on item collection")
	end
end

-- Initial setup
setupInventoryListener()

-- Handle character respawn - reinitialize everything
player.CharacterAdded:Connect(function(newCharacter)	
	task.spawn(function()
		-- Wait LONGER for server to reload inventory from DataStore and sync backpack
		-- This matches the server-side delays (humanoid wait + 0.3s + sync delays)
		task.wait(2)
				
		-- Refresh inventory display
		refreshInventory()
		
		-- Re-setup inventory listener
		setupInventoryListener()
		
	end)
end)