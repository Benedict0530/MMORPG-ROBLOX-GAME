local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

local InventoryManager = {}

-- Table to track inventories in memory
local playerInventories = {}
-- Table to track if we've already synced backpack for a player
local syncedPlayers = {}
-- Counter for unique item IDs
local itemIdCounter = 0

-- Table to track when inventory is loaded for each player
local inventoriesLoaded = {}

-- Default inventory (new format with IDs)
local DEFAULT_INVENTORY = {
	{ name = "Twig", id = "item_default_twig_1" }
}

-- Generate a unique item ID
local function generateUniqueItemId(itemName)
	itemIdCounter = itemIdCounter + 1
	return itemName .. "_" .. os.time() .. "_" .. itemIdCounter
end

-- Create a fresh default inventory with unique IDs for each new player
local function createDefaultInventory()
	return {
		{ name = "Twig", id = generateUniqueItemId("Twig") }
	}
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
local function setEquippedWeapon(player, weaponName, itemId)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	
	local equippedFolder = stats:FindFirstChild("Equipped")
	if not equippedFolder or not equippedFolder:IsA("Folder") then return end
	
	local nameValue = equippedFolder:FindFirstChild("name")
	local idValue = equippedFolder:FindFirstChild("id")
	
	if nameValue then nameValue.Value = weaponName end
	if idValue then idValue.Value = itemId end
end

-- Throttle settings for inventory saves
local SAVE_THROTTLE_INTERVAL = 8 -- Save inventory every 8 seconds max
local lastInventorySaveTime = {}
local pendingInventoryChanges = {}

-- Migrate inventory data to ensure proper format (convert old string array to new table with IDs)
local function migrateData(oldData)
	-- Ensure oldData is a table
	if not oldData or type(oldData) ~= "table" then
		return createDefaultInventory()
	end
	
	-- If empty, default to Twig
	if #oldData == 0 then
		return createDefaultInventory()
	end
	
	-- Check if already in new format (first element is a table with 'name' and 'id')
	if oldData[1] and type(oldData[1]) == "table" and oldData[1].name and oldData[1].id then
		return oldData
	end
	
	-- Convert from old format (array of strings) to new format (array of tables)
	local newData = {}
	for _, itemName in ipairs(oldData) do
		if type(itemName) == "string" then
			table.insert(newData, {
				name = itemName,
				id = generateUniqueItemId(itemName)
			})
		end
	end
	
	return #newData > 0 and newData or createDefaultInventory()
end

-- Save inventory to DataStore (throttled)
function InventoryManager.SaveInventory(player, forceImmediate)
	local userId = player.UserId
	local data = playerInventories[userId] or {}
	
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveInventory(userId, data, forceImmediate)
end

-- Add item to inventory with unique ID
function InventoryManager.AddItem(player, itemName)
	local userId = player.UserId
	playerInventories[userId] = playerInventories[userId] or {}
	
	-- Create new item entry with unique ID
	local newItem = {
		name = itemName,
		id = generateUniqueItemId(itemName)
	}
	table.insert(playerInventories[userId], newItem)
	
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
	
	-- Load from unified manager
	data = UnifiedDataStoreManager.LoadInventory(userId)
	if type(data) == "table" then
		playerInventories[userId] = migrateData(data)
	else
		playerInventories[userId] = createDefaultInventory()
	end
	
	-- Mark inventory as loaded
	inventoriesLoaded[userId] = true
	print("[InventoryManager] Inventory loaded and marked for player " .. player.Name)
end

