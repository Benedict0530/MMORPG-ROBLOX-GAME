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

-- Load OrbData
local OrbData = require(ReplicatedStorage.Modules.OrbData)

-- Load ArmorData
local ArmorData = require(ReplicatedStorage.Modules.ArmorData)

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
		if itemData.itemType == "armor" then
			local armorInfo = ArmorData[itemData.name]
			if armorInfo and armorInfo.Type then
				local slotName = "Equipped" .. armorInfo.Type
				local equippedSlot = stats:FindFirstChild(slotName)
				if equippedSlot and equippedSlot:IsA("Folder") then
					local equippedId = equippedSlot:FindFirstChild("id")
					if equippedId and equippedId.Value == itemData.id then
						equippedVisible = true
					end
				end
			end
		elseif itemData.itemType == "weapon" or itemData.itemType == nil then
			local equipped = stats:FindFirstChild("Equipped")
			if equipped and equipped:IsA("Folder") then
				local equippedId = equipped:FindFirstChild("id")
				if equippedId and equippedId.Value == itemData.id then
					equippedVisible = true
					end
			end
			-- Also check SecondaryEquipped for weapons
			if not equippedVisible then
				local secondaryEquipped = stats:FindFirstChild("SecondaryEquipped")
				if secondaryEquipped and secondaryEquipped:IsA("Folder") then
					local secondaryEquippedId = secondaryEquipped:FindFirstChild("id")
					if secondaryEquippedId and secondaryEquippedId.Value == itemData.id then
						equippedVisible = true
					end
				end
			end
		elseif itemData.itemType == "spirit orb" then
			local equippedOrb = stats:FindFirstChild("EquippedOrb")
			if equippedOrb and equippedOrb:IsA("Folder") then
				local equippedOrbId = equippedOrb:FindFirstChild("id")
				if equippedOrbId and equippedOrbId.Value == itemData.id then
					equippedVisible = true
				end
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

		local statsDescription = itemStats:FindFirstChild("Description")
		local firstButton = itemStats:FindFirstChild("1stButton")
		local secondButton = itemStats:FindFirstChild("2ndButton")

		-- Always treat questItem as view-only, even if itemType is missing or nil
		local isQuestItem = itemData.itemType == "questItem"
		if not isQuestItem then
			-- Defensive: check ItemsData for quest item name (for legacy/multi-quantity cases)
			local ItemsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemsData"))
			if ItemsData[itemData.name] then
				isQuestItem = true
			end
		end

		if isQuestItem then
			local ItemsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemsData"))
			local itemInfo = ItemsData[itemData.name]
			if statsDescription then
				statsDescription.Text = itemInfo and (itemInfo.Name .. "\n" .. (itemInfo.Description or "")) or itemData.name
			end
			if firstButton then firstButton.Visible = false end
			itemStats.Visible = true
			return
		end

		-- Check if this is a spirit orb, weapon, or armor
		local stats = nil
		local descText = ""
			   if itemData.itemType == "spirit orb" then
				   stats = OrbData.GetOrbData(itemData.name)
				   if not stats then
					   warn("[InventoryUI] Could not find orb data for " .. itemData.name)
					   return
				   end
				   descText = itemData.name .. "\n"
				   if stats.description then
					   descText = descText .. "\n" .. stats.description .. "\n"
				   end
				   descText = descText .. "\n🟡 Orb Multipliers:\n"
				   if stats.stats then
					   if stats.stats.Attack and stats.stats.Attack > 1 then
						   descText = descText .. string.format("Attack x%.2f\n", stats.stats.Attack)
					   end
					   if stats.stats.Defence and stats.stats.Defence > 1 then
						   descText = descText .. string.format("Defence x%.2f\n", stats.stats.Defence)
					   end
					   if stats.stats.CriticalChance and stats.stats.CriticalChance > 1 then
						   descText = descText .. string.format("Critical Chance x%.2f\n", stats.stats.CriticalChance)
					   end
					   if stats.stats.CriticalDamage and stats.stats.CriticalDamage > 1 then
						   descText = descText .. string.format("Critical Damage x%.2f\n", stats.stats.CriticalDamage)
					   end
				   end
				   if stats.chance then
					   descText = descText .. "\nDrop Rate: " .. tostring(math.floor(stats.chance * 100)) .. "%"
				   end
			   elseif itemData.itemType == "armor" or (itemData.name and string.find(itemData.name:lower(), "shoes")) then
				   -- Treat anything with itemType 'armor' or name containing 'shoes' as armor
				   stats = ArmorData[itemData.name]
				   if not stats then
					   warn("[InventoryUI] Could not find armor stats for " .. itemData.name)
					   return
				   end
				   descText = itemData.name .. "\n"
				   if stats.Description then
					   descText = descText .. "\n" .. stats.Description .. "\n"
				   end
				   descText = descText .. "\n🛡️ Armor Stats:\n"
				   descText = descText .. "Type: " .. tostring(stats.Type or "N/A") .. "\n"
				   descText = descText .. "Defense: " .. tostring(stats.Defense or "N/A") .. "\n"
			   else
				   if itemData.itemType == "weapon" or itemData.itemType == nil then
					   stats = WeaponData.GetWeaponStats(itemData.name)
					   if not stats then
						   warn("[InventoryUI] Could not find weapon stats for " .. itemData.name)
						   return
					   end
					   descText = itemData.name .. "\n"
					   if stats.Description then
						   descText = descText .. "\n" .. stats.Description .. "\n"
					   end
					   descText = descText .. "\n⚔️ Weapon Stats:\n"
					   descText = descText .. "Damage: " .. tostring(stats.damage) .. "\n"
					   descText = descText .. "Level Requirement: " .. tostring(stats.levelRequirement or "N/A") .. "\n"
					   local price = stats.Price or 0
					   local sellingPrice = math.floor(price * 0.4)
					   descText = descText .. "Selling Price: $" .. formatNumberWithCommas(sellingPrice)
				   else
					   descText = itemData.name .. "\nNo stats available."
				   end
			   end

		local statsDescription = itemStats:FindFirstChild("Description")
		if statsDescription then
			if statsDescription:IsA("TextLabel") or statsDescription:IsA("TextButton") then
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
			-- Check SecondaryEquipped for weapons
			if not isEquipped and (itemData.itemType == "weapon" or itemData.itemType == nil) then
				local secondaryEquipped = statsFolder:FindFirstChild("SecondaryEquipped")
				if secondaryEquipped and secondaryEquipped:IsA("Folder") then
					local secondaryEquippedId = secondaryEquipped:FindFirstChild("id")
					if secondaryEquippedId and secondaryEquippedId.Value == itemData.id then
						isEquipped = true
					end
				end
			end
			if not isEquipped and itemData.itemType == "spirit orb" then
				local equippedOrb = statsFolder:FindFirstChild("EquippedOrb")
				if equippedOrb and equippedOrb:IsA("Folder") then
					local equippedOrbId = equippedOrb:FindFirstChild("id")
					if equippedOrbId and equippedOrbId.Value == itemData.id then
						isEquipped = true
					end
				end
			end
			if not isEquipped and itemData.itemType == "armor" then
				local armorInfo = ArmorData[itemData.name]
				if armorInfo and armorInfo.Type then
					local slotName = "Equipped" .. armorInfo.Type
					local equippedSlot = statsFolder:FindFirstChild(slotName)
					if equippedSlot and equippedSlot:IsA("Folder") then
						local equippedId = equippedSlot:FindFirstChild("id")
						if equippedId and equippedId.Value == itemData.id then
							isEquipped = true
						end
					end
				end
			end
		end

		if firstButton then
			firstButton.Visible = true
			local buttonTextLabel = firstButton:FindFirstChild("Text")
			if isEquipped then
				if buttonTextLabel and (buttonTextLabel:IsA("TextLabel") or buttonTextLabel:IsA("TextButton")) then
					-- Check if equipped as secondary weapon
					local isSecondary = false
					if (itemData.itemType == "weapon" or itemData.itemType == nil) and statsFolder then
						local secondaryEquipped = statsFolder:FindFirstChild("SecondaryEquipped")
						if secondaryEquipped and secondaryEquipped:IsA("Folder") then
							local secondaryEquippedId = secondaryEquipped:FindFirstChild("id")
							if secondaryEquippedId and secondaryEquippedId.Value == itemData.id then
								isSecondary = true
							end
						end
					end
					buttonTextLabel.Text = isSecondary and "Unequip 2nd" or "Unequip"
				end
				if secondButton then secondButton.Visible = false end
			else
				if buttonTextLabel and (buttonTextLabel:IsA("TextLabel") or buttonTextLabel:IsA("TextButton")) then
					-- Check if primary weapon is equipped for weapons
					local hasPrimaryWeapon = false
					if (itemData.itemType == "weapon" or itemData.itemType == nil) and statsFolder then
						local equipped = statsFolder:FindFirstChild("Equipped")
						if equipped and equipped:IsA("Folder") then
							local equippedId = equipped:FindFirstChild("id")
							if equippedId and equippedId.Value ~= "" then
								hasPrimaryWeapon = true
							end
						end
					end
					buttonTextLabel.Text = hasPrimaryWeapon and "Equip 2nd" or "Equip"
				end
				if secondButton then secondButton.Visible = true end
			end
		end
		itemStats.Visible = true
	end)

	itemClone.MouseButton1Click:Connect(function()
		if not itemStats then 
			warn("[InventoryUI] ItemStats not available")
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
		local function fireAction(action)
			itemStats.Visible = false
			itemActionEvent:FireServer(action, itemData.id)
			task.delay(0.3, function()
				--print("[InventoryUI] Auto-refresh after action: " .. action)
				refreshInventory()
			end)
		end
		-- Equip/Unequip button connection
		if firstButton then
			-- Disconnect previous connection if it exists
			if connectionsByButton[firstButton] and connectionsByButton[firstButton].equipConn then
				connectionsByButton[firstButton].equipConn:Disconnect()
				connectionsByButton[firstButton].equipConn = nil
			end
			-- Connect new handler
			local newEquipConn = firstButton.MouseButton1Click:Connect(function()
				-- Always check equipped state live, not by button text
				local isEquipped = false
				local statsFolder = player:FindFirstChild("Stats")
				if statsFolder then
					if itemData.itemType == "armor" then
						local armorInfo = ArmorData[itemData.name]
						if armorInfo and armorInfo.Type then
							local slotName = "Equipped" .. armorInfo.Type
							local equippedSlot = statsFolder:FindFirstChild(slotName)
							if equippedSlot and equippedSlot:IsA("Folder") then
								local equippedId = equippedSlot:FindFirstChild("id")
								if equippedId and equippedId.Value == itemData.id then
									isEquipped = true
								end
							end
						end
					elseif itemData.itemType == "weapon" or itemData.itemType == nil then
						local equipped = statsFolder:FindFirstChild("Equipped")
						if equipped and equipped:IsA("Folder") then
							local equippedId = equipped:FindFirstChild("id")
							if equippedId and equippedId.Value == itemData.id then
								isEquipped = true
							end
						end
						-- Check SecondaryEquipped for weapons
						if not isEquipped then
							local secondaryEquipped = statsFolder:FindFirstChild("SecondaryEquipped")
							if secondaryEquipped and secondaryEquipped:IsA("Folder") then
								local secondaryEquippedId = secondaryEquipped:FindFirstChild("id")
								if secondaryEquippedId and secondaryEquippedId.Value == itemData.id then
									isEquipped = true
								end
							end
						end
					elseif itemData.itemType == "spirit orb" then
						local equippedOrb = statsFolder:FindFirstChild("EquippedOrb")
						if equippedOrb and equippedOrb:IsA("Folder") then
							local equippedOrbId = equippedOrb:FindFirstChild("id")
							if equippedOrbId and equippedOrbId.Value == itemData.id then
								isEquipped = true
							end
						end
					end
				end
				if isEquipped then
					--print("[InventoryUI] Unequip button pressed for", itemData.name, "id:", itemData.id)
					fireAction("Unequip")
				else
					--print("[InventoryUI] Equip button pressed for", itemData.name, "id:", itemData.id)
					fireAction("Equip")
				end
			end)
			connectionsByButton[firstButton] = connectionsByButton[firstButton] or {}
			connectionsByButton[firstButton].equipConn = newEquipConn
		end
		-- Drop button connection
		if secondButton then
			-- Disconnect previous connection if it exists
			if connectionsByButton[secondButton] and connectionsByButton[secondButton].dropConn then
				connectionsByButton[secondButton].dropConn:Disconnect()
				connectionsByButton[secondButton].dropConn = nil
			end
			-- Connect new handler
			local newDropConn = secondButton.MouseButton1Click:Connect(function()
				--print("[InventoryUI] Drop button pressed for", itemData.name, "id:", itemData.id)
				fireAction("Drop")
			end)
			connectionsByButton[secondButton] = connectionsByButton[secondButton] or {}
			connectionsByButton[secondButton].dropConn = newDropConn
		end
	end)

	itemClone.Parent = scrollingFrame
	return itemClone
