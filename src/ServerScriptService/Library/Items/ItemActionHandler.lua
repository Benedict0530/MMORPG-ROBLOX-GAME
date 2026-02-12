-- ItemActionHandler.lua
-- Handles server-side logic for equipping and dropping items

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local InventoryManager = require(script.Parent.InventoryManager)
local ItemActionHandler = {}

-- Debounce tables to prevent duplicate actions for the same player+itemId
local equipDebounce = {}
local dropDebounce = {}

-- Global per-player action lock to prevent concurrent actions
local playerActionLock = {}

-- Per-player cooldown to prevent rapid successive actions
local playerActionCooldown = {}
local ACTION_COOLDOWN = 0.05 -- 50ms cooldown between actions

-- Listen for client requests to equip/drop items
local itemActionEvent = ReplicatedStorage:FindFirstChild("ItemActionEvent")
if not itemActionEvent then
	itemActionEvent = Instance.new("RemoteEvent")
	itemActionEvent.Name = "ItemActionEvent"
	itemActionEvent.Parent = ReplicatedStorage
end

-- Create feedback event for client-side notifications
local itemFeedbackEvent = ReplicatedStorage:FindFirstChild("ItemFeedbackEvent")
if not itemFeedbackEvent then
	itemFeedbackEvent = Instance.new("RemoteEvent")
	itemFeedbackEvent.Name = "ItemFeedbackEvent"
	itemFeedbackEvent.Parent = ReplicatedStorage
end



function ItemActionHandler:EquipItem(player, itemId)
	-- Check global cooldown to prevent spam
	if playerActionCooldown[player] and tick() - playerActionCooldown[player] < ACTION_COOLDOWN then
		return
	end
	playerActionCooldown[player] = tick()
	-- Block if another action is ongoing for this player
	if playerActionLock[player] then
		warn("[ItemActionHandler] Action already in progress for", player.Name, "- blocking EquipItem")
		playerActionLock[player] = nil -- Always clear lock to prevent stuck state
		return
	end
	playerActionLock[player] = true
	equipDebounce[player] = equipDebounce[player] or {}
	if equipDebounce[player][itemId] then
		-- Already processing this itemId for this player, ignore duplicate
		equipDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end
	equipDebounce[player][itemId] = true
	--print("[ItemActionHandler] EquipItem called for", player.Name, itemId)

	-- Validate itemId exists in player's inventory
	local item = InventoryManager.GetItemById(player, itemId)
	if not item then
		warn("[ItemActionHandler] EquipItem: Item not found in inventory for", player.Name, itemId)
		equipDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end

	-- Check if this is a weapon and if there's already a weapon equipped
	if item.itemType == "weapon" or item.itemType == nil then
		local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
		local weaponStats = WeaponData.GetWeaponStats(item.name)
		
		-- Check if there's already a weapon equipped
		local stats = player:FindFirstChild("Stats")
		if stats then
			local equippedFolder = stats:FindFirstChild("Equipped")
			if equippedFolder and equippedFolder:IsA("Folder") then
				local equippedNameValue = equippedFolder:FindFirstChild("name")
				local equippedIdValue = equippedFolder:FindFirstChild("id")
				
				-- If there's already a weapon equipped and the new weapon is dual-wielded
				if equippedNameValue and equippedIdValue and equippedNameValue.Value ~= "" and equippedIdValue.Value ~= "" then
					if weaponStats and weaponStats.type == "Dual-Wielded" then
						-- Use secondary weapon handler
						local SecondaryWeaponHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("SecondaryWeaponHandler"))
						SecondaryWeaponHandler:EquipSecondaryWeapon(player, item.name, item.id)
						--print("[ItemActionHandler] Equipped as secondary weapon", item.name, "(id:", item.id, ") for", player.Name)
						
						-- Clear debounce and lock
						task.delay(0.05, function()
							if equipDebounce[player] then
								equipDebounce[player][itemId] = nil
							end
							playerActionLock[player] = nil
						end)
						return
					end
				end
			end
		end
	end

	-- Only check level requirement for weapons
	if item.itemType == "weapon" or item.itemType == nil then
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
			--print("[ItemActionHandler] Firing feedback event to player:", player.Name)
			-- Send feedback to client about level requirement
			itemFeedbackEvent:FireClient(player, "LevelRequirementNotMet", {
				itemName = item.name,
				requiredLevel = requiredLevel,
				playerLevel = playerLevel
			})
			--print("[ItemActionHandler] Feedback event fired successfully")
			equipDebounce[player][itemId] = nil
			playerActionLock[player] = nil
			return
		end
	end

	-- Equip based on item type
	if item.itemType == "spirit orb" then
		-- Equip as orb using setEquippedOrb
		InventoryManager.setEquippedOrb(player, item.name, item.id)
		--print("[ItemActionHandler] Equipped spirit orb", item.name, "(id:", item.id, ") for", player.Name)
	elseif item.itemType == "armor" then
		-- Equip as armor using ArmorsManager (update player data only)
		local ArmorsManager = require(script.Parent.ArmorsManager)
		local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
		local armorInfo = ArmorData[item.name]
		if armorInfo and armorInfo.Type then
			ArmorsManager.SetEquippedArmor(player, item.name, item.id)
			--print("[ItemActionHandler] Equipped armor", item.name, "(id:", item.id, ") for", player.Name)
		else
			warn("[ItemActionHandler] Armor info not found for", item.name)
		end
	else
		-- Equip as weapon using setEquippedWeapon
		-- NOTE: InventoryManager.setEquippedWeapon fires EquippedChanged event automatically
		InventoryManager.setEquippedWeapon(player, item.name, item.id)
		--print("[ItemActionHandler] Equipped weapon", item.name, "(id:", item.id, ") for", player.Name)
		-- Ensure tool is connected by syncing backpack
		if player.Character then
			InventoryManager.SyncBackpack(player, player.Character)
		end
	end
	-- Clear debounce after short delay (allowing for re-equip after a moment)
	task.delay(0.05, function()
		if equipDebounce[player] then
			equipDebounce[player][itemId] = nil
		end
		playerActionLock[player] = nil
	end)
