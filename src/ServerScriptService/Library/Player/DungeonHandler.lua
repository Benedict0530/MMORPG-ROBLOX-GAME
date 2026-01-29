-- DungeonHandler.server.lua
-- Handles dungeon entry requests from client (item entry)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")


local DungeonHandler = {}

local DungeonEntryEvent = ReplicatedStorage:FindFirstChild("DungeonEntryEvent") or Instance.new("RemoteEvent")
DungeonEntryEvent.Name = "DungeonEntryEvent"
DungeonEntryEvent.Parent = ReplicatedStorage

local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonsData"))
local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))

local function teleportPlayerToDungeon(player, toMap)
	print("[DungeonHandler] Teleporting", player.Name, "to dungeon:", toMap)
	-- Fire TeleportGuiEvent to client for loading/transition UI
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TeleportGuiEvent = ReplicatedStorage:FindFirstChild("TeleportGuiEvent")
	if TeleportGuiEvent then
		TeleportGuiEvent:FireClient(player, toMap)
	end
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local playerMapValue = stats:FindFirstChild("PlayerMap")
	local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
	local mapFolder = workspace:FindFirstChild("Maps")
	local dungeonMap = mapFolder and mapFolder:FindFirstChild(toMap)
	local spawnName = "DungeonSpawn"
	-- Try to get spawnName from DungeonsData if available
	local DungeonsData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("DungeonsData"))
	local data = DungeonsData[toMap]
	if data and data.SpawnName then
		spawnName = data.SpawnName
	end
	local spawnPart = dungeonMap and dungeonMap:FindFirstChild(spawnName)
	if playerMapValue then
		playerMapValue.Value = toMap
	end
	if lastSpawnValue then
		lastSpawnValue.Value = spawnName
	end
	if spawnPart then
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Set IsPortalTeleporting to true to avoid anti-tp false positive
			player:SetAttribute("IsPortalTeleporting", true)
			hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
			print("[DungeonHandler] Player teleported to dungeon spawn:", spawnName)
			-- Remove IsPortalTeleporting after a short delay
			task.delay(10, function()
				player:SetAttribute("IsPortalTeleporting", false)
			end)
		end
	else
		warn("[DungeonHandler] Could not find dungeon spawn part for:", toMap, "spawn:", spawnName)
	end
end

function DungeonHandler.Init()
	DungeonEntryEvent.OnServerEvent:Connect(function(player, toMap, robux)
		local data = DungeonsData[toMap]
		if not data then return end

		if robux == true then
			-- Robux entry: store pending dungeon for this player
			DungeonHandler._pendingRobuxDungeon = DungeonHandler._pendingRobuxDungeon or {}
			DungeonHandler._pendingRobuxDungeon[player.UserId] = toMap
			print("[DungeonHandler] Registered pending Robux dungeon for", player.Name, toMap)
			return
		end

		local requiredItem = data.EntryItemRequirement
		local requiredLevel = data.EntryLevelRequirement or 1

		local stats = player:FindFirstChild("Stats")
		if not stats then return end
		local levelValue = stats:FindFirstChild("Level")
		local playerLevel = levelValue and levelValue.Value or 1

		if playerLevel < requiredLevel then
			-- Fire back to client with failure reason
			DungeonEntryEvent:FireClient(player, {success = false, reason = "You need to be level " .. tostring(requiredLevel) .. " to enter."})
			return
		end

		-- Check inventory for required item
		local inventory = InventoryManager.GetInventory(player)
		local hasItem = false
		local itemIndex = nil
		for i, item in ipairs(inventory) do
			if item.name == requiredItem then
				hasItem = true
				itemIndex = i
				break
			end
		end

		if not hasItem then
			DungeonEntryEvent:FireClient(player, {success = false, reason = "You need the item: " .. tostring(requiredItem)})
			return
		end

		-- Remove the entry item from inventory
		local itemId = inventory[itemIndex].id
		InventoryManager.RemoveItem(player, itemId)

		-- Teleport player to dungeon
		teleportPlayerToDungeon(player, toMap)
	end)

	-- Listen for Developer Product purchase receipt
	local MarketplaceService = game:GetService("MarketplaceService")
	local DEV_PRODUCT_ID = 3525149275 -- REPLACE with your actual Developer Product ID for 10 Robux
	DungeonHandler._pendingRobuxDungeon = DungeonHandler._pendingRobuxDungeon or {}
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		if receiptInfo.ProductId == DEV_PRODUCT_ID then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if player then
				if DungeonHandler._pendingRobuxDungeon and DungeonHandler._pendingRobuxDungeon[player.UserId] then
					local toMap = DungeonHandler._pendingRobuxDungeon[player.UserId]
					teleportPlayerToDungeon(player, toMap)
					DungeonHandler._pendingRobuxDungeon[player.UserId] = nil
				else
					warn("[DungeonHandler] No pending Robux dungeon for player", player.Name)
				end
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return DungeonHandler
