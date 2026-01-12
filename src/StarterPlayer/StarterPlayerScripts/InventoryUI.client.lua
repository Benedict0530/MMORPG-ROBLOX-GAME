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
local connectionsByButton = {}

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

local gameGuiFrame = gameGui:WaitForChild("Frame", 5)

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

-- Get the UIListLayout (or UIGridLayout) inside the ScrollingFrame
local layout = scrollingFrame:FindFirstChildOfClass("UIListLayout") or scrollingFrame:FindFirstChildOfClass("UIGridLayout")
if not layout then
	warn("[InventoryUI] No UIListLayout or UIGridLayout found in ScrollingFrame! CanvasSize will not auto-adjust.")
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

local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
if not weaponsFolder then
	warn("[InventoryUI] Weapons folder not found in ReplicatedStorage!")
	return
end

-- Get or create RemoteEvent for item actions
local itemActionEvent = ReplicatedStorage:WaitForChild("ItemActionEvent")


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

-- Forward declarations for functions used before definition
local refreshInventory
local updateCapacityDisplay

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

	-- Replace the image with a ViewportFrame preview of the Tool from workspace/For2dImage
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = itemImage.Size
	viewport.Position = itemImage.Position
	viewport.AnchorPoint = itemImage.AnchorPoint
	viewport.BackgroundTransparency = 1
	viewport.Name = "ItemViewport"
	viewport.Parent = itemClone
	itemImage.Visible = false

	local for2dImageFolder = workspace:WaitForChild("For2dImage")
	if for2dImageFolder then
		local tool = for2dImageFolder:WaitForChild(itemData.name)
		if tool then
			local toolClone = tool:Clone()
			toolClone.Parent = viewport

			-- Find the main model or part to focus on (prefer Model:GetPivot, else PrimaryPart, else first BasePart)
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

			-- Setup camera
			local camera = Instance.new("Camera")
			camera.FieldOfView = 35
			viewport.CurrentCamera = camera
			camera.Parent = viewport

			if focusCFrame then
				-- Force all previews to use the same orientation as Twig: camera looks from +Z toward the pivot
				local camDistance = size *1.2
				local camPos = focusCFrame.Position + Vector3.new(0, 0, camDistance)
				camera.CFrame = CFrame.new(camPos, focusCFrame.Position)
				camera.Focus = CFrame.new(focusCFrame.Position)
			else
				camera.CFrame = CFrame.new(0, 0, 1)
				camera.Focus = CFrame.new(0, 0, 0)
			end
		else
			warn("[InventoryUI] Tool '" .. itemData.name .. "' not found in workspace.For2dImage or is not a Tool.")
		end
	else
		warn("[InventoryUI] workspace.For2dImage folder not found!")
	end

	-- Store item data in the clone for later reference (trading, equipping, etc.)
	itemClone:SetAttribute("ItemId", itemData.id)
	itemClone:SetAttribute("ItemName", itemData.name)

	-- Show Equipped indicator if this item is currently equipped
	local equippedVisible = false
	local stats = player:FindFirstChild("Stats")
	if stats then
		local equipped = stats:FindFirstChild("Equipped")
		if equipped and equipped:IsA("Folder") then
			local equippedId = equipped:FindFirstChild("id")
			if equippedId and equippedId.Value == itemData.id then
				equippedVisible = true
			end
		end
	end
	local equippedIndicator = itemClone:FindFirstChild("Equipped")
	if equippedIndicator and equippedIndicator:IsA("GuiObject") then
		equippedIndicator.Visible = equippedVisible
	end

	-- Add click handler to show item stats
	itemClone.MouseButton1Click:Connect(function()
		if not itemStats then 
			warn("[InventoryUI] ItemStats not available")
			return 
		end
		local weaponStats = WeaponData.GetWeaponStats(itemData.name)
		if not weaponStats then
			warn("[InventoryUI] Could not find weapon stats for " .. itemData.name)
			return
		end
		local statsDescription = itemStats:FindFirstChild("Description")
		if statsDescription then
			if statsDescription:IsA("TextLabel") or statsDescription:IsA("TextButton") then
				local price = weaponStats.Price or 0
				local descText = itemData.name .. "\n" ..
					"Damage: " .. tostring(weaponStats.damage) .. "\n" ..
					"Level Requirement: " .. tostring(weaponStats.levelRequirement or "N/A") .. "\n" ..
					(weaponStats.Description or "No description available") .. "\n" ..
					"Price: $" .. formatNumberWithCommas(price)
				statsDescription.Text = descText
			end
		end
		local firstButton = itemStats:FindFirstChild("1stButton")
		local secondButton = itemStats:FindFirstChild("2ndButton")
		local isEquipped = false
		local statsFolder = player:FindFirstChild("Stats")
		if statsFolder then
			local equipped = statsFolder:FindFirstChild("Equipped")
			if equipped and equipped:IsA("Folder") then
				local equippedId = equipped:FindFirstChild("id")
				if equippedId and equippedId.Value == itemData.id then
					isEquipped = true
				end
			end
		end
		if firstButton then firstButton.Visible = not isEquipped end
		if secondButton then secondButton.Visible = not isEquipped end
		itemStats.Visible = true
	end)

	itemClone.MouseButton1Click:Connect(function()
		if not itemStats then 
			Print("[InventoryUI] ItemStats not available")
			return 
		end
		local firstButton = itemStats:FindFirstChild("1stButton")
		local secondButton = itemStats:FindFirstChild("2ndButton")
		if firstButton and not firstButton:IsA("TextButton") and firstButton:FindFirstChildWhichIsA("TextButton") then
			firstButton = firstButton:FindFirstChildWhichIsA("TextButton")
		end
		if secondButton and not secondButton:IsA("TextButton") and secondButton:FindFirstChildWhichIsA("TextButton") then
			secondButton = secondButton:FindFirstChildWhichIsA("TextButton")
		end
		if firstButton and secondButton then
			local function fireAction(action)
				-- Don't delete immediately - let server response trigger UI update
				-- This prevents desync between client and server state
				itemStats.Visible = false
				itemActionEvent:FireServer(action, itemData.id)
				
				-- Also refresh inventory after a short delay as backup
				-- This ensures UI updates even if server event doesn't fire
				task.delay(0.3, function()
					print("[InventoryUI] Auto-refresh after action: " .. action)
					refreshInventory()
				end)
			end
			local newEquipConn = firstButton.MouseButton1Click:Connect(function()
				print("[InventoryUI] Equip button pressed for", itemData.name, "id:", itemData.id)
				fireAction("Equip")
			end)
			local newDropConn = secondButton.MouseButton1Click:Connect(function()
				print("[InventoryUI] Drop button pressed for", itemData.name, "id:", itemData.id)
				fireAction("Drop")
			end)
			connectionsByButton[firstButton] = connectionsByButton[firstButton] or {}
			connectionsByButton[firstButton].equipConn = newEquipConn
			connectionsByButton[secondButton] = connectionsByButton[secondButton] or {}
			connectionsByButton[secondButton].dropConn = newDropConn
		end
	end)

	itemClone.Parent = scrollingFrame
	return itemClone
