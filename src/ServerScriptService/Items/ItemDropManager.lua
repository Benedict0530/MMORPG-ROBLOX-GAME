-- ItemDropManager.lua
-- Handles spawning item drops when enemies die

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local ItemDropManager = {}

-- Spawn an item drop at the specified position
-- Returns the spawned item object
function ItemDropManager.SpawnItemDrop(itemName, spawnPosition, enemyDefeatedByPlayer)
	if not itemName or not spawnPosition then
		return nil
	end
	
	-- Try to find item template in ServerStorage (check both direct and in subfolders)
	local itemTemplate = ServerStorage:FindFirstChild(itemName)
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
	primaryPart.Anchored = true
	
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
	
	print("[ItemDropManager] Tagged drop '" .. itemName .. "' with ItemType: " .. tag.Value .. ", ItemName: " .. itemNameValue.Value)
	
	-- Destroy item after 30 seconds if not collected
	task.delay(30, function()
		if item and item.Parent then
			item:Destroy()
		end
	end)
	
	print("[ItemDropManager] Spawned drop: " .. itemName .. " at position " .. tostring(finalSpawnPosition))
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
