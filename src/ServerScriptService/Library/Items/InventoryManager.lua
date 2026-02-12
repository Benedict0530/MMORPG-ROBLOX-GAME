
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- DataStore
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

-- InventoryManager Table
local InventoryManager = {}

-- Internal State
local equipLocks = {}           -- Per-player equip lock to prevent overlapping equip/sync
local connectInProgress = {}    -- Per-player connection state
local playerInventories = {}    -- Table to track inventories in memory
local inventoriesLoaded = {}    -- Table to track when inventory is loaded for each player
local inventoriesLoading = {}   -- Table to track if inventory is currently loading (prevents race condition)
local itemIdCounter = 0         -- Counter for unique item IDs

-- Default inventory (new format with IDs and itemType)
local DEFAULT_INVENTORY = {
	{ name = "Twig", id = "item_default_twig_1", itemType = "weapon" }
}

-- Helper: Get a safe userId from player or fallback

local function getUserId(player)
	return (typeof(player) == "Instance" and player:IsA("Player")) and player.UserId or tostring(player)
end



local function generateUniqueItemId(itemName, player)
	local userId = player and getUserId(player) or "0"
	return string.format("%s_%s_%d_%d", itemName, userId, os.time(), math.random(100000,999999))
end


-- Create a fresh default inventory and equipped info for a new player

function InventoryManager.CreateStarterWeaponAndEquipped()
	local twigId = generateUniqueItemId("Twig")
	local twig = { name = "Twig", id = twigId, itemType = "weapon" }
	local orbId = generateUniqueItemId("Normal Orb")
	local normalOrb = { name = "Normal Orb", id = orbId, itemType = "spirit orb" }
	-- Give both Twig and Normal Orb, and return both as equipped for auto-equip logic
	-- Return equipped as a table of both items
	return { twig, normalOrb }, { twig, normalOrb }
end

-- For compatibility, keep createDefaultInventory for migration/legacy

local function createDefaultInventory()
	local inventory = select(1, InventoryManager.CreateStarterWeaponAndEquipped())
	return inventory
end