end


-- Display inventory capacity
updateCapacityDisplay = function()
	local stats = player:WaitForChild("Stats", 10)
	if not stats then return end
	
	local capacity = stats:FindFirstChild("InventoryCapacity")
	local maxCapacity = stats:FindFirstChild("InventoryMaxCapacity")
	
	if not capacity or not maxCapacity then return end
	
	-- Find the existing capacity label in the inventory UI
	local capacityLabel = inventoryUI:FindFirstChild("Capacity")
	if capacityLabel then
		capacityLabel.Text = capacity.Value .. " / " .. maxCapacity.Value
	end
end

-- Function to refresh inventory display
refreshInventory = function()
	print("[InventoryUI] refreshInventory called!")
	-- NOTE: Don't clear all button connections here - we'll only disconnect specific items that are being deleted

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

	-- inventoryData might be nil or empty - that's okay, we still need to remove old items from UI
	if not inventoryData then
		inventoryData = {}
	end

	-- Find equipped item id
	local equippedId = nil
	local equipped = stats:FindFirstChild("Equipped")
	if equipped and equipped:IsA("Folder") then
		local idValue = equipped:FindFirstChild("id")
		if idValue then
			equippedId = idValue.Value
		end
	end

	-- Sort inventory: equipped item first, then others
	table.sort(inventoryData, function(a, b)
		if equippedId then
			if a.id == equippedId then return true end
			if b.id == equippedId then return false end
		end
		return (a.name or "") < (b.name or "")
	end)

	-- Create a set of existing item IDs to avoid duplicates
	local existingItemIds = {}
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= itemTemplate and child.Name:match("^Item_") then
			local itemId = child:GetAttribute("ItemId")
			if itemId then
				existingItemIds[itemId] = child
			end
		end
	end

	-- Create UI items for each inventory item that doesn't already exist
	-- Also update equipped indicator for existing items
	local runService = game:GetService("RunService")
	for index, itemData in ipairs(inventoryData) do
		if itemData and itemData.name then
			-- Only create if this item doesn't already exist
			if not existingItemIds[itemData.id] then
				createInventoryItem(itemData, index)
				-- Force layout update after creating new item
				if layout then
					runService.RenderStepped:Wait()
					local contentX = layout.AbsoluteContentSize.X
					local contentY = layout.AbsoluteContentSize.Y
					local frameX = scrollingFrame.AbsoluteSize.X
					local frameY = scrollingFrame.AbsoluteSize.Y
					scrollingFrame.CanvasSize = UDim2.new(0, math.max(contentX, frameX), 0, math.max(contentY, frameY))
				end
			else
				-- Update equipped indicator for existing items
				local existingItem = existingItemIds[itemData.id]
				if existingItem then
					local isEquipped = false
					if equippedId and equippedId == itemData.id then
						isEquipped = true
					end
					local equippedIndicator = existingItem:FindFirstChild("Equipped")
					if equippedIndicator and equippedIndicator:IsA("GuiObject") then
						equippedIndicator.Visible = isEquipped
					end
				end
			end
		else
			warn("[InventoryUI] Invalid item data at index " .. index)
		end
	end
	
	-- Remove items that are no longer in inventory
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= itemTemplate and child.Name:match("^Item_") then
			local itemId = child:GetAttribute("ItemId")
			if itemId then
				local stillExists = false
				for _, itemData in ipairs(inventoryData) do
					if itemData and itemData.id == itemId then
						stillExists = true
						break
					end
				end
				if not stillExists then
					-- Remove from button connections before destroying
					for btn, btnConns in pairs(connectionsByButton) do
						if btn.Parent == child or btn.Parent.Parent == child then
							for _, conn in pairs(btnConns) do
								if conn then conn:Disconnect() end
							end
							connectionsByButton[btn] = nil
						end
					end
					child:Destroy()
				end
			end
		end
	end
	
	-- Update capacity display after refreshing inventory
	updateCapacityDisplay()
