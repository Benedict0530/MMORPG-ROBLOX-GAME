-- ItemCollectionHandler.lua
-- Handles item collection via RemoteEvent when player presses E
-- Supports coins and item drops
-- All saves are delegated to UnifiedDataStoreManager

local ItemCollectionHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local SFXEvent = ReplicatedStorage:FindFirstChild("SFXEvent")

-- Dependencies will be injected
local UnifiedDataStoreManager
local InventoryManager

-- Track items being collected to prevent duplication
local itemsBeingCollected = {}
-- Track player collection cooldown
local playerCollectCooldown = {}
-- Track pending money to save periodically
local pendingMoneySave = {}

local COLLECT_DISTANCE = 10
local COLLECT_COOLDOWN = 0.1

-- Determine if an item is a coin or a drop
local function getItemType(item)
	if item:FindFirstChild("CoinType") then
		return "coin"
	elseif item:FindFirstChild("ItemType") then
		return "drop"
	end
	return nil
end

-- Handle coin collection
local function handleCoinCollection(player, coin)
	local coinValueObj = coin:FindFirstChild("Value")
	local coinValue = coinValueObj and tonumber(coinValueObj.Value) or 1
	
	-- Validate coin value (prevent exploits)
	if not coinValue or coinValue < 0 or coinValue > 1000 then
		itemsBeingCollected[coin] = nil
		return
	end
	
	-- Add coin value to player's money
	local statsFolder = player:FindFirstChild("Stats")
	if statsFolder then
		local moneyValue = statsFolder:FindFirstChild("Money")
		if moneyValue then
			moneyValue.Value = moneyValue.Value + coinValue
			pendingMoneySave[player.UserId] = (pendingMoneySave[player.UserId] or 0) + coinValue
			SFXEvent:FireClient(player, "CoinPickup")
		end
	end
	
end

-- Handle item drop collection
local function handleItemDropCollection(player, itemDrop)
	local itemNameObj = itemDrop:FindFirstChild("ItemName")
	local itemName = itemNameObj and itemNameObj.Value
	
	if not itemName then
		warn("[ItemCollectionHandler] Drop has no ItemName!")
		itemsBeingCollected[itemDrop] = nil
		return false
	end
	
	print("[ItemCollectionHandler] Player " .. player.Name .. " collecting item: " .. itemName)
	
	-- Get item type from the drop if available, otherwise pass nil to let InventoryManager infer it
	local itemTypeObj = itemDrop:FindFirstChild("ItemType")
	local itemType = itemTypeObj and itemTypeObj.Value
	
	print("[ItemCollectionHandler] Item type from drop: " .. tostring(itemType))
	
	-- Add item to player's inventory with itemType
	local success, errorOrId = InventoryManager.AddItem(player, itemName, itemType)
	
	if success then
		print("[ItemCollectionHandler] Successfully added " .. itemName .. " to " .. player.Name .. "'s inventory")
		SFXEvent:FireClient(player, "ItemPickup")
		return true
	else
		-- Handle inventory full case
		local errorMsg = errorOrId or "Failed to add item to inventory"
		warn("[ItemCollectionHandler] " .. errorMsg .. " for player " .. player.Name)
		
		-- Notify player that inventory is full
		if errorMsg == "Inventory is full!" then
			local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
			if notificationEvent then
				notificationEvent:FireClient(player, "Inventory Full", "Your inventory is full! Max capacity: " .. tostring(player.Stats.InventoryMaxCapacity.Value), "error")
			end
		end
		return false
	end
end

-- Check if player can pick up an item based on ownership rules
local function canPlayerPickupItem(player, item)
	local dropOwner = item:FindFirstChild("DropOwner")
	local dropTime = item:FindFirstChild("DropTime")
	
	-- If no ownership info, item is free for all
	if not dropOwner or not dropTime then
		return true
	end
	
	local ownerValue = dropOwner.Value
	local elapsedTime = tick() - dropTime.Value
	
	-- If 10+ seconds have passed, item is free for all
	if elapsedTime >= 10 then
		return true
	end
	
	-- Within 10 second window: only owner can pick it up
	if ownerValue and ownerValue == player then
		return true
	end
	
	-- Player is not owner and ownership window hasn't expired
	return false
end

-- Function to save pending money to datastore
local function savePendingMoney(userId)
	if not pendingMoneySave[userId] or pendingMoneySave[userId] == 0 then
		return
	end
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	UnifiedDataStoreManager.SaveMoney(player, false)
	pendingMoneySave[userId] = nil
