print("[InventoryManager] Module loaded.")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

local InventoryManager = {}

-- Table to track inventories in memory
local playerInventories = {}
-- Table to track if we've already synced backpack for a player
local syncedPlayers = {}

-- Add item to inventory
function InventoryManager.AddItem(player, itemName)
	local userId = player.UserId
	playerInventories[userId] = playerInventories[userId] or {}
	if not table.find(playerInventories[userId], itemName) then
		table.insert(playerInventories[userId], itemName)
		print("[InventoryManager] Added item '" .. itemName .. "' to " .. player.Name .. "'s inventory.")
		InventoryManager.SaveInventory(player)
		return true
	else
		print("[InventoryManager] Item '" .. itemName .. "' already exists in " .. player.Name .. "'s inventory.")
	end
	return false
end

-- Remove item from inventory
function InventoryManager.RemoveItem(player, itemName)
	local userId = player.UserId
	playerInventories[userId] = playerInventories[userId] or {}
	for i, item in ipairs(playerInventories[userId]) do
		if item == itemName then
			table.remove(playerInventories[userId], i)
			InventoryManager.SaveInventory(player)
			return true
		end
	end
	return false
end

-- Get inventory table
function InventoryManager.GetInventory(player)
	return playerInventories[player.UserId] or {}
end

-- Save inventory to DataStore
function InventoryManager.SaveInventory(player)
	local userId = player.UserId
	local key = "Player_" .. userId
	local data = playerInventories[userId] or {}
	pcall(function()
		inventoryStore:SetAsync(key, data)
	end)
end

-- Load inventory from DataStore
function InventoryManager.LoadInventory(player)
	local userId = player.UserId
	local key = "Player_" .. userId
	local data
	local success, err = pcall(function()
		data = inventoryStore:GetAsync(key)
	end)
	if success and type(data) == "table" then
		playerInventories[userId] = data
	else
		playerInventories[userId] = {}
	end
end

-- Sync Backpack with inventory
function InventoryManager.SyncBackpack(player, character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[InventoryManager] Humanoid not found for " .. player.Name)
		return
	end
	
	print("[InventoryManager] Syncing items for " .. player.Name .. ".")
	-- Remove all weapon tools from player
	for _, tool in ipairs(player:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
	-- Add all inventory items as tools
	local WeaponManager = require(script.Parent.WeaponManager)
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if weaponsFolder then
		local availableWeapons = {}
		for _, weapon in ipairs(weaponsFolder:GetChildren()) do
			table.insert(availableWeapons, weapon.Name)
		end
		print("[InventoryManager] Available weapons in ReplicatedStorage.Weapons: " .. table.concat(availableWeapons, ", "))
		local equippedWeaponName = nil
		
		-- Get equipped weapon from player stats
		local stats = player:FindFirstChild("Stats")
		if stats then
			local equippedStat = stats:FindFirstChild("Equipped")
			if equippedStat then
				equippedWeaponName = equippedStat.Value
			end
		end
		
		equippedWeaponName = equippedWeaponName or "Twig" -- Default to Twig if not found
		
		-- Check if equipped weapon exists in inventory
		local equippedWeaponInInventory = false
		for _, itemName in ipairs(playerInventories[player.UserId] or {}) do
			if itemName == equippedWeaponName then
				equippedWeaponInInventory = true
				break
			end
		end
		
		-- If equipped weapon not in inventory, set to first available or Twig
		if not equippedWeaponInInventory then
			equippedWeaponName = playerInventories[player.UserId] and playerInventories[player.UserId][1] or "Twig"
			print("[InventoryManager] Equipped weapon '" .. equippedWeaponName .. "' not in inventory. Defaulting to '" .. equippedWeaponName .. "'")
		end
		
		local equippedTool = nil
		for _, itemName in ipairs(playerInventories[player.UserId] or {}) do
			print("[InventoryManager] Checking inventory item: '" .. itemName .. "' for " .. player.Name)
			local tool = weaponsFolder:FindFirstChild(itemName)
			if tool then
				print("[InventoryManager] Found matching weapon: '" .. itemName .. "' for " .. player.Name)
				local clone = tool:Clone()
				clone.Parent = player
				print("[InventoryManager] Gave tool '" .. itemName .. "' to " .. player.Name .. ".")
				
				-- Connect tool with error handling
				local success, err = pcall(function()
					WeaponManager.ConnectTool(clone)
				end)
				if not success then
					warn("[InventoryManager] Failed to connect tool '" .. itemName .. "': " .. tostring(err))
				else
					print("[InventoryManager] Successfully connected tool '" .. itemName .. "'")
				end
				
				-- Mark this as the equipped tool if it matches
				if itemName == equippedWeaponName then
					equippedTool = clone
				end
			else
				warn("[InventoryManager] Tool '" .. itemName .. "' not found in ReplicatedStorage.Weapons for " .. player.Name)
			end
		end
		
		-- Auto-equip the weapon only if it was found in inventory
		if equippedTool then
			task.wait(0.1) -- Small delay to ensure tool is fully setup
			local success, err = pcall(function()
				humanoid:EquipTool(equippedTool)
			end)
			if success then
				print("[InventoryManager] Auto-equipped tool '" .. equippedTool.Name .. "' for " .. player.Name)
			else
				warn("[InventoryManager] Failed to equip tool '" .. equippedTool.Name .. "': " .. tostring(err))
			end
		end
	else
		warn("[InventoryManager] Weapons folder not found in ReplicatedStorage for " .. player.Name)
	end
end


-- Give starting items to player (only if new)
function InventoryManager.GiveStartingItemsIfNew(player)
	local inventory = InventoryManager.GetInventory(player)
	if #inventory < 1 then
		print("[InventoryManager] New player detected: " .. player.Name .. ". Giving Twig.")
		InventoryManager.AddItem(player, "Twig")
	else
		print("[InventoryManager] Existing player: " .. player.Name .. ". Inventory: " .. table.concat(inventory, ", "))
	end
end


Players.PlayerAdded:Connect(function(player)
	print("[InventoryManager] PlayerAdded: " .. player.Name .. " (" .. player.UserId .. ")")
	InventoryManager.LoadInventory(player)
	print("[InventoryManager] After LoadInventory: " .. player.Name .. " inventory: " .. table.concat(InventoryManager.GetInventory(player), ", "))
	InventoryManager.GiveStartingItemsIfNew(player)
	print("[InventoryManager] After GiveStartingItemsIfNew: " .. player.Name .. " inventory: " .. table.concat(InventoryManager.GetInventory(player), ", "))
	player.CharacterAdded:Connect(function(char)
		print("[InventoryManager] CharacterAdded for " .. player.Name)
		local humanoid = char:WaitForChild("Humanoid", 5)
		if not humanoid then
			warn("[InventoryManager] Humanoid not found for " .. player.Name)
			return
		end
		print("[InventoryManager] Syncing inventory for " .. player.Name)
		InventoryManager.SyncBackpack(player, char)
	end)
end)

-- Optionally save inventory on player removing
Players.PlayerRemoving:Connect(function(player)
	InventoryManager.SaveInventory(player)
	playerInventories[player.UserId] = nil
end)
