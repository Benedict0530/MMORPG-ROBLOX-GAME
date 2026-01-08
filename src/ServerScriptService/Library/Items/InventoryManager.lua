local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

local InventoryManager = {}

-- Per-player equip lock to prevent overlapping equip/sync
local equipLocks = {}
local connectInProgress = {}

-- Table to track inventories in memory
local playerInventories = {}
-- Table to track if we've already synced backpack for a player
local syncedPlayers = {}
-- Counter for unique item IDs
local itemIdCounter = 0

-- Table to track when inventory is loaded for each player
local inventoriesLoaded = {}

-- Default inventory (new format with IDs and itemType)
local DEFAULT_INVENTORY = {
	{ name = "Twig", id = "item_default_twig_1", itemType = "weapon" }
}

-- Helper: Get a safe userId from player or fallback
local function getUserId(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.UserId
	end
	return tostring(player)
end


local function generateUniqueItemId(itemName, player)
	-- Use os.time, math.random, and player.UserId for uniqueness
	local userId = player and getUserId(player) or "0"
	return itemName .. "_" .. tostring(userId) .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))
end


-- Create a fresh default inventory and equipped info for a new player
function InventoryManager.CreateStarterWeaponAndEquipped()
	local id = generateUniqueItemId("Twig")
	local item = { name = "Twig", id = id, itemType = "weapon" }
	return { item }, { name = "Twig", id = id }
end

