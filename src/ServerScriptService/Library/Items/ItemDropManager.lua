-- ItemDropManager.lua
-- Handles spawning item drops when enemies die

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local ItemDropManager = {}

-- Create a billboard with the item name on top of the item
local function createItemNameBillboard(item, itemName)
	-- Find a suitable part for the billboard (head, primary part, or first part)
	local billboardPart = item:FindFirstChild("Head")
	if not billboardPart then
		billboardPart = item.PrimaryPart
	end
	if not billboardPart then
		-- Find first BasePart
		for _, child in ipairs(item:GetDescendants()) do
			if child:IsA("BasePart") then
				billboardPart = child
				break
			end
		end
	end
	
	if not billboardPart then return end
	
	-- Create billboard GUI
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemNameBillboard"
	billboard.Size = UDim2.new(10, 0, 0.5, 0)
	billboard.MaxDistance = 100
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = billboardPart
	billboard.AlwaysOnTop = true
	
	-- Create text label for item name
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White color
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = itemName
	textLabel.Parent = billboard
	
	-- Add UIStroke for visibility
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(0, 0, 0)
	uiStroke.Thickness = 2
	uiStroke.Parent = textLabel
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel
	
	print("[ItemDropManager] ✅ Item name billboard created for", itemName)
end

-- Spawn an item drop at the specified position
-- Returns the spawned item object
function ItemDropManager.SpawnItemDrop(itemName, spawnPosition, enemyDefeatedByPlayer)
	if not itemName or not spawnPosition then
		return nil
	end
	
	-- Try to find item template in ServerStorage (check both direct and in subfolders)
	local itemTemplate = ServerStorage:WaitForChild("Weapons"):FindFirstChild(itemName)
	if not itemTemplate then
		-- Try to find in Items folder or other locations
		local itemsFolder = ServerStorage:FindFirstChild("Items")
		if itemsFolder then
			itemTemplate = itemsFolder:FindFirstChild(itemName)
		end
	end
	
	if not itemTemplate then
		warn("[ItemDropManager] Item template '" .. itemName .. "' not found in ServerStorage")
		return nil
	end
	
	-- Don't spawn Tools as drops - Tools should only be equipment
	if itemTemplate:IsA("Tool") then
		warn("[ItemDropManager] Cannot drop Tool '" .. itemName .. "' - Tools are equipment only. Use a different item type.")
		return nil
	end
	
	-- Clone the item
	local item = itemTemplate:Clone()
	item.Parent = workspace
	
	-- Store owner (player who dealt most damage) and drop time for pickup restriction
	if enemyDefeatedByPlayer then
		local ownerValue = Instance.new("ObjectValue")
		ownerValue.Name = "DropOwner"
		ownerValue.Value = enemyDefeatedByPlayer
		ownerValue.Parent = item
		
		local dropTimeValue = Instance.new("NumberValue")
		dropTimeValue.Name = "DropTime"
		dropTimeValue.Value = tick()
		dropTimeValue.Parent = item
		
		local pickupRestrictionValue = Instance.new("NumberValue")
		pickupRestrictionValue.Name = "PickupRestrictionDuration"
		pickupRestrictionValue.Value = 10 -- 10 second exclusive ownership window
		pickupRestrictionValue.Parent = item
	end
	
	-- Set primary part if not already set
	local primaryPart = item:FindFirstChild("HumanoidRootPart") or item:FindFirstChild("PrimaryPart")
	if not primaryPart then
		-- Find first BasePart to use as primary
		for _, child in ipairs(item:GetDescendants()) do
			if child:IsA("BasePart") then
				primaryPart = child
				break
			end
		end
	end
	
	if primaryPart then
		item.PrimaryPart = primaryPart
	else
		warn("[ItemDropManager] Could not find any BasePart in item '" .. itemName .. "'")
		return nil
	end
	
	-- Weld all parts to the primary part
	local function weldPartsToRoot(obj, rootPart)
		if not obj or not rootPart then return end
		if obj:IsA("BasePart") and obj ~= rootPart then
			-- Create a WeldConstraint to join this part to the root
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = obj
			weld.Parent = obj
		end
		for _, child in ipairs(obj:GetChildren()) do
			weldPartsToRoot(child, rootPart)
		end
	end
	weldPartsToRoot(item, primaryPart)
	
	-- Anchor the primary part so item stays in place (won't fall due to gravity)
	-- primaryPart.Anchored = true
	
	-- Now position the item using PivotTo while preserving the template's orientation
	local finalSpawnPosition = spawnPosition
	
	-- Get the template's original orientation
	local templatePivot = itemTemplate:GetPivot()
	local templateOrientation = templatePivot - templatePivot.Position -- Extract just the rotation part
	
	-- Create a CFrame with the spawn position but template's orientation
	local finalCFrame = CFrame.new(finalSpawnPosition) * templateOrientation
	item:PivotTo(finalCFrame)
	
	-- Apply collision group for items (same as coins)
	local ITEM_GROUP = "Items"
	pcall(function() PhysicsService:RegisterCollisionGroup(ITEM_GROUP) end)
	-- Always set Items-Env collidability
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Env", true) end)
	-- Set all parts to Items group
	local function setItemCollisionGroup(obj)
		if not obj then return end
		if obj:IsA("BasePart") then 
			obj.CollisionGroup = ITEM_GROUP
		end
		for _, child in ipairs(obj:GetChildren()) do
			setItemCollisionGroup(child)
		end
	end
	setItemCollisionGroup(item)
	
	-- Setup collision relationships for items
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, ITEM_GROUP, true) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Enemies", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Players", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Env", true) end)
	
	-- Tag item so collection script knows to process it
	local tag = item:FindFirstChild("ItemType")
	if not tag then
		tag = Instance.new("StringValue")
		tag.Name = "ItemType"
		tag.Value = "DropItem"
		tag.Parent = item
	else
		tag.Value = "DropItem"
	end
	
	-- Store item name for reference
	local itemNameValue = item:FindFirstChild("ItemName")
	if not itemNameValue then
		itemNameValue = Instance.new("StringValue")
		itemNameValue.Name = "ItemName"
		itemNameValue.Value = itemName
		itemNameValue.Parent = item
	else
		itemNameValue.Value = itemName
	end
	
	-- Store item type (weapon, armor, material, potion, etc.)
	-- Get from WeaponData or use default
	local itemTypeValue = item:FindFirstChild("ItemCategory")
	local itemType = "weapon" -- default
	pcall(function()
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		local weaponStats = WeaponData.GetWeaponStats(itemName)
		if weaponStats and weaponStats.itemType then
			itemType = weaponStats.itemType
		end
	end)
	
	if not itemTypeValue then
		itemTypeValue = Instance.new("StringValue")
		itemTypeValue.Name = "ItemCategory"
		itemTypeValue.Value = itemType
		itemTypeValue.Parent = item
	else
		itemTypeValue.Value = itemType
	end
	
	-- Transparency is handled client-side by ItemTransparencyHandler.client.lua
	-- This allows each player to see different transparency based on ownership
	
	-- Create item name billboard (except for coins)
	if itemName ~= "Coin" and not string.find(itemName:lower(), "coin") then
		createItemNameBillboard(item, itemName)
	end
		
	-- Destroy item after 30 seconds if not collected
	task.delay(30, function()
		if item and item.Parent then
			item:Destroy()
		end
	end)
	
	return item
end

-- Handle enemy drops from enemy stats
-- Returns a table of spawned items
function ItemDropManager.SpawnEnemyDrops(enemyStats, spawnPosition, defeatedByPlayer)
	if not enemyStats or not enemyStats.Drops then
		return {}
	end
	
	local spawnedItems = {}
	
	for _, dropInfo in ipairs(enemyStats.Drops) do
		if dropInfo and dropInfo.itemName and dropInfo.chance then
			-- Roll for drop chance
			local roll = math.random()
			if roll <= dropInfo.chance then
				local item = ItemDropManager.SpawnItemDrop(dropInfo.itemName, spawnPosition, defeatedByPlayer)
				if item then
					table.insert(spawnedItems, item)
				end
			end
		end
	end
	
	return spawnedItems
end

return ItemDropManager