end

-- Initial refresh (wait a moment for server to be ready)
task.wait(1)
refreshInventory()

updateCapacityDisplay()

-- Listen for capacity changes
local stats = player:FindFirstChild("Stats")
if stats then
	local capacity = stats:FindFirstChild("InventoryCapacity")
	local maxCapacity = stats:FindFirstChild("InventoryMaxCapacity")
	if capacity then
		connections.capacityChanged = capacity.Changed:Connect(function()
			updateCapacityDisplay()
		end)
	end
	if maxCapacity then
		connections.maxCapacityChanged = maxCapacity.Changed:Connect(function()
			updateCapacityDisplay()
		end)
	end
end


-- Setup inventory change listener
local function setupInventoryListener()
	disconnectAll()

	local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
	if inventoryChangedEvent then
		print("[InventoryUI] InventoryChanged listener connected")
		connections.inventoryChanged = inventoryChangedEvent.OnClientEvent:Connect(function()
			print("[InventoryUI] InventoryChanged event FIRED!")
			refreshInventory()
			updateCapacityDisplay()
		end)
	else
		warn("[InventoryUI] InventoryChanged event not found - UI won't auto-update on item collection")
	end

	-- Listen for EquippedChanged event for immediate UI update on equip
	local equippedChangedEvent = ReplicatedStorage:FindFirstChild("EquippedChanged")
	if equippedChangedEvent then
		print("[InventoryUI] EquippedChanged listener connected")
		connections.equippedChanged = equippedChangedEvent.OnClientEvent:Connect(function()
			print("[InventoryUI] EquippedChanged event FIRED!")
			refreshInventory()
		end)
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