-- For compatibility, keep createDefaultInventory for migration/legacy
local function createDefaultInventory()
	local inventory, _ = InventoryManager.CreateStarterWeaponAndEquipped()
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
		   print("[InventoryManager] FAILED: No Stats found for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end
	   if not equippedFolder or not equippedFolder:IsA("Folder") then
		   print("[InventoryManager] FAILED: No Equipped folder for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end
	   if not weaponsFolder then
		   print("[InventoryManager] FAILED: Weapons folder not found in ReplicatedStorage for " .. player.Name .. " after wait")
		   clearLocks()
		   return
	   end

	local nameValue = equippedFolder:FindFirstChild("name")
	local idValue = equippedFolder:FindFirstChild("id")

	if nameValue then nameValue.Value = weaponName end
	if idValue then idValue.Value = itemId end

	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveStats(player, true)

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
		print("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
		clearLocks()
		return
	end
	local clone = tool:Clone()
	clone.Parent = player
	clone:SetAttribute("_ItemId", itemId)
	clone:SetAttribute("_OwnerUserId", player.UserId)
	print("[InventoryManager] Weapon CREATED for " .. player.Name .. ": " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")

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
					print("[InventoryManager] FAILED: Could not equip tool '" .. clone.Name .. "' for " .. player.Name .. " (try " .. try .. "): " .. tostring(err))
				else
					print("[InventoryManager] Weapon EQUIPPED for " .. player.Name .. ": " .. clone.Name .. " (try " .. try .. ")")
				end
				task.wait(0.15)
				if clone.Parent == character then
					equipped = true
					break
				end
			end
			if not equipped then
				print("[InventoryManager] FAILED: Tool '" .. clone.Name .. "' could not be equipped after retries for " .. player.Name)
			else
				local ok, err2 = pcall(function()
					WeaponManager.ConnectTool(clone, player)
				end)
				if ok then
					print("[InventoryManager] CONNECTED: " .. player.Name .. " - " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")
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
							print("[InventoryManager] RE-CONNECTED (" .. i .. "): " .. player.Name .. " - " .. clone.Name .. " (id: " .. tostring(itemId) .. ")")
						else
							print("[InventoryManager] FAILED: re-connect (" .. i .. ") '" .. clone.Name .. "' for " .. player.Name .. ": " .. tostring(err3))
						end
					end
				else
					print("[InventoryManager] FAILED: connect '" .. clone.Name .. "' after equip for " .. player.Name .. ": " .. tostring(err2))
				end
			end
		else
			print("[InventoryManager] FAILED: No Humanoid found for " .. player.Name)
		end
	else
		print("[InventoryManager] FAILED: No Character found for " .. player.Name)
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
		print("[InventoryManager] ✅ Inventory already in correct format with " .. #oldData .. " items")
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
	
	print("[InventoryManager] ✅ Migrated inventory from old format: " .. #newData .. " items")
	return #newData > 0 and newData or createDefaultInventory()
end

-- Save inventory to DataStore (throttled)
function InventoryManager.SaveInventory(player, forceImmediate)
	local userId = player.UserId
	local data = playerInventories[userId] or {}
	
	-- SAFEGUARD: Validate inventory before saving
	-- Never save empty inventory unless player is completely new (0 items intentional)
	if not data or #data == 0 then
		-- If player already had items loaded, don't save empty data
		if inventoriesLoaded[userId] and inventoriesLoaded[userId] == true then
			warn("[InventoryManager] ⚠️ Prevented save of EMPTY inventory for " .. player.Name .. " - data loss protection!")
			return false  -- Don't save empty data over good data
		end
	end
	
	print("[InventoryManager] Saving inventory for " .. player.Name .. ": " .. #data .. " items (forceImmediate=" .. tostring(forceImmediate) .. ")")
	for i, item in ipairs(data) do
		print("[InventoryManager]   Item " .. i .. ": " .. item.name)
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
	
	-- Default itemType to "weapon" if not provided, or try to get from WeaponData
	if not itemType then
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		local weaponStats = WeaponData.GetWeaponStats(itemName)
		itemType = weaponStats and weaponStats.itemType or "weapon"
	end
	
	-- Create new item entry with unique ID and itemType
	local newItem = {
		name = itemName,
		id = generateUniqueItemId(itemName, player),
		itemType = itemType
	}
	table.insert(playerInventories[userId], newItem)
	
	print("[InventoryManager] Added item to " .. player.Name .. ": name=" .. newItem.name .. ", id=" .. newItem.id .. ", itemType=" .. newItem.itemType)
	print("[InventoryManager] Inventory now has " .. #playerInventories[userId] .. " items")
	
	-- Update capacity stat to reflect current inventory count
	if stats then
		local capacityValue = stats:FindFirstChild("InventoryCapacity")
		if capacityValue then
			capacityValue.Value = #playerInventories[userId]
		end
	end
	
	-- Item added to inventory, trigger save
	InventoryManager.SaveInventory(player, false) -- Throttled save
	
	-- Notify client that inventory has changed
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
			
			-- Item removed from inventory, trigger save
			InventoryManager.SaveInventory(player, false) -- Throttled save
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
	
	print("[InventoryManager] Loading inventory for " .. player.Name .. " (UserId: " .. userId .. ")")
	
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
	
	print("[InventoryManager] Loaded data from DataStore: " .. tostring(data) .. " (retries: " .. retries .. ")")
	
	if type(data) == "table" then
		playerInventories[userId] = migrateData(data)
		print("[InventoryManager] ✅ Successfully loaded inventory with " .. #playerInventories[userId] .. " items")
	elseif data == nil then
		-- DataStore load failed - create default but mark as needing save
		playerInventories[userId] = createDefaultInventory()
		warn("[InventoryManager] ⚠️ DataStore load failed for " .. player.Name .. " - using default inventory")
	else
		playerInventories[userId] = createDefaultInventory()
		print("[InventoryManager] Created default inventory (loaded data was not a table)")
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
end

-- Sync Backpack with inventory
function InventoryManager.SyncBackpack(player, character)
	local WeaponManager = require(script.Parent.WeaponManager)
	if equipLocks[player] then
		print("[InventoryManager] SyncBackpack already in progress for " .. player.Name .. ", skipping.")
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
		print("[InventoryManager] FAILED: Humanoid not found for " .. player.Name .. " after wait")
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
		print("[InventoryManager] FAILED: Weapons folder not found in ReplicatedStorage for " .. player.Name .. " after wait")
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
		equippedWeaponName = equipped.name
		equippedItemId = equipped.id
	end
	if (not equippedWeaponName or equippedWeaponName == "") and #inventory > 0 then
		equippedWeaponName = inventory[1].name
		equippedItemId = inventory[1].id
		local found = false
		for _, item in ipairs(inventory) do
			if item.id == equippedItemId then
				found = true
				break
			end
		end
		if not found then
			InventoryManager.setEquippedWeapon(player, equippedWeaponName, equippedItemId)
		end
	end
	local equippedTool = nil
	if equippedWeaponName and equippedWeaponName ~= "" then
		local baseWeaponName = equippedWeaponName:match("^([^_]+)") or equippedWeaponName
		local tool = weaponsFolder:FindFirstChild(baseWeaponName)
		if not tool then
			print("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
		else
			local clone = tool:Clone()
			clone.Parent = player
			clone:SetAttribute("_ItemId", equippedItemId)
			clone:SetAttribute("_OwnerUserId", player.UserId)
			print("[InventoryManager] Weapon CREATED for " .. player.Name .. ": " .. clone.Name .. " (id: " .. tostring(equippedItemId) .. ")")
			task.wait(0.15)
			if clone.Parent ~= player then
				print("[InventoryManager] FAILED: Tool '" .. baseWeaponName .. "' parent changed, retrying for " .. player.Name)
				clone = player:FindFirstChild(baseWeaponName)
				if not clone then
					print("[InventoryManager] FAILED: Could not recover tool '" .. baseWeaponName .. "' for " .. player.Name)
				end
			end
			if clone and clone.Parent == player then
				equippedTool = clone
			end
		end
	end
	if equippedTool then
		task.wait(0.15)
		if not equippedTool or equippedTool.Parent ~= player then
			print("[InventoryManager] FAILED: Equipped tool no longer in player backpack for " .. player.Name)
			equipLocks[player] = nil
			return
		end
		if not humanoid or not character.Parent or humanoid.Health <= 0 then
			print("[InventoryManager] FAILED: Humanoid invalid or character dead before equipping for " .. player.Name)
			equipLocks[player] = nil
			return
		end
		local success, err = pcall(function()
			humanoid:EquipTool(equippedTool)
		end)
		if not success then
			print("[InventoryManager] FAILED: Could not equip tool '" .. equippedTool.Name .. "' for " .. player.Name .. ": " .. tostring(err))
		else
			print("[InventoryManager] Weapon EQUIPPED for " .. player.Name .. ": " .. equippedTool.Name)
			-- Mark player as fully loaded after successful weapon equip
			local DamageManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("DamageManager"))
			DamageManager.MarkPlayerLoaded(player)
		end
		task.wait(0.15)
		if equippedTool and equippedTool.Parent ~= character then
			local retrySuccess = pcall(function()
				humanoid:EquipTool(equippedTool)
			end)
			if retrySuccess then
				task.wait(0.1)
			end
		end
		if equippedTool and equippedTool.Parent == character then
			local success2, err2 = pcall(function()
				WeaponManager.ConnectTool(equippedTool, player)
			end)
			if success2 then
				print("[InventoryManager] CONNECTED: " .. player.Name .. " - " .. equippedTool.Name .. " (id: " .. tostring(equippedItemId) .. ")")
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
						-- print("[InventoryManager] RE-CONNECTED (" .. i .. "): " .. player.Name .. " - " .. equippedTool.Name .. " (id: " .. tostring(equippedItemId) .. ")")
					else
						print("[InventoryManager] FAILED: re-connect (" .. i .. ") '" .. equippedTool.Name .. "' for " .. player.Name .. ": " .. tostring(err3))
					end
				end
			else
				print("[InventoryManager] FAILED: connect '" .. equippedTool.Name .. "' after equip for " .. player.Name .. ": " .. tostring(err2))
			end
		else
			print("[InventoryManager] FAILED: Tool is not in character after equipping for " .. player.Name)
		end
	else
		print("[InventoryManager] FAILED: No equipped tool found for " .. player.Name)
	end
	equipLocks[player] = nil
	connectInProgress[player] = nil
end


-- Give starting items to player (only if new)
function InventoryManager.GiveStartingItemsIfNew(player)
	local inventory = InventoryManager.GetInventory(player)
	local stats = player:FindFirstChild("Stats")
	local equippedOk = false
	if stats then
		local equippedFolder = stats:FindFirstChild("Equipped")
		if equippedFolder and equippedFolder:IsA("Folder") then
			local idValue = equippedFolder:FindFirstChild("id")
			if idValue and idValue.Value ~= "" then
				equippedOk = true
			end
		end
	end
	if #inventory < 1 or not equippedOk then
		-- Only create starter inventory/equipped if missing (should only happen for legacy data)
		local starterInventory, equipped = InventoryManager.CreateStarterWeaponAndEquipped()
		local userId = player.UserId
		playerInventories[userId] = starterInventory
		if equipped and equipped.name and equipped.id then
			InventoryManager.setEquippedWeapon(player, equipped.name, equipped.id)
		end
		InventoryManager.SaveInventory(player, true)
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		UnifiedDataStoreManager.SaveStats(player, true)
	else
		print("[InventoryManager] Player already has items and equipped, skipping starting item")
	end
end

-- Initialize player inventory (called from Init.server.lua for existing players)
function InventoryManager.InitializePlayer(player)
	print("[InventoryManager] InitializePlayer called for " .. player.Name)
	
	-- Load inventory
	InventoryManager.LoadInventory(player)
	
	-- Give starting items if new
	InventoryManager.GiveStartingItemsIfNew(player)
	
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

-- Server-wide character monitor
task.spawn(function()
	print("[InventoryManager] 🌍 Starting server-wide character monitor")
	while true do
		task.wait(0.5)
		
		for _, player in ipairs(Players:GetPlayers()) do
			local currentChar = player.Character
			local lastChar = lastKnownCharacters[player.UserId]
			
			-- Detect respawn: character exists, is different from last known, and last was not nil
			if currentChar and currentChar ~= lastChar and lastChar ~= nil then
				print("[InventoryManager] ⚡⚡⚡ RESPAWN DETECTED for " .. player.Name)
				lastKnownCharacters[player.UserId] = currentChar
				
				-- Trigger respawn sync
				task.spawn(function()
					print("[InventoryManager] 📌 Character loaded for " .. player.Name)
					
					local success, err = pcall(function()
						-- Wait for humanoid to exist
						local humanoid = currentChar:WaitForChild("Humanoid", 5)
						if not humanoid then
							warn("[InventoryManager] Humanoid not found for " .. player.Name .. " on respawn")
							return
						end
						
						print("[InventoryManager] ✅ Humanoid ready for " .. player.Name)
						
						-- Small delay to ensure character is fully loaded
						task.wait(0.3)
						
					-- FIXED: Don't reload from DataStore on respawn - keeps in-memory inventory intact
					-- This prevents losing recently acquired items that haven't been saved yet
					-- Inventory is already loaded on PlayerAdded and only updated when items are collected
					print("[InventoryManager] ✅ Using existing inventory for respawn (no reload) for " .. player.Name)
					
					-- Cleanup old connections
					local WeaponManager = require(script.Parent.WeaponManager)
					if WeaponManager.CleanupPlayerTools then
						print("[InventoryManager] 🧹 Calling CleanupPlayerTools for " .. player.Name)
						WeaponManager.CleanupPlayerTools(player)
						print("[InventoryManager] 🧹 CleanupPlayerTools complete for " .. player.Name)
					else
						print("[InventoryManager] ⚠️ CleanupPlayerTools not found in WeaponManager")
					end

						-- Sync backpack
						print("[InventoryManager] 🎯 Syncing backpack for " .. player.Name)
						InventoryManager.SyncBackpack(player, currentChar)
						print("[InventoryManager] ✅ SyncBackpack complete for " .. player.Name)
					end)
					
					if not success then
						warn("[InventoryManager] ❌ Error in respawn handler for " .. player.Name .. ": " .. tostring(err))
					end
				end)
			elseif currentChar and lastChar == nil then
				-- First time tracking this character (initial spawn)
				lastKnownCharacters[player.UserId] = currentChar
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	print("[InventoryManager] ✓ PlayerAdded: " .. player.Name)
	
	-- Load and initialize inventory immediately
	InventoryManager.LoadInventory(player)
	-- IMPORTANT: Wait for LoadInventory to complete before GiveStartingItemsIfNew
	task.wait(0.1)
	InventoryManager.GiveStartingItemsIfNew(player)
	
	-- Handle initial character if it exists
	if player.Character then
		lastKnownCharacters[player.UserId] = player.Character
		print("[InventoryManager] 🔄 Handling initial character for " .. player.Name)
		
		task.spawn(function()
			local success, err = pcall(function()
				-- Wait for humanoid
				local humanoid = player.Character:WaitForChild("Humanoid", 5)
				if not humanoid then
					warn("[InventoryManager] Humanoid not found for " .. player.Name)
					return
				end
				
				task.wait(0.3)
				
				-- Cleanup old connections
				local WeaponManager = require(script.Parent.WeaponManager)
				if WeaponManager.CleanupPlayerTools then
					WeaponManager.CleanupPlayerTools(player)
				end
				
				-- Sync backpack
				print("[InventoryManager] 🎯 Syncing initial backpack for " .. player.Name)
				InventoryManager.SyncBackpack(player, player.Character)
				print("[InventoryManager] ✅ Initial SyncBackpack complete for " .. player.Name)
			end)
			
			if not success then
				warn("[InventoryManager] ❌ Error syncing initial character for " .. player.Name .. ": " .. tostring(err))
			end
		end)
	else
		-- Character doesn't exist yet, wait for it
		player.CharacterAdded:Connect(function(newCharacter)
			lastKnownCharacters[player.UserId] = newCharacter
			print("[InventoryManager] 🔄 Character loaded for " .. player.Name .. " (via CharacterAdded)")
			
			task.spawn(function()
				local success, err = pcall(function()
					-- Wait for humanoid
					local humanoid = newCharacter:WaitForChild("Humanoid", 5)
					if not humanoid then
						warn("[InventoryManager] Humanoid not found for " .. player.Name)
						return
					end
					
					task.wait(0.3)
					
					-- Cleanup old connections
					local WeaponManager = require(script.Parent.WeaponManager)
					if WeaponManager.CleanupPlayerTools then
						WeaponManager.CleanupPlayerTools(player)
					end
					
					-- Sync backpack
					print("[InventoryManager] 🎯 Syncing backpack for " .. player.Name)
					InventoryManager.SyncBackpack(player, newCharacter)
					print("[InventoryManager] ✅ SyncBackpack complete for " .. player.Name)
				end)
				
				if not success then
					warn("[InventoryManager] ❌ Error syncing character for " .. player.Name .. ": " .. tostring(err))
				end
			end)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Force save inventory through unified manager
	UnifiedDataStoreManager.SaveInventory(player.UserId, playerInventories[player.UserId] or {}, true)
	
	-- Cleanup tracking
	playerInventories[player.UserId] = nil
	inventoriesLoaded[player.UserId] = nil
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
		print("[InventoryManager] Null player request!")
		return {} 
	end
	
	print("[InventoryManager] Player " .. player.Name .. " (ID: " .. player.UserId .. ") requesting inventory")
	
	-- Wait for inventory to be loaded if not already
	local userId = player.UserId
	local waitCount = 0
	while not inventoriesLoaded[userId] and waitCount < 50 do
		waitCount = waitCount + 1
		task.wait(0.1)
		print("[InventoryManager] Waiting for inventory to load... attempt " .. waitCount)
	end
	
	if not inventoriesLoaded[userId] then
		warn("[InventoryManager] Inventory failed to load for " .. player.Name .. " after timeout!")
		return {}
	end
	
	-- Get player's inventory
	local inventory = InventoryManager.GetInventory(player)
	
	if not inventory or #inventory == 0 then
		print("[InventoryManager] Player " .. player.Name .. " has empty inventory, returning default")
		return {}
	end
	
	print("[InventoryManager] Returning inventory for " .. player.Name .. " with " .. #inventory .. " items")
	return inventory
end

return InventoryManager
