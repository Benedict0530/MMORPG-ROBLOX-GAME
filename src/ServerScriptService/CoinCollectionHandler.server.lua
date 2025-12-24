-- ItemCollectionHandler.server.lua (renamed from CoinCollectionHandler)
-- Handles item collection via RemoteEvent when player presses E
-- Supports coins and item drops
-- All saves are delegated to UnifiedDataStoreManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))

-- InventoryManager will be loaded lazily when needed (it's a .server.lua file)
local InventoryManager = nil

-- Function to get InventoryManager (lazy load)
local function getInventoryManager()
	if InventoryManager then return InventoryManager end
	
	local ItemsFolder = ServerScriptService:FindFirstChild("Items")
	if ItemsFolder then
		local inventoryScript = ItemsFolder:FindFirstChild("InventoryManager")
		if inventoryScript then
			InventoryManager = require(inventoryScript)
			return InventoryManager
		end
	end
	return nil
end

-- Create RemoteEvent for item collection if it doesn't exist
local itemCollectRemote = ReplicatedStorage:FindFirstChild("ItemCollect")
if not itemCollectRemote then
	itemCollectRemote = Instance.new("RemoteEvent")
	itemCollectRemote.Name = "ItemCollect"
	itemCollectRemote.Parent = ReplicatedStorage
end

-- Keep old name for backward compatibility
local coinCollectRemote = ReplicatedStorage:FindFirstChild("CoinCollect")
if not coinCollectRemote then
	coinCollectRemote = itemCollectRemote -- Use the same remote
else
	-- Redirect old remote to new one
	coinCollectRemote.OnServerEvent:Connect(function(player, coin)
		itemCollectRemote:FireServer(player, coin) -- Not actually needed, but for reference
	end)
end

local COLLECT_DISTANCE = 10
local COLLECT_COOLDOWN = 0.5 -- Prevent rapid requests

-- Track items being collected to prevent duplication
local itemsBeingCollected = {}
-- Track player collection cooldown
local playerCollectCooldown = {}
-- Track pending money to save periodically instead of on every coin
local pendingMoneySave = {}

-- Determine if an item is a coin or a drop
local function getItemType(item)
	if item:FindFirstChild("CoinType") then
		return "coin"
	elseif item:FindFirstChild("ItemType") then
		return "drop"
	end
	return nil
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
		print("[ItemCollectionHandler] Item rejected - Type: " .. tostring(itemType) .. ", Parent: " .. tostring(item and item.Parent))
		return -- Item doesn't exist or is invalid
	end
	
	-- Prevent item duplication - check if already being collected
	if itemsBeingCollected[item] then
		return -- Item is already being collected
	end
	
	-- Player collection rate limiting
	local now = tick()
	if playerCollectCooldown[player.UserId] and (now - playerCollectCooldown[player.UserId]) < COLLECT_COOLDOWN then
		return -- Player is collecting too fast
	end
	
	-- Verify player character exists
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end
	
	local playerRoot = player.Character.HumanoidRootPart
	
	-- Get item position using GetPivot() which works on both parts and models
	local itemPivot = item:GetPivot()
	if not itemPivot then
		return
	end
	
	-- Verify distance (within 10 studs) - security check
	local distance = (itemPivot.Position - playerRoot.Position).Magnitude
	if distance > COLLECT_DISTANCE then
		return -- Too far away, possible cheating
	end
	
	-- Mark item as being collected
	itemsBeingCollected[item] = true
	
	if itemType == "coin" then
		-- Handle coin collection
		handleCoinCollection(player, item)
	elseif itemType == "drop" then
		-- Handle item drop collection
		handleItemDropCollection(player, item)
	end
	
	-- Update collection cooldown
	playerCollectCooldown[player.UserId] = now
	
	-- Destroy item after successful collection
	item:Destroy()
end)

-- Handle coin collection
function handleCoinCollection(player, coin)
	-- Get coin value
	local coinValueObj = coin:FindFirstChild("Value")
	local coinValue = coinValueObj and tonumber(coinValueObj.Value) or 1
	
	-- Validate coin value (prevent exploits)
	if not coinValue or coinValue < 0 or coinValue > 1000 then
		itemsBeingCollected[coin] = nil
		return -- Invalid coin value
	end
	
	-- Add coin value to player's money immediately to memory
	local statsFolder = player:FindFirstChild("Stats")
	if statsFolder then
		local moneyValue = statsFolder:FindFirstChild("Money")
		if moneyValue then
			moneyValue.Value = moneyValue.Value + coinValue
			-- Track pending money to save to datastore later (not immediately)
			pendingMoneySave[player.UserId] = (pendingMoneySave[player.UserId] or 0) + coinValue
		end
	end
	
	print("[ItemCollectionHandler] Player " .. player.Name .. " collected coin worth " .. coinValue)
end

-- Handle item drop collection
function handleItemDropCollection(player, itemDrop)
	-- Get InventoryManager (lazy load)
	local invManager = getInventoryManager()
	if not invManager then
		warn("[ItemCollectionHandler] InventoryManager not available, cannot add item to inventory")
		return
	end
	
	-- Get item name
	local itemNameObj = itemDrop:FindFirstChild("ItemName")
	local itemName = itemNameObj and itemNameObj.Value
	
	if not itemName then
		warn("[ItemCollectionHandler] Drop has no ItemName!")
		itemsBeingCollected[itemDrop] = nil
		return
	end
	
	-- Add item to player's inventory
	local success = invManager.AddItem(player, itemName)
	
	if success then
		print("[ItemCollectionHandler] Player " .. player.Name .. " collected item: " .. itemName)
	else
		warn("[ItemCollectionHandler] Failed to add " .. itemName .. " to player " .. player.Name .. " inventory")
	end
end

-- Function to save pending money to datastore
local function savePendingMoney(userId)
	if not pendingMoneySave[userId] or pendingMoneySave[userId] == 0 then
		return
	end
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	-- Delegate to UnifiedDataStoreManager
	UnifiedDataStoreManager.SaveMoney(player, false)
	pendingMoneySave[userId] = nil
end

-- Save money periodically (check every frame but only act on throttled interval)
local saveConnection
saveConnection = game:GetService("RunService").Heartbeat:Connect(function()
	for userId, money in pairs(pendingMoneySave) do
		if money and money > 0 then
			savePendingMoney(userId)
		end
	end
end)

local cleanupConnection
cleanupConnection = Players.PlayerRemoving:Connect(function(player)
	-- Save any pending money before player leaves (force save immediately)
	if pendingMoneySave[player.UserId] and pendingMoneySave[player.UserId] > 0 then
		UnifiedDataStoreManager.SaveMoney(player, true)
	end
	-- Clear player tracking
	playerCollectCooldown[player.UserId] = nil
	pendingMoneySave[player.UserId] = nil
end)