end


function ItemActionHandler:DropItem(player, itemId)
	-- Check global cooldown to prevent spam
	if playerActionCooldown[player] and tick() - playerActionCooldown[player] < ACTION_COOLDOWN then
		return
	end
	playerActionCooldown[player] = tick()
	-- Block if another action is ongoing for this player
	if playerActionLock[player] then
		warn("[ItemActionHandler] Action already in progress for", player.Name, "- blocking DropItem")
		playerActionLock[player] = nil -- Always clear lock to prevent stuck state
		return
	end
	playerActionLock[player] = true
	-- Prevent dropping if the item is currently equipped (check live Stats first, then DataStore as fallback)
	local equippedIdValue = nil
	local stats = player:FindFirstChild("Stats")
	if stats then
		local equipped = stats:FindFirstChild("Equipped")
		if equipped and equipped:IsA("Folder") then
			local idValue = equipped:FindFirstChild("id")
			if idValue and idValue.Value ~= "" then
				equippedIdValue = idValue.Value
			end
		end
	end
	-- If not found in live stats, check DataStore as fallback
	if not equippedIdValue then
		local DataStoreService = game:GetService("DataStoreService")
		local statsStore = DataStoreService:GetDataStore("PlayerStats")
		local success, data = pcall(function()
			return statsStore:GetAsync("Player_" .. tostring(player.UserId))
		end)
		if success and data and data.Equipped and type(data.Equipped) == "table" then
			equippedIdValue = data.Equipped.id
		end
	end
	--print("[ItemActionHandler] Drop attempt: itemId=", tostring(itemId), ", equippedId=", tostring(equippedIdValue))
	if equippedIdValue and tostring(equippedIdValue) == tostring(itemId) then
		warn("[ItemActionHandler] Cannot drop currently equipped item for", player.Name, itemId, "(checked live Stats/DataStore)")
		dropDebounce[player] = dropDebounce[player] or {}
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end

	dropDebounce[player] = dropDebounce[player] or {}
	if dropDebounce[player][itemId] then
		-- Already processing this itemId for this player, ignore duplicate
		playerActionLock[player] = nil
		return
	end
	dropDebounce[player][itemId] = true
	--print("[ItemActionHandler] DropItem called for", player.Name, itemId)

	-- Remove item from inventory and save
	local item = InventoryManager.GetItemById(player, itemId)
	if not item then
		warn("[ItemActionHandler] DropItem: Item not found in inventory for", player.Name, itemId)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end

	local removed = InventoryManager.RemoveItem(player, itemId)
	if not removed then
		warn("[ItemActionHandler] DropItem: Failed to remove item from inventory for", player.Name, itemId)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end

	-- Spawn the dropped tool at player's root part for others to pick up
	local character = player.Character
	if not character then
		warn("[ItemActionHandler] DropItem: Player has no character", player.Name)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end
	local leftFoot = character:FindFirstChild("LeftFoot")
	if not leftFoot then
		warn("[ItemActionHandler] DropItem: No LeftFoot for", player.Name)
		dropDebounce[player][itemId] = nil
		playerActionLock[player] = nil
		return
	end

	-- Use ItemDropManager to spawn the drop model from ServerStorage, not the tool
	local ItemDropManager = require(script.Parent.ItemDropManager)
	local dropPosition = leftFoot.Position + Vector3.new(0, 0, 0)
	local spawnedDrop = ItemDropManager.SpawnItemDrop(item.name, dropPosition, player)
	if spawnedDrop then
		--print("[ItemActionHandler] Dropped", item.name, "(id:", item.id, ") at", tostring(dropPosition))
	else
		warn("[ItemActionHandler] Failed to spawn drop for", item.name, "at", tostring(dropPosition))
	end
	-- NOTE: InventoryManager.RemoveItem fires InventoryChanged event automatically
	-- Clear debounce after short delay (allowing for re-drop after a moment)
	task.delay(0.05, function()
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
	       elseif action == "Unequip" then
		       -- Determine item type and call appropriate unequip
		       local item = InventoryManager.GetItemById(player, itemId)
		       if item then
			       if item.itemType == "armor" then
				       local ArmorsManager = require(script.Parent.ArmorsManager)
				       local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
				       local armorInfo = ArmorData[item.name]
				       if armorInfo and armorInfo.Type then
					       ArmorsManager.UnequipAndRemoveAccessory(player, armorInfo.Type)
				       end
			       elseif item.itemType == "weapon" or item.itemType == nil then
				       -- Check if this is primary or secondary weapon
				       local stats = player:FindFirstChild("Stats")
				       if stats then
					       local equippedFolder = stats:FindFirstChild("Equipped")
					       local secondaryEquippedFolder = stats:FindFirstChild("SecondaryEquipped")
					       
					       local isPrimary = false
					       local isSecondary = false
					       
					       if equippedFolder and equippedFolder:IsA("Folder") then
						       local equippedId = equippedFolder:FindFirstChild("id")
						       if equippedId and equippedId.Value == itemId then
							       isPrimary = true
						       end
					       end
					       
					       if secondaryEquippedFolder and secondaryEquippedFolder:IsA("Folder") then
						       local secondaryEquippedId = secondaryEquippedFolder:FindFirstChild("id")
						       if secondaryEquippedId and secondaryEquippedId.Value == itemId then
							       isSecondary = true
						       end
					       end
					       
					       if isPrimary then
						       -- Unequipping primary weapon
						       -- Check if there's a secondary weapon to promote
						       if secondaryEquippedFolder then
							       local secondaryName = secondaryEquippedFolder:FindFirstChild("name")
							       local secondaryId = secondaryEquippedFolder:FindFirstChild("id")
							       
							       if secondaryName and secondaryId and secondaryName.Value ~= "" and secondaryId.Value ~= "" then
								       -- Get secondary weapon info before unequipping
								       local secondaryWeaponName = secondaryName.Value
								       local secondaryWeaponId = secondaryId.Value
								       
								       -- Unequip secondary first
							       local SecondaryWeaponHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("SecondaryWeaponHandler"))
								       SecondaryWeaponHandler:UnequipSecondaryWeapon(player)
								       
								       -- Unequip primary
								       local WeaponManager = require(script.Parent.WeaponManager)
								       WeaponManager.UnequipWeapon(player)
								       
								       -- Equip the secondary as new primary
								       InventoryManager.setEquippedWeapon(player, secondaryWeaponName, secondaryWeaponId)
								       --print("[ItemActionHandler] Promoted secondary weapon to primary:", secondaryWeaponName)
							       else
								       -- No secondary weapon, just unequip primary
								       local WeaponManager = require(script.Parent.WeaponManager)
								       WeaponManager.UnequipWeapon(player)
							       end
						       else
							       -- No secondary weapon folder, just unequip primary
							       local WeaponManager = require(script.Parent.WeaponManager)
							       WeaponManager.UnequipWeapon(player)
						       end
					       elseif isSecondary then
						       -- Unequipping secondary weapon - just unequip it
					       local SecondaryWeaponHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Combat"):WaitForChild("SecondaryWeaponHandler"))
					       SecondaryWeaponHandler:UnequipSecondaryWeapon(player)
					       --print("[ItemActionHandler] Unequipped secondary weapon")
				       else
						       -- Not equipped as either primary or secondary, ignore
						       warn("[ItemActionHandler] Weapon not equipped as primary or secondary:", item.name)
					       end
				       end
					       elseif item.itemType == "spirit orb" then
						       -- Use robust orb unequip logic from OrbSpiritHandler
						       local OrbSpiritHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("OrbSpiritHandler"))
						       OrbSpiritHandler.UnequipOrb(player)
			       end
		       end
	else
		warn("[ItemActionHandler] Unknown action from client:", action)
	end
end)

return ItemActionHandler
