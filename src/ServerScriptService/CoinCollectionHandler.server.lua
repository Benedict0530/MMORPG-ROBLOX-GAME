-- CoinCollectionHandler.server.lua
-- Handles coin collection via RemoteEvent when player presses E

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvent for coin collection if it doesn't exist
local coinCollectRemote = ReplicatedStorage:FindFirstChild("CoinCollect")
if not coinCollectRemote then
	coinCollectRemote = Instance.new("RemoteEvent")
	coinCollectRemote.Name = "CoinCollect"
	coinCollectRemote.Parent = ReplicatedStorage
end

local COLLECT_DISTANCE = 10
local COLLECT_COOLDOWN = 0.5 -- Prevent rapid requests
local statsStore = game:GetService("DataStoreService"):GetDataStore("PlayerStats")

-- Track coins being collected to prevent duplication
local coinsBeingCollected = {}
-- Track player collection cooldown
local playerCollectCooldown = {}
-- Track pending money to save periodically instead of on every coin
local pendingMoneySave = {}
-- Track last save time per player to throttle datastore requests
local lastSaveTime = {}
-- Save interval (save every 5 seconds or when player leaves)
local SAVE_INTERVAL = 5

-- Handle coin collection request from client
coinCollectRemote.OnServerEvent:Connect(function(player, coin)
	-- Validate player exists and is in game
	if not player or not Players:FindFirstChild(player.Name) then
		return
	end
	
	-- Validate coin exists and has proper structure
	if not coin or not coin.Parent or not coin:FindFirstChild("CoinType") then
		return -- Coin doesn't exist or is invalid
	end
	
	-- Prevent coin duplication - check if already being collected
	if coinsBeingCollected[coin] then
		return -- Coin is already being collected
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
	local coinRoot = coin:FindFirstChild("HumanoidRootPart") or coin:FindFirstChild("PrimaryPart") or coin
	
	-- Verify coin root exists
	if not coinRoot then
		return
	end
	
	-- Verify distance (within 5 studs) - security check
	local distance = (coinRoot.Position - playerRoot.Position).Magnitude
	if distance > COLLECT_DISTANCE then
		return -- Too far away, possible cheating
	end
	
	-- Mark coin as being collected
	coinsBeingCollected[coin] = true
	
	-- Get coin value
	local coinValueObj = coin:FindFirstChild("Value")
	local coinValue = coinValueObj and tonumber(coinValueObj.Value) or 1
	
	-- Validate coin value (prevent exploits)
	if not coinValue or coinValue < 0 or coinValue > 1000 then
		coinsBeingCollected[coin] = nil
		return -- Invalid coin value
	end
	
	-- Add coin value to player's money immediately to memory
	local key = "Player_" .. player.UserId
	local statsFolder = player:FindFirstChild("Stats")
	if statsFolder then
		local moneyValue = statsFolder:FindFirstChild("Money")
		if moneyValue then
			moneyValue.Value = moneyValue.Value + coinValue
			print("[CoinCollectionHandler] Player " .. player.Name .. " collected " .. coinValue .. " coins! Total: " .. moneyValue.Value)
			
			-- Track pending money to save to datastore later (not immediately)
			pendingMoneySave[player.UserId] = (pendingMoneySave[player.UserId] or 0) + coinValue
		end
	end
	
	-- Update collection cooldown
	playerCollectCooldown[player.UserId] = now
	
	-- Destroy coin after successful collection
	coin:Destroy()
end)

-- Cleanup tracking table when coin is destroyed (safety)
game:GetService("Debris"):AddItem(Instance.new("Folder"), 60) -- Periodic cleanup via folder destruction

-- Function to save pending money to datastore
local function savePendingMoney(userId)
	if not pendingMoneySave[userId] or pendingMoneySave[userId] == 0 then
		return
	end
	
	local now = tick()
	-- Only save if enough time has passed since last attempt
	if lastSaveTime[userId] and (now - lastSaveTime[userId]) < SAVE_INTERVAL then
		return
	end
	
	lastSaveTime[userId] = now
	local key = "Player_" .. userId
	local moneyToSave = pendingMoneySave[userId]
	
	local success, err = pcall(function()
		statsStore:UpdateAsync(key, function(old)
			old = old or {}
			old["Money"] = (old["Money"] or 0) + moneyToSave
			return old
		end)
	end)
	
	if success then
		pendingMoneySave[userId] = nil
		print("[CoinCollectionHandler] Saved " .. moneyToSave .. " money for user " .. userId)
	else
		warn("[CoinCollectionHandler] Failed to save money for user " .. userId .. ": " .. tostring(err))
		-- On failure, allow retry after 2 seconds instead of immediately
		lastSaveTime[userId] = now - (SAVE_INTERVAL - 2)
	end
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
		lastSaveTime[player.UserId] = 0 -- Force save by resetting timer
		savePendingMoney(player.UserId)
	end
	-- Clear player tracking
	playerCollectCooldown[player.UserId] = nil
	pendingMoneySave[player.UserId] = nil
	lastSaveTime[player.UserId] = nil
end)
