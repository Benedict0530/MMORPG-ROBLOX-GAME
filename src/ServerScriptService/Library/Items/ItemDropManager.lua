-- ItemDropManager.lua
-- Handles spawning item drops when enemies die

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

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
	
	--print("[ItemDropManager] ✅ Item name billboard created for", itemName)
end

-- Spawn an item drop at the specified position
-- Returns the spawned item object
function ItemDropManager.SpawnItemDrop(itemName, spawnPosition, enemyDefeatedByPlayer)
	if not itemName or not spawnPosition then
		return nil
	end
	
	-- If this is a spirit orb, use SpawnOrbDrop instead
	if itemName == "Normal Orb" or itemName == "Fire Orb" or itemName == "Water Orb" or itemName == "Wind Orb" or itemName == "Earth Orb" or itemName == "Lightning Orb" or itemName == "Dark Orb" or itemName == "Light Orb" or itemName == "Shadow Orb" or itemName == "Radiant Orb" then
		return ItemDropManager.SpawnOrbDrop(itemName, spawnPosition, enemyDefeatedByPlayer)
	end
	
	-- Try to find item template in ServerStorage (Weapons, Items, Armors)
	local itemTemplate = nil
	local weaponsFolder = ServerStorage:FindFirstChild("Weapons")
	if weaponsFolder then
		itemTemplate = weaponsFolder:FindFirstChild(itemName)
	end
	if not itemTemplate then
		local itemsFolder = ServerStorage:FindFirstChild("Items")
		if itemsFolder then
			itemTemplate = itemsFolder:FindFirstChild(itemName)
		end
	end
	if not itemTemplate then
		local armorsFolder = ServerStorage:FindFirstChild("Armors")
		if armorsFolder then
			itemTemplate = armorsFolder:FindFirstChild(itemName)
			-- Check for subfolders: Suit, Helmet, Legs, Shoes
			if not itemTemplate then
				for _, subfolderName in ipairs({"Suit", "Helmet", "Legs", "Shoes"}) do
					local subfolder = armorsFolder:FindFirstChild(subfolderName)
					if subfolder then
						itemTemplate = subfolder:FindFirstChild(itemName)
						if itemTemplate then break end
					end
				end
			end
		end
	end

	if not itemTemplate then
		warn("[ItemDropManager] Item template '" .. itemName .. "' not found in ServerStorage (Weapons, Items, Armors)")
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
		
		-- Get party members if owner is in a party
		local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))
		local party = PartyDataStore.GetParty(enemyDefeatedByPlayer.UserId)
		if party and #party.members > 0 then
			-- Store all party members as allowed owners
			local partyOwnersValue = Instance.new("ObjectValue")
			partyOwnersValue.Name = "PartyMembers"
			partyOwnersValue.Parent = item
			
			-- Create a table of party member references
			for _, member in ipairs(party.members) do
				if member and member.Parent then
					local memberValue = Instance.new("ObjectValue")
					memberValue.Name = "Member_" .. member.UserId
					memberValue.Value = member
					memberValue.Parent = partyOwnersValue
				end
			end
			--print("[ItemDropManager] ✅ Drop " .. itemName .. " set for party of " .. enemyDefeatedByPlayer.Name .. " (" .. #party.members .. " members)")
		else
			--print("[ItemDropManager] ℹ️ Drop " .. itemName .. " set for solo player " .. enemyDefeatedByPlayer.Name)
		end
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
	local isQuestItem = false
	pcall(function()
		local ItemsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemsData"))
		if ItemsData[itemName] then
			isQuestItem = true
		end
	end)
	if not tag then
		tag = Instance.new("StringValue")
		tag.Name = "ItemType"
		tag.Value = isQuestItem and "questItem" or "DropItem"
		tag.Parent = item
	else
		tag.Value = isQuestItem and "questItem" or "DropItem"
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

	-- Determine item type and category (weapon, armor, etc.)
	local itemTypeValue = item:FindFirstChild("ItemCategory")
	local itemType = "weapon" -- default
	local itemCategory = nil
	local foundType = false
	pcall(function()
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
		local weaponStats = WeaponData.GetWeaponStats(itemName)
		if weaponStats and weaponStats.itemType then
			itemType = weaponStats.itemType
			foundType = true
		end
		if not foundType then
			local armorStats = ArmorData[itemName]
			if armorStats and armorStats.Type then
				itemType = "armor"
				itemCategory = armorStats.Type -- Suit, Helmet, Legs
			end
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
	if itemType == "armor" and itemCategory then
		local armorTypeValue = Instance.new("StringValue")
		armorTypeValue.Name = "ArmorType"
		armorTypeValue.Value = itemCategory
		armorTypeValue.Parent = item
	end
	
	-- Transparency is handled client-side by ItemTransparencyHandler.client.lua
	-- This allows each player to see different transparency based on ownership
	
	-- Create item name billboard (except for coins)
	if itemName ~= "Coin" and not string.find(itemName:lower(), "coin") then
		createItemNameBillboard(item, itemName)
	end
		
	-- Destroy item after 2 minutes if not collected
	task.delay(120, function()
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

-- Spawn a spirit orb drop at the specified position with unique ID
-- itemType should be "spirit orb"
-- Returns the spawned orb object
function ItemDropManager.SpawnOrbDrop(orbName, spawnPosition, enemyDefeatedByPlayer, orbStats)
	if not orbName or not spawnPosition then
		return nil
	end
	
	-- Try to find orb template in ServerStorage
	local orbsFolder = ServerStorage:FindFirstChild("OrbItems")
	if not orbsFolder then
		warn("[ItemDropManager] OrbItems folder not found in ServerStorage")
		return nil
	end
	
	local orbTemplate = orbsFolder:FindFirstChild(orbName)
	if not orbTemplate then
		warn("[ItemDropManager] Orb template '" .. orbName .. "' not found in ServerStorage.OrbItems")
		return nil
	end
	
	-- Clone the orb
	local orb = orbTemplate:Clone()
	orb.Parent = workspace
	
	-- Generate unique ID for this orb instance
	local orbId = orbName .. "_" .. tostring(enemyDefeatedByPlayer and enemyDefeatedByPlayer.UserId or "enemy") .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))
	
	-- Store orb metadata
	if enemyDefeatedByPlayer then
		local ownerValue = Instance.new("ObjectValue")
		ownerValue.Name = "DropOwner"
		ownerValue.Value = enemyDefeatedByPlayer
		ownerValue.Parent = orb
		
		local dropTimeValue = Instance.new("NumberValue")
		dropTimeValue.Name = "DropTime"
		dropTimeValue.Value = tick()
		dropTimeValue.Parent = orb
		
		local pickupRestrictionValue = Instance.new("NumberValue")
		pickupRestrictionValue.Name = "PickupRestrictionDuration"
		pickupRestrictionValue.Value = 10 -- 10 second exclusive ownership window
		pickupRestrictionValue.Parent = orb
		
		-- Get party members if owner is in a party
		local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))
		local party = PartyDataStore.GetParty(enemyDefeatedByPlayer.UserId)
		if party and #party.members > 0 then
			local partyOwnersValue = Instance.new("ObjectValue")
			partyOwnersValue.Name = "PartyMembers"
			partyOwnersValue.Parent = orb
			
			for _, member in ipairs(party.members) do
				if member and member.Parent then
					local memberValue = Instance.new("ObjectValue")
					memberValue.Name = "Member_" .. member.UserId
					memberValue.Value = member
					memberValue.Parent = partyOwnersValue
				end
			end
			--print("[ItemDropManager] ✅ Orb drop " .. orbName .. " set for party of " .. enemyDefeatedByPlayer.Name .. " (" .. #party.members .. " members)")
		else
			--print("[ItemDropManager] ℹ️ Orb drop " .. orbName .. " set for solo player " .. enemyDefeatedByPlayer.Name)
		end
	end
	
	-- Store orb ID
	local orbIdValue = Instance.new("StringValue")
	orbIdValue.Name = "OrbId"
	orbIdValue.Value = orbId
	orbIdValue.Parent = orb
	
	-- Store item type
	local itemTypeValue = orb:FindFirstChild("ItemType")
	if not itemTypeValue then
		itemTypeValue = Instance.new("StringValue")
		itemTypeValue.Name = "ItemType"
		itemTypeValue.Value = "spirit orb"
		itemTypeValue.Parent = orb
	else
		itemTypeValue.Value = "spirit orb"
	end
	
	-- Store orb name
	local orbNameValue = orb:FindFirstChild("OrbName")
	if not orbNameValue then
		orbNameValue = Instance.new("StringValue")
		orbNameValue.Name = "OrbName"
		orbNameValue.Value = orbName
		orbNameValue.Parent = orb
	else
		orbNameValue.Value = orbName
	end
	
	-- Also store as ItemName for ItemCollectionHandler compatibility
	local itemNameValue = orb:FindFirstChild("ItemName")
	if not itemNameValue then
		itemNameValue = Instance.new("StringValue")
		itemNameValue.Name = "ItemName"
		itemNameValue.Value = orbName
		itemNameValue.Parent = orb
	else
		itemNameValue.Value = orbName
	end
	
	-- Set primary part if not already set
	local primaryPart = orb:FindFirstChild("HumanoidRootPart") or orb:FindFirstChild("PrimaryPart")
	if not primaryPart then
		for _, child in ipairs(orb:GetDescendants()) do
			if child:IsA("BasePart") then
				primaryPart = child
				break
			end
		end
	end
	
	if primaryPart then
		orb.PrimaryPart = primaryPart
	else
		warn("[ItemDropManager] Could not find any BasePart in orb '" .. orbName .. "'")
		return nil
	end
	
	-- Weld all parts to the primary part
	local function weldPartsToRoot(obj, rootPart)
		if not obj or not rootPart then return end
		if obj:IsA("BasePart") and obj ~= rootPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = obj
			weld.Parent = obj
		end
		for _, child in ipairs(obj:GetChildren()) do
			weldPartsToRoot(child, rootPart)
		end
	end
	weldPartsToRoot(orb, primaryPart)
	
	-- Position the orb
	local templatePivot = orbTemplate:GetPivot()
	local templateOrientation = templatePivot - templatePivot.Position
	local finalCFrame = CFrame.new(spawnPosition) * templateOrientation
	orb:PivotTo(finalCFrame)
	
	-- Apply collision group for items
	local ITEM_GROUP = "Items"
	pcall(function() PhysicsService:RegisterCollisionGroup(ITEM_GROUP) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Env", true) end)
	
	local function setItemCollisionGroup(obj)
		if not obj then return end
		if obj:IsA("BasePart") then 
			obj.CollisionGroup = ITEM_GROUP
		end
		for _, child in ipairs(obj:GetChildren()) do
			setItemCollisionGroup(child)
		end
	end
	setItemCollisionGroup(orb)
	
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, ITEM_GROUP, true) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Enemies", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Players", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ITEM_GROUP, "Env", true) end)
	
	-- Create orb name billboard
	createItemNameBillboard(orb, orbName)
	
	-- Destroy orb after 2 minutes if not collected
	task.delay(120, function()
		if orb and orb.Parent then
			orb:Destroy()
		end
	end)
	
	--print("[ItemDropManager] ✅ Orb drop spawned: " .. orbName .. " (id: " .. orbId .. ")")
	return orb
end

return ItemDropManager