-- Sync Backpack with inventory
function InventoryManager.SyncBackpack(player, character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[InventoryManager] Humanoid not found for " .. player.Name)
		return
	end
	
	-- Remove all weapon tools from player
	for _, tool in ipairs(player:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
	
	-- Add staggered delay to prevent all players syncing tools simultaneously
	local playerCount = #Players:GetPlayers()
	if playerCount > 1 then
		local delayFactor = (player.UserId % playerCount) * 0.2
		task.wait(delayFactor)
	end
	
	local WeaponManager = require(script.Parent.WeaponManager)
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[InventoryManager] Weapons folder not found in ReplicatedStorage for " .. player.Name)
		return
	end
	
	-- Get current inventory
	local inventory = playerInventories[player.UserId] or {}
	
	-- If inventory is empty, default to Twig
	if #inventory == 0 then
		inventory = createDefaultInventory()
	end
	
	local equippedWeaponName = nil
	local equippedItemId = nil
	local stats = player:FindFirstChild("Stats")
	
	-- Get equipped weapon using helper function
	local equipped = getEquippedWeapon(player)
	if equipped then
		equippedWeaponName = equipped.name
		equippedItemId = equipped.id
	end
	
	-- If no weapon is equipped, auto-equip the first one
	if not equippedWeaponName or equippedWeaponName == "" then
		if #inventory > 0 then
			equippedWeaponName = inventory[1].name
			equippedItemId = inventory[1].id
			-- Save to player stats using helper function
			setEquippedWeapon(player, equippedWeaponName, equippedItemId)
			print(string.format("[InventoryManager] Auto-equipped '%s' (ID: %s) for %s", equippedWeaponName, equippedItemId, player.Name))
		else
			equippedWeaponName = "Twig"
		end
	end
	
	-- ONLY give the equipped tool to the player, not all inventory items
	-- Inventory items are for storage/drops, equipped tool is what goes in backpack
	local equippedTool = nil
	if equippedWeaponName and equippedWeaponName ~= "" then
		-- Stagger tool creation per player to reduce server load
		task.wait((player.UserId % 10) * 0.2)
		-- Extract base weapon name (remove unique ID suffix if present, e.g., "Twig_5" -> "Twig")
		local baseWeaponName = equippedWeaponName:match("^([^_]+)") or equippedWeaponName
		local tool = weaponsFolder:FindFirstChild(baseWeaponName)
		if not tool then
			warn("[InventoryManager] Tool '" .. baseWeaponName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
		else
			-- Found matching weapon, clone it
			local clone = tool:Clone()
			clone.Parent = player
			
			-- Store the unique item ID in the tool for trading/identification purposes
			clone:SetAttribute("_ItemId", equippedItemId)
			clone:SetAttribute("_OwnerUserId", player.UserId)
			
			-- Wait longer for tool to fully replicate when multiple players join
			task.wait(1.0)
			
			-- Verify tool is in player's backpack/inventory
			if clone.Parent ~= player then
				warn("[InventoryManager] Tool '" .. baseWeaponName .. "' parent changed, retrying for " .. player.Name)
				-- Tool was moved/destroyed, try to find it in player's backpack
				clone = player:FindFirstChild(baseWeaponName)
				if not clone then
					warn("[InventoryManager] Could not recover tool '" .. baseWeaponName .. "' for " .. player.Name)
				end
			end
			
			-- Only proceed if we have a valid tool
			if clone and clone.Parent == player then
				equippedTool = clone
				print(string.format("[InventoryManager] Created equipped tool: %s (ID: %s)", baseWeaponName, equippedItemId))
			end
		end
	end
	
	-- Auto-equip the weapon
	if equippedTool then
		-- Wait longer for all tools to be fully replicated before equipping
		-- This is critical when multiple players join at the same time
		task.wait(0.1)
		
		-- Verify tool still exists before equipping
		if not equippedTool or equippedTool.Parent ~= player then
			warn("[InventoryManager] Equipped tool no longer in player backpack for " .. player.Name)
			return
		end
		
		-- Verify humanoid still exists
		if not humanoid or humanoid.Health <= 0 then
			warn("[InventoryManager] Humanoid invalid before equipping for " .. player.Name)
			return
		end
		
		-- Small staggered delay per player to prevent simultaneous equips
		task.wait((player.UserId % 5) * 0.1)
		
		local success, err = pcall(function()
			humanoid:EquipTool(equippedTool)
		end)
		if not success then
			warn("[InventoryManager] Failed to equip tool '" .. equippedTool.Name .. "' for " .. player.Name .. ": " .. tostring(err))
		else
			print("[InventoryManager] Successfully equipped tool '" .. equippedTool.Name .. "' for " .. player.Name)
		end
		
		-- NOW connect the tool AFTER it's been equipped to the character
		-- This ensures the tool is in the proper location before the event listener is set up
		task.wait(0.5)
		if equippedTool and equippedTool.Parent == character then
			local success2, err2 = pcall(function()
				WeaponManager.ConnectTool(equippedTool, player)
			end)
			if not success2 then
				warn("[InventoryManager] Failed to connect tool '" .. equippedTool.Name .. "' after equip for " .. player.Name .. ": " .. tostring(err2))
			else
				print("[InventoryManager] Successfully connected tool '" .. equippedTool.Name .. "' after equip for " .. player.Name)
			end
		else
			warn("[InventoryManager] Tool is not in character after equipping for " .. player.Name)
		end
	else
		warn("[InventoryManager] No equipped tool found for " .. player.Name)
	end
end


-- Give starting items to player (only if new)
function InventoryManager.GiveStartingItemsIfNew(player)
	local inventory = InventoryManager.GetInventory(player)
	if #inventory < 1 then
		-- New player detected, assign starting Twig with unique ID
		InventoryManager.AddItem(player, "Twig")
	end
end


Players.PlayerAdded:Connect(function(player)
	-- Use task.spawn to ensure this doesn't block other PlayerAdded handlers
	task.spawn(function()
		-- Wait for PlayerDataStore to initialize stats
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local playerSignalsFolder = ReplicatedStorage:WaitForChild("PlayerInitSignals", 10)
	if not playerSignalsFolder then
		warn("[InventoryManager] PlayerInitSignals folder not found for " .. player.Name)
		return
	end
	
	local signalName = "Player_" .. player.UserId
	-- Wait for stats ready signal
	local statsReadySignal = playerSignalsFolder:WaitForChild(signalName, 10)
	if not statsReadySignal then
		warn("[InventoryManager] Stats ready signal not found for " .. player.Name)
		return
	end
	
	-- Check if signal was already fired (check _Fired flag)
	local firedFlag = statsReadySignal:FindFirstChild("_Fired")
	if not firedFlag or not firedFlag.Value then
		-- Wait for stats ready signal to fire
		statsReadySignal.Event:Wait()
	end
	-- Stats are now ready
	
	InventoryManager.LoadInventory(player)
	InventoryManager.GiveStartingItemsIfNew(player)
	
	-- Handle both existing character and future characters
	if player.Character then
		-- Player has existing character, sync inventory
		task.spawn(function()
			task.wait(0.5) -- Wait for character to fully load
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid and player.Character.Parent then
				InventoryManager.SyncBackpack(player, player.Character)
			end
		end)
	end
	player.CharacterAdded:Connect(function(char)
		-- Character spawned, sync inventory
		task.spawn(function()
			-- Cleanup old tool connections first
			local WeaponManager = require(script.Parent.WeaponManager)
			WeaponManager.CleanupPlayerTools(player)
			
			local humanoid = char:WaitForChild("Humanoid", 5)
			if not humanoid then
				warn("[InventoryManager] Humanoid not found for " .. player.Name)
				return
			end
			task.wait(0.5) -- Wait for character replication before syncing
			InventoryManager.SyncBackpack(player, char)
		end)
	end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Force save inventory through unified manager
	UnifiedDataStoreManager.SaveInventory(player.UserId, playerInventories[player.UserId] or {}, true)
	
	-- Cleanup tracking
	playerInventories[player.UserId] = nil
	inventoriesLoaded[player.UserId] = nil
	lastInventorySaveTime[player.UserId] = nil
	pendingInventoryChanges[player.UserId] = nil
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