end


-- Display inventory capacity
updateCapacityDisplay = function()
	local stats = player:FindFirstChild("Stats")
	if not stats then
		-- Wait indefinitely for Stats to appear
		while true do
			stats = player:FindFirstChild("Stats")
			if stats then break end
			player.ChildAdded:Wait()
		end
	end
	if not stats then
		warn("[InventoryUI] Stats folder not found after waiting!")
		return
	end
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
	--print("[InventoryUI] refreshInventory called!")
	-- NOTE: Don't clear all button connections here - we'll only disconnect specific items that are being deleted

	-- Get player inventory
	local stats = player:FindFirstChild("Stats")
	if not stats then
		-- Wait indefinitely for Stats to appear
		while true do
			stats = player:FindFirstChild("Stats")
			if stats then break end
			player.ChildAdded:Wait()
		end
	end
	if not stats then
		warn("[InventoryUI] Stats folder not found after waiting!")
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

	-- Find equipped ids for weapon, orb, and armor
	local equippedId = nil
	local equipped = stats:FindFirstChild("Equipped")
	if equipped and equipped:IsA("Folder") then
		local idValue = equipped:FindFirstChild("id")
		if idValue then
			equippedId = idValue.Value
		end
	end
	local secondaryEquippedId = nil
	local secondaryEquipped = stats:FindFirstChild("SecondaryEquipped")
	if secondaryEquipped and secondaryEquipped:IsA("Folder") then
		local idValue = secondaryEquipped:FindFirstChild("id")
		if idValue then
			secondaryEquippedId = idValue.Value
		end
	end
	local equippedOrbId = nil
	local equippedOrb = stats:FindFirstChild("EquippedOrb")
	if equippedOrb and equippedOrb:IsA("Folder") then
		local idValue = equippedOrb:FindFirstChild("id")
		if idValue then
			equippedOrbId = idValue.Value
		end
	end
	-- Armor slots
	local equippedArmorIds = {}
	for _, slot in ipairs({"Helmet", "Suit", "Legs", "Shoes"}) do
		local slotFolder = stats:FindFirstChild("Equipped" .. slot)
		if slotFolder and slotFolder:IsA("Folder") then
			local idValue = slotFolder:FindFirstChild("id")
			if idValue and idValue.Value ~= "" then
				equippedArmorIds[idValue.Value] = true
			end
		end
	end

	   -- Sort inventory: equipped item (weapon/orb/armor) first, then others
	   table.sort(inventoryData, function(a, b)
		   -- Primary Weapon
		   if equippedId then
			   if a.id == equippedId and b.id ~= equippedId then return true end
			   if b.id == equippedId and a.id ~= equippedId then return false end
		   end
		   -- Secondary Weapon
		   if secondaryEquippedId then
			   if a.id == secondaryEquippedId and b.id ~= secondaryEquippedId then return true end
			   if b.id == secondaryEquippedId and a.id ~= secondaryEquippedId then return false end
		   end
		   -- Orb
		   if equippedOrbId then
			   if a.id == equippedOrbId and b.id ~= equippedOrbId then return true end
			   if b.id == equippedOrbId and a.id ~= equippedOrbId then return false end
		   end
		   -- Armor
		   if equippedArmorIds[a.id] and not equippedArmorIds[b.id] then return true end
		   if equippedArmorIds[b.id] and not equippedArmorIds[a.id] then return false end
		   -- Fallback: sort by name
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
					if itemData.itemType == "armor" then
						if equippedArmorIds[itemData.id] then
							isEquipped = true
						end
					else
						-- Check if it's a weapon equipped (primary)
						if equippedId and equippedId == itemData.id then
							isEquipped = true
						end
						-- Check if it's a weapon equipped (secondary)
						if not isEquipped and secondaryEquippedId and secondaryEquippedId == itemData.id then
							isEquipped = true
						end
						-- Check if it's an orb equipped
						if not isEquipped and equippedOrbId and equippedOrbId == itemData.id then
							isEquipped = true
						end
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


task.wait(1)
refreshInventory()
updateCapacityDisplay()

-- Fire InventoryUIReady event for loading manager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local inventoryUIReadyEvent = ReplicatedStorage:FindFirstChild("InventoryUIReady")
if inventoryUIReadyEvent and inventoryUIReadyEvent:IsA("BindableEvent") then
	inventoryUIReadyEvent:Fire()
end

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
		--print("[InventoryUI] InventoryChanged listener connected")
		connections.inventoryChanged = inventoryChangedEvent.OnClientEvent:Connect(function()
			--print("[InventoryUI] InventoryChanged event FIRED!")
			refreshInventory()
			updateCapacityDisplay()
		end)
	else
		warn("[InventoryUI] InventoryChanged event not found - UI won't auto-update on item collection")
	end

	-- Listen for EquippedChanged event for immediate UI update on equip
	local equippedChangedEvent = ReplicatedStorage:FindFirstChild("EquippedChanged")
	if equippedChangedEvent then
		--print("[InventoryUI] EquippedChanged listener connected")
		connections.equippedChanged = equippedChangedEvent.OnClientEvent:Connect(function()
			--print("[InventoryUI] EquippedChanged event FIRED!")
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