-- Helper: Get equipped weapon data from folder structure
local function getEquippedWeapon(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	
	local equippedFolder = stats:FindFirstChild("Equipped")
	if not equippedFolder or not equippedFolder:IsA("Folder") then return nil end
	
	local nameValue = equippedFolder:FindFirstChild("name")
	local idValue = equippedFolder:FindFirstChild("id")
	
	if not nameValue or not idValue then return nil end
	
	return {
		name = nameValue.Value,
		id = idValue.Value
	}
end

-- Helper: Set equipped weapon data in folder structure
function InventoryManager.setEquippedWeapon(player, weaponName, itemId)
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		-- Only allow equipping if weaponName is a valid weapon in WeaponData
		if not WeaponData.Weapons[weaponName] then
			warn("[InventoryManager] setEquippedWeapon: Attempted to equip non-weapon '" .. tostring(weaponName) .. "' for " .. player.Name)
			return
		end
	local WeaponManager = require(script.Parent.WeaponManager)
	local userId = getUserId(player)
	if equipLocks[userId] then
		warn("[InventoryManager] Equip already in progress for " .. player.Name .. ", skipping.")
		return
	end
	equipLocks[userId] = true
	if connectInProgress[userId] then
		warn("[InventoryManager] Connect already in progress for " .. player.Name .. ", skipping.")
		WeaponManager.blockSwingEvent[player] = nil
		equipLocks[userId] = nil
		return
	end
	connectInProgress[userId] = true
	WeaponManager.blockSwingEvent[player] = true
	-- Robustly wait for dependencies (Stats, Equipped folder, Weapons folder)
	local stats, equippedFolder, weaponsFolder
	local maxWait, waited = 2, 0
	while waited < maxWait do
		stats = player:FindFirstChild("Stats")
		if stats then
			equippedFolder = stats:FindFirstChild("Equipped")
		end
		weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
		if stats and equippedFolder and equippedFolder:IsA("Folder") and weaponsFolder then
			break
		end
		task.wait(0.1)
		waited = waited + 0.1
	end
	   local function clearLocks()
		   WeaponManager.blockSwingEvent[player] = nil
		   equipLocks[userId] = nil
		   connectInProgress[userId] = nil
	   end
	   if not stats then
		   --print("[InventoryManager] FAILED: No Stats found for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end
	   if not equippedFolder or not equippedFolder:IsA("Folder") then
		   --print("[InventoryManager] FAILED: No Equipped folder for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end
	   if not weaponsFolder then
		   --print("[InventoryManager] FAILED: Weapons folder not found in ReplicatedStorage for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end

	local nameValue = equippedFolder:FindFirstChild("name")
	local idValue = equippedFolder:FindFirstChild("id")

	if nameValue then nameValue.Value = weaponName end
	if idValue then idValue.Value = itemId end

	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveStats(player, false)

	-- Remove all tools from player and character (backpack and hand)
	for _, tool in ipairs(player:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
	if player.Character then
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") then
				tool:Destroy()
			end
		end
	end

	local baseWeaponName = weaponName:match("^([^_]+)") or weaponName
	local tool = weaponsFolder:FindFirstChild(baseWeaponName)
	if not tool then
		--print("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
		clearLocks()
		return
	end
	local clone = tool:Clone()
	clone.Parent = player
	clone:SetAttribute("_ItemId", itemId)
	clone:SetAttribute("_OwnerUserId", player.UserId)
	--print("[InventoryManager] Weapon CREATED for " .. player.Name .. ": " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")

	-- Wait a bit longer for tool to replicate under heavy load
	task.wait(0.15)
	-- Wait for character and humanoid
	local character, humanoid
	waited = 0
	while waited < maxWait do
		character = player.Character
		if character then
			humanoid = character:FindFirstChild("Humanoid")
		end
		if character and humanoid then break end
		task.wait(0.1)
		waited = waited + 0.1
	end
	local equipped = false
	if character then
		if humanoid then
			local maxTries = 4
			for try = 1, maxTries do
				local success, err = pcall(function()
					humanoid:EquipTool(clone)
				end)
				if not success then
					--print("[InventoryManager] FAILED: Could not equip tool '" .. clone.Name .. "' for " .. player.Name .. " (try " .. try .. "): " .. tostring(err))
				else
					--print("[InventoryManager] Weapon EQUIPPED for " .. player.Name .. ": " .. clone.Name .. " (try " .. try .. ")")
				end
				task.wait(0.15)
				if clone.Parent == character then
					equipped = true
					break
				end
			end
			if not equipped then
				--print("[InventoryManager] FAILED: Tool '" .. clone.Name .. "' could not be equipped after retries for " .. player.Name)
			else
				local ok, err2 = pcall(function()
					WeaponManager.ConnectTool(clone, player)
				end)
				if ok then
					--print("[InventoryManager] CONNECTED: " .. player.Name .. " - " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")
					for i = 1, 5 do
						if connectInProgress[player] ~= true then break end
						if WeaponManager.CleanupPlayerTools then
							WeaponManager.CleanupPlayerTools(player)
						end
						task.wait(0.05)
						local ok2, err3 = pcall(function()
							WeaponManager.ConnectTool(clone, player)
						end)
						if ok2 then
							--print("[InventoryManager] RE-CONNECTED (" .. i .. "): " .. player.Name .. " - " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")
						else
							--print("[InventoryManager] FAILED: re-connect (" .. i .. ") '" .. clone.Name .. "' for " .. player.Name .. ": " .. tostring(err3))
						end
					end
				else
					--print("[InventoryManager] FAILED: connect '" .. clone.Name .. "' after equip for " .. player.Name .. ": " .. tostring(err2))
				end
			end
		else
			--print("[InventoryManager] FAILED: No Humanoid found for " .. player.Name)
		end
	else
		--print("[InventoryManager] FAILED: No Character found for " .. player.Name)
	end
	
	-- Fire EquippedChanged event for quick UI update (equipped indicator)
	local equippedChangedEvent = ReplicatedStorage:FindFirstChild("EquippedChanged")
	if equippedChangedEvent then
		equippedChangedEvent:FireClient(player)
	end
	
	clearLocks()
end

-- Throttle settings for inventory saves
-- IMPORTANT: Must match or be less than UnifiedDataStoreManager.CONFIG.THROTTLE_INTERVAL (5s)
local SAVE_THROTTLE_INTERVAL = 4 -- Save inventory every 4 seconds max (less than 5s to avoid conflicts)
local lastInventorySaveTime = {}
local pendingInventoryChanges = {}

-- Migrate inventory data to ensure proper format (convert old string array to new table with IDs and itemType)
local function migrateData(oldData)
	-- Ensure oldData is a table
	if not oldData or type(oldData) ~= "table" then
		warn("[InventoryManager] 🚨 Inventory data corrupted or missing - using default")
		return createDefaultInventory()
	end
	
	-- If empty, default to Twig
	if #oldData == 0 then
		warn("[InventoryManager] ⚠️ Inventory is empty - assigning default Twig")
		return createDefaultInventory()
	end
	
	-- SAFEGUARD: Check if data looks corrupted (size mismatch)
	-- If inventory suddenly shrunk significantly, something is wrong
	if #oldData > 100 then
		warn("[InventoryManager] 🚨 Inventory size suspicious (" .. #oldData .. " items) - possible corruption")
		-- Don't return default, but return the data as-is to investigate
	end
	
	-- Check if already in new format (first element is a table with 'name' and 'id')
	if oldData[1] and type(oldData[1]) == "table" and oldData[1].name and oldData[1].id then
		--print("[InventoryManager] ✅ Inventory already in correct format with " .. #oldData .. " items")
		-- Ensure itemType exists for all items (backward compatibility)
		for _, item in ipairs(oldData) do
			if not item.itemType then
				-- Try to infer from item name using WeaponData
				local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
				local weaponStats = WeaponData.GetWeaponStats(item.name)
				item.itemType = weaponStats and weaponStats.itemType or "weapon" -- Default to weapon if not found
			end
		end
		return oldData
	end
	
	-- Convert from old format (array of strings) to new format (array of tables with itemType)
	local newData = {}
	local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
	
	for _, itemName in ipairs(oldData) do
		if type(itemName) == "string" then
			-- Try to get itemType from WeaponData, default to "weapon"
			local weaponStats = WeaponData.GetWeaponStats(itemName)
			local itemType = weaponStats and weaponStats.itemType or "weapon"
			
			table.insert(newData, {
				name = itemName,
				id = generateUniqueItemId(itemName),
				itemType = itemType
			})
		end
	end
	
	--print("[InventoryManager] ✅ Migrated inventory from old format: " .. #newData .. " items")
	return #newData > 0 and newData or createDefaultInventory()
end

-- Save inventory to DataStore (throttled)
function InventoryManager.SaveInventory(player, forceImmediate)
	local userId = player.UserId
	local data = playerInventories[userId] or {}
	
	-- CRITICAL SAFEGUARD: Prevent data loss from empty saves
	if not data or type(data) ~= "table" then
		warn("[InventoryManager] ⚠️ CRITICAL: Inventory data is nil or invalid for " .. player.Name .. " (userId: " .. userId .. ") - aborting save to prevent data loss")
		return false
	end
	
	-- SAFEGUARD: Validate inventory before saving
	-- Never save empty inventory unless player is completely new (0 items intentional)
	if #data == 0 then
		-- If player already had items loaded, don't save empty data
		if inventoriesLoaded[userId] and inventoriesLoaded[userId] == true then
			warn("[InventoryManager] ⚠️ Prevented save of EMPTY inventory for " .. player.Name .. " - data loss protection!")
			return false  -- Don't save empty data over good data
		end
	end
	
	-- Additional safeguard: If we're about to save, verify current in-memory data is reasonable
	if #data > 1000 then
		warn("[InventoryManager] ⚠️ CRITICAL: Inventory size suspiciously large (" .. #data .. ") - possible data corruption, aborting save")
		return false
	end
	
	--print("[InventoryManager] Saving inventory for " .. player.Name .. ": " .. #data .. " items (forceImmediate=" .. tostring(forceImmediate) .. ")")
	for i, item in ipairs(data) do
		--print("[InventoryManager]   Item " .. i .. ": " .. item.name)
	end
	
	-- Deep copy data to prevent external modifications during save
	local dataCopy = {}
	for _, item in ipairs(data) do
		table.insert(dataCopy, {
			name = item.name,
			id = item.id,
			itemType = item.itemType
		})
	end
	
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveInventory(userId, dataCopy, forceImmediate)
end

-- Add item to inventory with unique ID and item type
function InventoryManager.AddItem(player, itemName, itemType)
	local userId = player.UserId
	
	-- CRITICAL FIX: Ensure playerInventories[userId] is initialized
	if not playerInventories[userId] or type(playerInventories[userId]) ~= "table" then
		warn("[InventoryManager] ⚠️ Inventory not properly initialized for " .. player.Name .. " (userId: " .. userId .. ") - reinitializing")
		-- Attempt to load from DataStore again
		InventoryManager.LoadInventory(player)
		-- If still not initialized, use default
		if not playerInventories[userId] or type(playerInventories[userId]) ~= "table" then
			playerInventories[userId] = createDefaultInventory()
		end
	end
	
	-- CRITICAL: Prevent adding to nil inventory
	if not playerInventories[userId] or type(playerInventories[userId]) ~= "table" or #playerInventories[userId] < 0 then
		warn("[InventoryManager] 🚨 CRITICAL: Inventory still invalid after init attempt for " .. player.Name .. " - aborting AddItem to prevent data loss")
		return false, "Inventory initialization failed"
	end
	
	-- Check inventory capacity before adding
	local stats = player:FindFirstChild("Stats")
	if stats then
		local maxCapacity = stats:FindFirstChild("InventoryMaxCapacity")
		if maxCapacity then
			local currentItemCount = #playerInventories[userId]
			if currentItemCount >= maxCapacity.Value then
				warn("[InventoryManager] Inventory full for " .. player.Name .. " (" .. currentItemCount .. "/" .. maxCapacity.Value .. ")")
				return false, "Inventory is full!"
			end
		end
	end
	
	-- Validate and correct itemType: only allow "armor", "weapon", "spirit orb"
	local validTypes = { ["armor"] = true, ["weapon"] = true, ["spirit orb"] = true }
	if not itemType or not validTypes[itemType] then
		local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
		if ArmorData[itemName] and ArmorData[itemName].itemType == "armor" then
			itemType = "armor"
		else
			local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
			local weaponStats = WeaponData.GetWeaponStats(itemName)
			itemType = weaponStats and weaponStats.itemType or "weapon"
		end
	end
	
	-- Create new item entry with unique ID and itemType
	local newItem = {
		name = itemName,
		id = generateUniqueItemId(itemName, player),
		itemType = itemType
	}
	table.insert(playerInventories[userId], newItem)
	
	--print("[InventoryManager] Added item to " .. player.Name .. ": name=" .. newItem.name .. ", id=" .. newItem.id .. ", itemType=" .. newItem.itemType)
	--print("[InventoryManager] Inventory now has " .. #playerInventories[userId] .. " items")
	
	-- Update capacity stat to reflect current inventory count
	if stats then
		local capacityValue = stats:FindFirstChild("InventoryCapacity")
		if capacityValue then
			capacityValue.Value = #playerInventories[userId]
		end
	end
	
	-- Item added to inventory, trigger IMMEDIATE save
	InventoryManager.SaveInventory(player, true) -- Force immediate save

	-- Notify client that inventory has changed (always fire after data change)
	local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
	if inventoryChangedEvent then
		inventoryChangedEvent:FireClient(player)
	end

	return true, newItem.id
end

-- Remove item from inventory by ID
function InventoryManager.RemoveItem(player, itemId)
	local userId = player.UserId
	playerInventories[userId] = playerInventories[userId] or {}
	for i, item in ipairs(playerInventories[userId]) do
		if item.id == itemId then
			table.remove(playerInventories[userId], i)

			-- Update capacity stat to reflect current inventory count
			local stats = player:FindFirstChild("Stats")
			if stats then
				local capacityValue = stats:FindFirstChild("InventoryCapacity")
				if capacityValue then
					capacityValue.Value = #playerInventories[userId]
				end
			end

			   -- Item removed from inventory, trigger IMMEDIATE save
			   InventoryManager.SaveInventory(player, true) -- Force immediate save

			-- Notify client that inventory has changed (always fire after data change)
			local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
			if inventoryChangedEvent then
				inventoryChangedEvent:FireClient(player)
			end

			return true
		end
	end
	return false
end

-- Helper: Get item by ID
function InventoryManager.GetItemById(player, itemId)
	local userId = player.UserId
	local inventory = playerInventories[userId] or {}
	for _, item in ipairs(inventory) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

-- Get inventory table
function InventoryManager.GetInventory(player)
	return playerInventories[player.UserId] or {}
end

-- Load inventory from DataStore
function InventoryManager.LoadInventory(player)
	local userId = player.UserId
	local data
	
	-- Mark as loading to prevent race conditions
	inventoriesLoading[userId] = true
	--print("[InventoryManager] 🔄 Loading inventory for " .. player.Name .. " (UserId: " .. userId .. ")")
	
	-- CRITICAL: Don't reload if already loaded in this session (prevents overwriting with stale DataStore data)
	if inventoriesLoaded[userId] and inventoriesLoaded[userId] == true then
		--print("[InventoryManager] ✅ Inventory already loaded for " .. player.Name .. " - skipping reload to prevent data loss")
		inventoriesLoading[userId] = false
		return
	end
	
	-- Load from unified manager with retry logic
	local retries = 0
	local maxRetries = 3
	while retries < maxRetries do
		data = UnifiedDataStoreManager.LoadInventory(userId)
		if data ~= nil then
			break
		end
		retries = retries + 1
		if retries < maxRetries then
			warn("[InventoryManager] LoadInventory returned nil, retrying... (" .. retries .. "/" .. maxRetries .. ")")
			task.wait(0.5) -- Wait before retry
		end
	end
	
	--print("[InventoryManager] Loaded data from DataStore: " .. tostring(data) .. " (retries: " .. retries .. ")")
	
	if type(data) == "table" then
	local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
		playerInventories[userId] = migrateData(data)
		--print("[InventoryManager] ✅ Successfully loaded inventory with " .. #playerInventories[userId] .. " items")
	elseif data == nil then
		-- DataStore load failed - create default but mark as needing save
			-- Default itemType detection: check ArmorData first, then WeaponData, then fallback
			local itemType = nil
			if ArmorData[itemName] and ArmorData[itemName].itemType == "armor" then
				itemType = "armor"
			else
				local weaponStats = WeaponData.GetWeaponStats(itemName)
				itemType = weaponStats and weaponStats.itemType or "weapon"
			end
		playerInventories[userId] = createDefaultInventory()
		warn("[InventoryManager] ⚠️ DataStore load failed for " .. player.Name .. " - using default inventory")
	else
		playerInventories[userId] = createDefaultInventory()
		--print("[InventoryManager] Created default inventory (loaded data was not a table)")
	end
	
	-- CRITICAL: Validate inventory is never nil or invalid
	if not playerInventories[userId] or type(playerInventories[userId]) ~= "table" then
		warn("[InventoryManager] 🚨 CRITICAL: Inventory is still invalid after load attempt - forcing default")
		playerInventories[userId] = createDefaultInventory()
	end
	
	-- Update InventoryCapacity stat to reflect actual inventory count
	local stats = player:FindFirstChild("Stats")
	if stats then
		local capacityValue = stats:FindFirstChild("InventoryCapacity")
		if capacityValue then
			capacityValue.Value = #playerInventories[userId]
		end
	end
	
	-- Mark inventory as loaded IMMEDIATELY
	inventoriesLoaded[userId] = true
	inventoriesLoading[userId] = false
	--print("[InventoryManager] ✅ Inventory loading complete for " .. player.Name .. " with " .. #playerInventories[userId] .. " items")
end

-- Sync Backpack with inventory
function InventoryManager.SyncBackpack(player, character)
	local WeaponManager = require(script.Parent.WeaponManager)
	if equipLocks[player] then
		--print("[InventoryManager] SyncBackpack already in progress for " .. player.Name .. ", skipping.")
		return
	end
	equipLocks[player] = true
	if connectInProgress[player] then
		warn("[InventoryManager] Connect already in progress for " .. player.Name .. ", skipping.")
		equipLocks[player] = nil
		return
	end
	connectInProgress[player] = true
	-- Robustly wait for humanoid and weaponsFolder
	local humanoid, weaponsFolder
	local maxWait, waited = 2, 0
	while waited < maxWait do
		humanoid = character:FindFirstChild("Humanoid")
		weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
		if humanoid and weaponsFolder then break end
		task.wait(0.1)
		waited = waited + 0.1
	end
	if not humanoid then
		--print("[InventoryManager] FAILED: Humanoid not found for " .. player.Name .. " after wait")
		equipLocks[player] = nil
		connectInProgress[player] = nil
		return
	end
	for _, tool in ipairs(player:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
	if not weaponsFolder then
		--print("[InventoryManager] FAILED: Weapons folder not found in ReplicatedStorage for " .. player.Name .. " after wait")
		equipLocks[player] = nil
		connectInProgress[player] = nil
		return
	end
	local inventory = playerInventories[player.UserId] or {}
	if #inventory == 0 then
		inventory = createDefaultInventory()
	end
	local equippedWeaponName = nil
	local equippedItemId = nil
	local stats = player:FindFirstChild("Stats")
	local equipped = getEquippedWeapon(player)
	if equipped then
		-- Only treat as weapon if it's a valid weapon in WeaponData
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		if equipped.name and WeaponData.Weapons[equipped.name] then
			equippedWeaponName = equipped.name
			equippedItemId = equipped.id
		else
			equippedWeaponName = nil
			equippedItemId = nil
		end
	end
	
			   -- Only auto-equip a weapon for new players (handled in GiveStartingItemsIfNew). Do NOT auto-equip on unequip or weapon change.
			   -- If equippedWeaponName is empty, do nothing. Do not auto-equip here.
			   if (not equippedWeaponName or equippedWeaponName == "") then
				   --print("[InventoryManager] No equipped weapon for " .. player.Name .. ". Not auto-equipping (handled only for new players).")
			   end

			   -- (Auto-equip of spirit orbs is now disabled except by explicit player action)
	local equippedTool = nil
	if equippedWeaponName and equippedWeaponName ~= "" then
		-- Final safeguard: do not equip if this is a questItem
		local equippedItem = nil
		for _, item in ipairs(inventory) do
			if item.name == equippedWeaponName and item.id == equippedItemId then
				equippedItem = item
				break
			end
		end
		if equippedItem and equippedItem.Type == "questItem" then
			--print("[InventoryManager] SAFEGUARD: Equipped item '" .. tostring(equippedWeaponName) .. "' is a questItem. Giving Twig instead.")
			local twigId = generateUniqueItemId("Twig", player)
			local twigItem = { name = "Twig", id = twigId, itemType = "weapon" }
			table.insert(inventory, twigItem)
			equippedWeaponName = twigItem.name
			equippedItemId = twigItem.id
			InventoryManager.setEquippedWeapon(player, equippedWeaponName, equippedItemId)
			InventoryManager.SaveInventory(player, true)
		end
		local baseWeaponName = equippedWeaponName:match("^([^_]+)") or equippedWeaponName
		local tool = weaponsFolder:FindFirstChild(baseWeaponName)
		if not tool then
			warn("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
			-- Don't return, try to equip something else
		else
			local clone = tool:Clone()
			clone.Parent = player
			clone:SetAttribute("_ItemId", equippedItemId)
			clone:SetAttribute("_OwnerUserId", player.UserId)
			--print("[InventoryManager] Weapon CREATED for " .. player.Name .. ": " .. clone.Name .. " (id: " .. tostring(equippedItemId) .. ")")
			task.wait(0.15)
			if clone.Parent ~= player then
				--print("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' parent changed, retrying for " .. player.Name)
				clone = player:FindFirstChild(baseWeaponName)
				if not clone then
					--print("[InventoryManager] FAILED: Could not recover tool '" .. baseWeaponName .. "' for " .. player.Name)
				end
			end
			if clone and clone.Parent == player then
				equippedTool = clone
			end
		end
	end
	
			   -- If equippedTool is nil, try to find any valid weapon from inventory as fallback (must exist in WeaponData)
			   -- Only give fallback Twig if inventory has more than 1 item (prevents overlap with starter logic for new players)
			   if not equippedTool and #inventory > 0 then
				   --print("[InventoryManager] ⚠️ Fallback: No equipped tool found, trying first valid weapon from WeaponData for " .. player.Name)
				   local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
				   local firstWeapon = nil
				   for _, item in ipairs(inventory) do
					   if item.itemType == "weapon" and WeaponData.Weapons[item.name] then
						   firstWeapon = item
						   break
					   end
				   end
				   if firstWeapon then
					   local baseWeaponName = firstWeapon.name:match("^([^_]+)") or firstWeapon.name
					   local tool = weaponsFolder:FindFirstChild(baseWeaponName)
					   if tool then
						   local clone = tool:Clone()
						   clone.Parent = player
						   clone:SetAttribute("_ItemId", firstWeapon.id)
						   clone:SetAttribute("_OwnerUserId", player.UserId)
						   --print("[InventoryManager] Fallback: Created weapon " .. clone.Name .. " from inventory")
						   task.wait(0.15)
						   if clone.Parent == player then
							   equippedTool = clone
							   equippedItemId = firstWeapon.id
						   end
					   else
						   --print("[InventoryManager] Fallback: Weapon '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons")
					   end
				   else
					   -- No valid weapon found at all, only give Twig if inventory has more than 1 item (not a new player)
					   if #inventory > 1 then
						   --print("[InventoryManager] Fallback: No valid weapon items from WeaponData found in inventory (only orbs/questItems?) - giving Twig.")
						   local twigId = generateUniqueItemId("Twig", player)
						   local twigItem = { name = "Twig", id = twigId, itemType = "weapon" }
						   table.insert(inventory, twigItem)
						   local baseWeaponName = twigItem.name
						   local tool = weaponsFolder:FindFirstChild(baseWeaponName)
						   if tool then
							   local clone = tool:Clone()
							   clone.Parent = player
							   clone:SetAttribute("_ItemId", twigItem.id)
							   clone:SetAttribute("_OwnerUserId", player.UserId)
							   --print("[InventoryManager] Fallback: Created Twig for " .. player.Name)
							   task.wait(0.15)
							   if clone.Parent == player then
								   equippedTool = clone
								   equippedItemId = twigItem.id
								   InventoryManager.setEquippedWeapon(player, twigItem.name, twigItem.id)
								   InventoryManager.SaveInventory(player, true)
							   end
						   else
							   --print("[InventoryManager] Fallback: Twig not found in ReplicatedStorage.Weapons!")
						   end
					   else
						   --print("[InventoryManager] Fallback: Not giving Twig because inventory has 1 or fewer items (likely new player)")
					   end
				   end
			   end
	if equippedTool then
		task.wait(0.15)
		if not equippedTool or equippedTool.Parent ~= player then
			--print("[InventoryManager] FAILED: Equipped tool no longer in player backpack for " .. player.Name)
			equipLocks[player] = nil
			connectInProgress[player] = nil
			return
		end
		if not humanoid or not character.Parent or humanoid.Health <= 0 then
			--print("[InventoryManager] FAILED: Humanoid invalid or character dead before equipping for " .. player.Name)
			equipLocks[player] = nil
			connectInProgress[player] = nil
			return
		end
		
		-- Try to equip with multiple retries
		local equipped = false
		for attempt = 1, 3 do
			if equippedTool and equippedTool.Parent == player then
				local success, err = pcall(function()
					humanoid:EquipTool(equippedTool)
				end)
				if success then
					task.wait(0.1)
					-- Check if actually equipped
					if equippedTool.Parent == character then
						--print("[InventoryManager] Weapon EQUIPPED for " .. player.Name .. ": " .. equippedTool.Name .. " (attempt " .. attempt .. ")")
						equipped = true
						break
					else
						--print("[InventoryManager] Equip attempt " .. attempt .. " failed - tool not in character for " .. player.Name)
					end
				else
					--print("[InventoryManager] Equip attempt " .. attempt .. " failed with error: " .. tostring(err))
				end
			end
			
			if attempt < 3 then
				task.wait(0.2)
			end
		end
		
		if equipped then
			-- Mark player as fully loaded after successful weapon equip
			local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
			DamageManager.MarkPlayerLoaded(player)
		else
			--print("[InventoryManager] ⚠️ WARNING: Could not equip weapon for " .. player.Name .. " after 3 attempts")
		end
		
		-- Final connection attempt
		if equippedTool and equippedTool.Parent == character then
			local success2, err2 = pcall(function()
				WeaponManager.ConnectTool(equippedTool, player)
			end)
			if success2 then
				--print("[InventoryManager] CONNECTED: " .. player.Name .. " - " .. equippedTool.Name .. " (id: " .. tostring(equippedItemId) .. ")")
				for i = 1, 3 do
					if connectInProgress[player] ~= true then break end
					if WeaponManager.CleanupPlayerTools then
						WeaponManager.CleanupPlayerTools(player)
					end
					task.wait(0.5)
					local ok2, err3 = pcall(function()
						WeaponManager.ConnectTool(equippedTool, player)
					end)
					if ok2 then
						-- Successfully reconnected
					else
						--print("[InventoryManager] FAILED: re-connect (" .. i .. ") '" .. equippedTool.Name .. "' for " .. player.Name .. ": " .. tostring(err3))
					end
				end
			else
				--print("[InventoryManager] FAILED: connect '" .. equippedTool.Name .. "' after equip for " .. player.Name .. ": " .. tostring(err2))
			end
		else
			--print("[InventoryManager] FAILED: Tool is not in character after equipping for " .. player.Name)
		end
	else
		--print("[InventoryManager] ⚠️ WARNING: No weapon to equip for " .. player.Name)
	end
	equipLocks[player] = nil
	connectInProgress[player] = nil
end


-- Give starting items to player (only if new)
function InventoryManager.GiveStartingItemsIfNew(player)
	local userId = player.UserId
	
	-- CRITICAL: Wait for inventory to finish loading before checking if player needs starter items
	-- Using 60 seconds to handle edge cases (server lag, heavy load, etc.)
	local maxWait = 60
	local waited = 0
	local startTime = tick()
	
	--print("[InventoryManager] ⏳ Waiting for inventory to load for " .. player.Name .. "...")
	
	-- Wait for loading flag to clear (means LoadInventory completed or failed)
	while inventoriesLoading[userId] and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
		
		-- Log progress every 10 seconds to detect stuck loads
		if waited % 10 == 0 then
			warn("[InventoryManager] ⏰ Still waiting for inventory load after " .. waited .. "s for " .. player.Name)
		end
	end
	
	local loadTime = tick() - startTime
	
	-- If still loading after timeout, it's likely stuck or DataStore issues
	if inventoriesLoading[userId] then
		warn("[InventoryManager] 🚨 CRITICAL: Inventory still loading for " .. player.Name .. " after " .. maxWait .. "s - ABORTING to prevent data loss. Player should rejoin.")
		-- Mark as loaded to prevent retry loops, but don't give items
		inventoriesLoading[userId] = false
		return
	end
	
	-- Wait for loaded flag to be set (confirms LoadInventory completed successfully)
	waited = 0
	while not inventoriesLoaded[userId] and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
		
		if waited % 10 == 0 then
			warn("[InventoryManager] ⏰ Still waiting for inventory loaded flag after " .. waited .. "s for " .. player.Name)
		end
	end
	
	-- If loaded flag not set, LoadInventory failed or had issues
	if not inventoriesLoaded[userId] then
		warn("[InventoryManager] 🚨 CRITICAL: Inventory not marked as loaded for " .. player.Name .. " after " .. maxWait .. "s - ABORTING to prevent data loss. Player should rejoin.")
		return
	end
	
	--print("[InventoryManager] ✅ Inventory loaded successfully in " .. string.format("%.2f", loadTime) .. "s for " .. player.Name)
	
	local inventory = InventoryManager.GetInventory(player)
	--print("[InventoryManager] Checking if " .. player.Name .. " needs starter items. Current inventory size: " .. #inventory)
	
	-- Wait for Stats and Equipped folder
	local stats = player:FindFirstChild("Stats")
	waited = 0
	local statsMaxWait = 5
	while (not stats or not stats:FindFirstChild("Equipped")) and waited < statsMaxWait do
		task.wait(0.1)
		stats = player:FindFirstChild("Stats")
		waited = waited + 0.1
	end
	   -- Only give starter items if inventory is empty AND no weapon is equipped
	   local hasWeaponEquipped = false
	   if stats then
		   local equippedFolder = stats:FindFirstChild("Equipped")
		   if equippedFolder and equippedFolder:IsA("Folder") then
			   local nameValue = equippedFolder:FindFirstChild("name")
			   if nameValue and typeof(nameValue.Value) == "string" and nameValue.Value ~= "" then
				   -- Check if equipped item is a weapon in inventory
				   for _, item in ipairs(inventory) do
					   if item.name == nameValue.Value and item.itemType == "weapon" then
						   hasWeaponEquipped = true
						   break
					   end
				   end
			   end
		   end
	   end
	   if #inventory < 1 and not hasWeaponEquipped then
		   --print("[InventoryManager] ⚠️ Player " .. player.Name .. " confirmed as NEW (inventory empty and no weapon equipped). Creating starter items.")
		   -- Only create starter inventory/equipped if missing (should only happen for new players)
		   local starterInventory, equipped = InventoryManager.CreateStarterWeaponAndEquipped()
		   playerInventories[userId] = starterInventory
		   -- Add starter items to inventory first, then equip
		   local starterWeapon, starterOrb = nil, nil
		   for _, item in ipairs(starterInventory) do
			   if item.itemType == "weapon" then
				   starterWeapon = item
			   elseif item.itemType == "spirit orb" then
				   starterOrb = item
			   end
		   end
		   -- Equip weapon first if present
		   if starterWeapon then
			   InventoryManager.setEquippedWeapon(player, starterWeapon.name, starterWeapon.id)
		   end
		   -- Do NOT auto-equip orb; just add to inventory
		   InventoryManager.SaveInventory(player, true)
		   local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		   UnifiedDataStoreManager.SaveStats(player, false)
	   else
		   --print("[InventoryManager] Player already has items and equipped weapon, skipping starting item to prevent item loss")
	   end
end

-- Initialize player inventory (called from Init.server.lua for existing players)
function InventoryManager.InitializePlayer(player)
	--print("[InventoryManager] InitializePlayer called for " .. player.Name)
	
	-- Load inventory
	InventoryManager.LoadInventory(player)
	
	-- Give starting items if new
	InventoryManager.GiveStartingItemsIfNew(player)
	
	-- Auto-equip Normal Orb is now disabled per new requirements
	
	-- Sync backpack if character exists
	if player.Character then
		task.spawn(function()
			task.wait(0.5)
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid and player.Character.Parent then
				InventoryManager.SyncBackpack(player, player.Character)
			end
		end)
	end
end


-- Track last known character for each player to detect respawns
local lastKnownCharacters = {}

-- Server-wide character monitor (optimized)
task.spawn(function()
	--print("[InventoryManager] 🌍 Starting server-wide character monitor")
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local currentChar = player.Character
			local lastChar = lastKnownCharacters[player.UserId]
			if currentChar and currentChar ~= lastChar and lastChar ~= nil then
				--print("[InventoryManager] ⚡ RESPAWN DETECTED for " .. player.Name)
				lastKnownCharacters[player.UserId] = currentChar
				task.spawn(function()
					--print("[InventoryManager] 📌 Character loaded for " .. player.Name)
					local ok, err = pcall(function()
						local humanoid = currentChar:FindFirstChild("Humanoid") or currentChar:WaitForChild("Humanoid", 3)
						if not humanoid then warn("[InventoryManager] Humanoid not found for " .. player.Name) return end
						--print("[InventoryManager] ✅ Humanoid ready for " .. player.Name)
						task.wait(0.3)
						--print("[InventoryManager] ✅ Using existing inventory for respawn (no reload) for " .. player.Name)
						local WeaponManager = require(script.Parent.WeaponManager)
						if WeaponManager.CleanupPlayerTools then WeaponManager.CleanupPlayerTools(player) end
						local syncOk, syncErr = pcall(function()
							InventoryManager.SyncBackpack(player, currentChar)
						end)
						if not syncOk then warn("[InventoryManager] SyncBackpack error for " .. player.Name .. ": " .. tostring(syncErr)) end
					end)
					if not ok then warn("[InventoryManager] Error in respawn handler for " .. player.Name .. ": " .. tostring(err)) end
				end)
			elseif currentChar and lastChar == nil then
				lastKnownCharacters[player.UserId] = currentChar
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	--print("[InventoryManager] ✓ PlayerAdded: " .. player.Name)
	
	-- Load and initialize inventory immediately
	InventoryManager.LoadInventory(player)
	task.wait(0.1)
	InventoryManager.GiveStartingItemsIfNew(player)
	if player.Character then
		lastKnownCharacters[player.UserId] = player.Character
		--print("[InventoryManager] 🔄 Handling initial character for " .. player.Name)
		task.spawn(function()
			local ok, err = pcall(function()
				local humanoid = player.Character:FindFirstChild("Humanoid") or player.Character:WaitForChild("Humanoid", 3)
				if not humanoid then warn("[InventoryManager] Humanoid not found for " .. player.Name) return end
				task.wait(0.3)
				local WeaponManager = require(script.Parent.WeaponManager)
				if WeaponManager.CleanupPlayerTools then WeaponManager.CleanupPlayerTools(player) end
				--print("[InventoryManager] 🎯 Syncing initial backpack for " .. player.Name)
				InventoryManager.SyncBackpack(player, player.Character)
				--print("[InventoryManager] ✅ Initial SyncBackpack complete for " .. player.Name)
			end)
			if not ok then warn("[InventoryManager] Error syncing initial character for " .. player.Name .. ": " .. tostring(err)) end
		end)
	else
		player.CharacterAdded:Connect(function(newCharacter)
			lastKnownCharacters[player.UserId] = newCharacter
			--print("[InventoryManager] 🔄 Character loaded for " .. player.Name .. " (via CharacterAdded)")
			task.spawn(function()
				local ok, err = pcall(function()
					local humanoid = newCharacter:FindFirstChild("Humanoid") or newCharacter:WaitForChild("Humanoid", 3)
					if not humanoid then warn("[InventoryManager] Humanoid not found for " .. player.Name) return end
					task.wait(0.3)
					local WeaponManager = require(script.Parent.WeaponManager)
					if WeaponManager.CleanupPlayerTools then WeaponManager.CleanupPlayerTools(player) end
					--print("[InventoryManager] 🎯 Syncing backpack for " .. player.Name)
					InventoryManager.SyncBackpack(player, newCharacter)
					--print("[InventoryManager] ✅ SyncBackpack complete for " .. player.Name)
				end)
				if not ok then warn("[InventoryManager] Error syncing character for " .. player.Name .. ": " .. tostring(err)) end
			end)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Force immediate inventory save before cleanup to prevent data loss
	InventoryManager.SaveInventory(player, false)
	local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
	-- [REMOVED] OrbSpiritHandler.RemoveOrbStatBonuses
	-- [REMOVED] OrbSpiritHandler.CleanupPlayerOrbData
	playerInventories[player.UserId] = nil
	inventoriesLoaded[player.UserId] = nil
	inventoriesLoading[player.UserId] = nil
	lastInventorySaveTime[player.UserId] = nil
	pendingInventoryChanges[player.UserId] = nil
	lastKnownCharacters[player.UserId] = nil
end)

-- Heartbeat loop to batch and save pending inventory changes
game:GetService("RunService").Heartbeat:Connect(function()
	local now = tick()
	for userId, hasPending in pairs(pendingInventoryChanges) do
		if hasPending then
			local player = Players:GetPlayerByUserId(userId)
			if player and lastInventorySaveTime[userId] and (now - lastInventorySaveTime[userId]) >= SAVE_THROTTLE_INTERVAL then
				InventoryManager.SaveInventory(player, false)
			end
		end
	end
end)

-- Setup RemoteFunction for inventory UI requests
local inventoryEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
if not inventoryEvent then
	inventoryEvent = Instance.new("RemoteFunction")
	inventoryEvent.Name = "GetPlayerInventory"
	inventoryEvent.Parent = ReplicatedStorage
end

-- Handle inventory requests from clients
inventoryEvent.OnServerInvoke = function(player)
	if not player then 
		--print("[InventoryManager] Null player request!")
		return {} 
	end
	
	--print("[InventoryManager] Player " .. player.Name .. " (ID: " .. player.UserId .. ") requesting inventory")
	
	-- Wait for inventory to be loaded if not already
	local userId = player.UserId
	local waitCount = 0
	while not inventoriesLoaded[userId] and waitCount < 1000 do
		waitCount = waitCount + 1
		task.wait(0.1)
	end
	
	if not inventoriesLoaded[userId] then
		warn("[InventoryManager] Inventory failed to load for " .. player.Name .. " after timeout!")
		return {}
	end
	
	-- Get player's inventory
	local inventory = InventoryManager.GetInventory(player)
	
	if not inventory or #inventory == 0 then
		--print("[InventoryManager] Player " .. player.Name .. " has empty inventory, returning default")
		return {}
	end
	
	--print("[InventoryManager] Returning inventory for " .. player.Name .. " with " .. #inventory .. " items")
	return inventory
end

-- Get inventory with equipped status for UI display
function InventoryManager.GetInventoryWithEquippedStatus(player)
	if not player then return {} end
	
	local inventory = InventoryManager.GetInventory(player)
	if not inventory or #inventory == 0 then return {} end
	
	-- Get equipped weapon and orb (use helpers, fallback to InventoryManager methods if needed)
	local equippedWeapon = nil
	if type(getEquippedWeapon) == "function" then
		equippedWeapon = getEquippedWeapon(player)
	elseif type(InventoryManager.GetEquippedWeapon) == "function" then
		equippedWeapon = InventoryManager.GetEquippedWeapon(player)
	end

	local equippedOrb = nil
	if type(getEquippedOrb) == "function" then
		equippedOrb = getEquippedOrb(player)
	elseif type(InventoryManager.GetEquippedOrb) == "function" then
		equippedOrb = InventoryManager.GetEquippedOrb(player)
	end
	
	-- Add equipped flag to each item
	local inventoryWithStatus = {}
	for _, item in ipairs(inventory) do
		local itemWithStatus = {
			name = item.name,
			id = item.id,
			itemType = item.itemType,
			equipped = false
		}
		
		-- Check if this item is equipped
		if item.itemType == "weapon" and equippedWeapon and equippedWeapon.id == item.id then
			itemWithStatus.equipped = true
		elseif item.itemType == "spirit orb" and equippedOrb and equippedOrb.id == item.id then
			itemWithStatus.equipped = true
		end
		
		table.insert(inventoryWithStatus, itemWithStatus)
	end
	
	return inventoryWithStatus
end

-- Handle inventory requests from clients (with equipped status)
local inventoryWithStatusEvent = ReplicatedStorage:FindFirstChild("GetPlayerInventoryWithStatus")
if not inventoryWithStatusEvent then
	inventoryWithStatusEvent = Instance.new("RemoteFunction")
	inventoryWithStatusEvent.Name = "GetPlayerInventoryWithStatus"
	inventoryWithStatusEvent.Parent = ReplicatedStorage
end

inventoryWithStatusEvent.OnServerInvoke = function(player)
	if not player then 
		--print("[InventoryManager] Null player request for inventory with status!")
		return {} 
	end
	
	--print("[InventoryManager] Player " .. player.Name .. " requesting inventory with equipped status")
	
	-- Wait for inventory to be loaded
	local userId = player.UserId
	local waitCount = 0
	while not inventoriesLoaded[userId] and waitCount < 50 do
		waitCount = waitCount + 1
		task.wait(0.1)
	end
	
	if not inventoriesLoaded[userId] then
		warn("[InventoryManager] Inventory failed to load for " .. player.Name)
		return {}
	end
	
	return InventoryManager.GetInventoryWithEquippedStatus(player)
end

-- Helper: Get equipped orb data from folder structure
local function getEquippedOrb(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	
	local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
	if not equippedOrbFolder or not equippedOrbFolder:IsA("Folder") then return nil end
	
	local nameValue = equippedOrbFolder:FindFirstChild("name")
	local idValue = equippedOrbFolder:FindFirstChild("id")
	
	if not nameValue or not idValue then return nil end
	
	return {
		name = nameValue.Value,
		id = idValue.Value
	}
end

-- -- Helper: Set equipped orb data in folder structure
function InventoryManager.setEquippedOrb(player, orbName, itemId)
	local userId = getUserId(player)
	if equipLocks[userId] then
		warn("[InventoryManager] Equip already in progress for " .. player.Name .. ", skipping.")
		return
	end
	equipLocks[userId] = true
	
	-- Robustly wait for dependencies (Stats, EquippedOrb folder)
	local stats, equippedOrbFolder
	local maxWait, waited = 2, 0
	while waited < maxWait do
		stats = player:FindFirstChild("Stats")
		if stats then
			equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
		end
		if stats and equippedOrbFolder and equippedOrbFolder:IsA("Folder") then
			break
		end
		task.wait(0.1)
		waited = waited + 0.1
	end
	
	local function clearLocks()
		equipLocks[userId] = nil
	end
	
	if not stats then
		--print("[InventoryManager] FAILED: No Stats found for " .. player.Name .. " after wait")
		clearLocks()
		return
	end
	if not equippedOrbFolder or not equippedOrbFolder:IsA("Folder") then
		--print("[InventoryManager] FAILED: No EquippedOrb folder for " .. player.Name .. " after wait")
		clearLocks()
		return
	end
	local nameValue = equippedOrbFolder:FindFirstChild("name")
	local idValue = equippedOrbFolder:FindFirstChild("id")
	if nameValue then nameValue.Value = orbName end
	if idValue then idValue.Value = itemId end
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveStats(player, false)
	--print("[InventoryManager] Orb EQUIPPED for " .. player.Name .. ": " .. orbName .. " (id: " .. tostring(itemId) .. ")")
	-- Fire EquippedOrbChanged event for client UI update
	local equippedOrbChangedEvent = ReplicatedStorage:FindFirstChild("EquippedOrbChanged")
	if not equippedOrbChangedEvent then
		equippedOrbChangedEvent = Instance.new("RemoteEvent")
		equippedOrbChangedEvent.Name = "EquippedOrbChanged"
		equippedOrbChangedEvent.Parent = ReplicatedStorage
	end
	equippedOrbChangedEvent:FireClient(player)
	-- Force server-side equip and log
	   local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
	   -- Wait for character and required parts to exist before equipping VFX/accessory
	   local maxWait, waited = 3, 0
	   while (not player.Character or not player.Character:FindFirstChild("Humanoid")) and waited < maxWait do
		   task.wait(0.1)
		   waited = waited + 0.1
	   end
	   -- Optionally wait for LeftHand and UpperTorso if needed for VFX
	   if player.Character then
		   local lh, ut = player.Character:FindFirstChild("LeftHand"), player.Character:FindFirstChild("UpperTorso")
		   local partWaited = 0
		   while (not lh or not ut) and partWaited < 2 do
			   task.wait(0.1)
			   lh = player.Character:FindFirstChild("LeftHand")
			   ut = player.Character:FindFirstChild("UpperTorso")
			   partWaited = partWaited + 0.1
		   end
	   end
	   local success = OrbSpiritHandler.EquipOrbFromInventory(player)
	   if success then
		   --print("[InventoryManager] OrbSpiritHandler.EquipOrbFromInventory succeeded for " .. player.Name)
	   else
		   --print("[InventoryManager] OrbSpiritHandler.EquipOrbFromInventory failed for " .. player.Name)
	   end
	clearLocks()
end

-- Get equipped orb for player
function InventoryManager.GetEquippedOrb(player)
	return getEquippedOrb(player)
end

return InventoryManager
