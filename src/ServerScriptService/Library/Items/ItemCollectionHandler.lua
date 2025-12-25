-- ItemCollectionHandler.lua
-- Handles item collection via RemoteEvent when player presses E
-- Supports coins and item drops
-- All saves are delegated to UnifiedDataStoreManager

local ItemCollectionHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

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
		return
	end
	
	-- Add item to player's inventory
	local success = InventoryManager.AddItem(player, itemName)
	
	if success then
	else
		warn("[ItemCollectionHandler] Failed to add " .. itemName .. " to player " .. player.Name .. " inventory")
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
		
		if itemType == "coin" then
			handleCoinCollection(player, item)
		elseif itemType == "drop" then
			handleItemDropCollection(player, item)
		end
		
		-- Update collection cooldown
		playerCollectCooldown[player.UserId] = now
		
		-- Destroy item after successful collection
		item:Destroy()
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
