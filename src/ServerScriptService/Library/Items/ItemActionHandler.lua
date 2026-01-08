-- ItemActionHandler.lua
-- Handles server-side logic for equipping and dropping items

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryManager = require(script.Parent.InventoryManager)
local ItemActionHandler = {}

-- Debounce tables to prevent duplicate actions for the same player+itemId
local equipDebounce = {}
local dropDebounce = {}

-- Global per-player action lock to prevent concurrent actions
local playerActionLock = {}

-- Listen for client requests to equip/drop items
local itemActionEvent = ReplicatedStorage:FindFirstChild("ItemActionEvent")
if not itemActionEvent then
	itemActionEvent = Instance.new("RemoteEvent")
	itemActionEvent.Name = "ItemActionEvent"
	itemActionEvent.Parent = ReplicatedStorage
end
local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")



function ItemActionHandler:EquipItem(player, itemId)
	-- Block if another action is ongoing for this player
	if playerActionLock[player] then
		warn("[ItemActionHandler] Action already in progress for", player.Name, "- blocking EquipItem")
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end
	playerActionLock[player] = true
	equipDebounce[player] = equipDebounce[player] or {}
	if equipDebounce[player][itemId] then
		-- Already processing this itemId for this player, ignore duplicate
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end
	equipDebounce[player][itemId] = true
	print("[ItemActionHandler] EquipItem called for", player.Name, itemId)

	-- Validate itemId exists in player's inventory
	local item = InventoryManager.GetItemById(player, itemId)
	if not item then
		warn("[ItemActionHandler] EquipItem: Item not found in inventory for", player.Name, itemId)
		equipDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	-- Check level requirement before equipping
	local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
	local weaponStats = WeaponData.GetWeaponStats(item.name)
	local requiredLevel = weaponStats and weaponStats.levelRequirement or 1
	local playerLevel = 1
	local statsFolder = player:FindFirstChild("Stats")
	if statsFolder then
		local levelValue = statsFolder:FindFirstChild("Level")
		if levelValue and tonumber(levelValue.Value) then
			playerLevel = tonumber(levelValue.Value)
		end
	end
	if playerLevel < requiredLevel then
		warn("[ItemActionHandler] Player ", player.Name, " does not meet level requirement for ", item.name, ": required=", requiredLevel, ", player=", playerLevel)
		equipDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	-- Update player's equipped slot in stats
	InventoryManager.setEquippedWeapon(player, item.name, item.id)

	print("[ItemActionHandler] Equipped", item.name, "(id:", item.id, ") for", player.Name)
	-- Ensure tool is connected by syncing backpack
	if player.Character then
		InventoryManager.SyncBackpack(player, player.Character)
	end
	-- Fire InventoryChanged event to refresh UI
	if inventoryChangedEvent then
		inventoryChangedEvent:FireClient(player)
	end
	-- Clear debounce after short delay (allowing for re-equip after a moment)
	task.delay(0.5, function()
		if equipDebounce[player] then
			equipDebounce[player][itemId] = nil
		end
		playerActionLock[player] = nil
	end)
end


function ItemActionHandler:DropItem(player, itemId)
	-- Block if another action is ongoing for this player
	if playerActionLock[player] then
		warn("[ItemActionHandler] Action already in progress for", player.Name, "- blocking DropItem")
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end
	playerActionLock[player] = true
	-- Prevent dropping if the item is currently equipped (check DataStore directly)
	local DataStoreService = game:GetService("DataStoreService")
	local statsStore = DataStoreService:GetDataStore("PlayerStats")
	local equippedIdValue = nil
	local success, data = pcall(function()
		return statsStore:GetAsync("Player_" .. tostring(player.UserId))
	end)
	if success and data and data.Equipped and type(data.Equipped) == "table" then
		equippedIdValue = data.Equipped.id
	end
	print("[ItemActionHandler] Drop attempt: itemId=", tostring(itemId), ", equippedId=", tostring(equippedIdValue))
	if equippedIdValue and tostring(equippedIdValue) == tostring(itemId) then
		warn("[ItemActionHandler] Cannot drop currently equipped item for", player.Name, itemId, "(checked DataStore)")
		dropDebounce[player] = dropDebounce[player] or {}
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	dropDebounce[player] = dropDebounce[player] or {}
	if dropDebounce[player][itemId] then
		-- Already processing this itemId for this player, ignore duplicate
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end
	dropDebounce[player][itemId] = true
	print("[ItemActionHandler] DropItem called for", player.Name, itemId)

	-- Remove item from inventory and save
	local item = InventoryManager.GetItemById(player, itemId)
	if not item then
		warn("[ItemActionHandler] DropItem: Item not found in inventory for", player.Name, itemId)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	local removed = InventoryManager.RemoveItem(player, itemId)
	if not removed then
		warn("[ItemActionHandler] DropItem: Failed to remove item from inventory for", player.Name, itemId)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	-- Spawn the dropped tool at player's root part for others to pick up
	local character = player.Character
	if not character then
		warn("[ItemActionHandler] DropItem: Player has no character", player.Name)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end
	local leftFoot = character:FindFirstChild("LeftFoot")
	if not leftFoot then
		warn("[ItemActionHandler] DropItem: No LeftFoot for", player.Name)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		if inventoryChangedEvent then
			inventoryChangedEvent:FireClient(player)
		end
		return
	end

	-- Use ItemDropManager to spawn the drop model from ServerStorage, not the tool
	local ItemDropManager = require(script.Parent.ItemDropManager)
	local dropPosition = leftFoot.Position + Vector3.new(0, 0, 0)
	local spawnedDrop = ItemDropManager.SpawnItemDrop(item.name, dropPosition, player)
	if spawnedDrop then
		print("[ItemActionHandler] Dropped", item.name, "(id:", item.id, ") at", tostring(dropPosition))
	else
		warn("[ItemActionHandler] Failed to spawn drop for", item.name, "at", tostring(dropPosition))
	end
	-- Fire InventoryChanged event to refresh UI
	if inventoryChangedEvent then
		inventoryChangedEvent:FireClient(player)
	end
	-- Clear debounce after short delay (allowing for re-drop after a moment)
	task.delay(0.5, function()
		if dropDebounce[player] then
			dropDebounce[player][itemId] = nil
		end
		playerActionLock[player] = nil
	end)
end

itemActionEvent.OnServerEvent:Connect(function(player, action, itemId)
	if action == "Equip" then
		ItemActionHandler:EquipItem(player, itemId)
	elseif action == "Drop" then
		ItemActionHandler:DropItem(player, itemId)
	else
		warn("[ItemActionHandler] Unknown action from client:", action)
	end
end)

return ItemActionHandler