end

-- Initialize item collection handler
function ItemCollectionHandler.Initialize(unifiedDataStore, inventoryMgr)
	UnifiedDataStoreManager = unifiedDataStore
	InventoryManager = inventoryMgr
	
	-- Create RemoteEvent for item collection if it doesn't exist
	local itemCollectRemote = ReplicatedStorage:FindFirstChild("ItemCollect")
	if not itemCollectRemote then
		itemCollectRemote = Instance.new("RemoteEvent")
		itemCollectRemote.Name = "ItemCollect"
		itemCollectRemote.Parent = ReplicatedStorage
	end
	
	-- Handle item collection request from client
	itemCollectRemote.OnServerEvent:Connect(function(player, item)
		-- Validate player exists and is in game
		if not player or not Players:FindFirstChild(player.Name) then
			return
		end

		-- If no item is provided, find the nearest valid collectible item
		if not item then
			if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
				return
			end
			local playerRoot = player.Character.HumanoidRootPart
			local closestItem = nil
			local closestDistance = COLLECT_DISTANCE
			local closestIsCoin = false
			
			for _, candidate in ipairs(workspace:GetChildren()) do
				if (candidate:FindFirstChild("CoinType") or candidate:FindFirstChild("ItemType")) and not itemsBeingCollected[candidate] then
					local itemPivot = candidate:GetPivot()
					if itemPivot then
						local distance = (itemPivot.Position - playerRoot.Position).Magnitude
						if distance <= closestDistance and canPlayerPickupItem(player, candidate) then
							-- Check if this is a coin
							local isCoin = candidate:FindFirstChild("CoinType") ~= nil
							
							-- Prioritize coins: always pick coin if closer, or if we don't have a coin yet
							if isCoin then
								if not closestIsCoin or distance < closestDistance then
									closestDistance = distance
									closestItem = candidate
									closestIsCoin = true
								end
							-- Only pick non-coin items if we haven't found a coin
							elseif not closestIsCoin then
								closestDistance = distance
								closestItem = candidate
								closestIsCoin = false
							end
						end
					end
				end
			end
			item = closestItem
		end

		-- If still no item, nothing to collect
		if not item then return end

		-- Determine item type
		local itemType = getItemType(item)

		-- Validate item exists and has proper structure
		if not item or not item.Parent or not itemType then
			return
		end

		-- Prevent item duplication
		if itemsBeingCollected[item] then
			return
		end

		-- Player collection rate limiting
		local now = tick()
		if playerCollectCooldown[player.UserId] and (now - playerCollectCooldown[player.UserId]) < COLLECT_COOLDOWN then
			return
		end

		-- Verify player character exists
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			return
		end

		local playerRoot = player.Character.HumanoidRootPart

		-- Get item position using GetPivot()
		local itemPivot = item:GetPivot()
		if not itemPivot then
			return
		end

		-- Verify distance (within 10 studs) - security check
		local distance = (itemPivot.Position - playerRoot.Position).Magnitude
		if distance > COLLECT_DISTANCE then
			return
		end

		-- Check ownership restrictions for both coins and drops
		if not canPlayerPickupItem(player, item) then
			-- Player is not allowed to pick up this item yet
			return
		end

		-- Mark item as being collected
		itemsBeingCollected[item] = true

		local success = false
		if itemType == "coin" then
			handleCoinCollection(player, item)
			success = true -- Coins are always successfully collected
		elseif itemType == "drop" then
			local dropSuccess, errorOrId = handleItemDropCollection(player, item)
			success = dropSuccess -- Use the actual success return from handleItemDropCollection
		end

		-- Update collection cooldown
		playerCollectCooldown[player.UserId] = now

		-- Only destroy the item if it was successfully collected
		if success then
			item:Destroy()
		else
			-- Item collection failed (inventory full), remove from being collected
			itemsBeingCollected[item] = nil
		end
	end)
	
	-- Save money periodically
	game:GetService("RunService").Heartbeat:Connect(function()
		for userId, money in pairs(pendingMoneySave) do
			if money and money > 0 then
				savePendingMoney(userId)
			end
		end
	end)
	
	-- Save money before player leaves
	Players.PlayerRemoving:Connect(function(player)
		if pendingMoneySave[player.UserId] and pendingMoneySave[player.UserId] > 0 then
			UnifiedDataStoreManager.SaveMoney(player, true)
		end
		playerCollectCooldown[player.UserId] = nil
		pendingMoneySave[player.UserId] = nil
	end)
	
end

return ItemCollectionHandler
