local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require the InventoryManager module (the .lua file, not this script)
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))

-- Create RemoteEvent for notifying clients of inventory changes
local inventoryChangedEvent = ReplicatedStorage:FindFirstChild("InventoryChanged")
if not inventoryChangedEvent then
	inventoryChangedEvent = Instance.new("RemoteEvent")
	inventoryChangedEvent.Name = "InventoryChanged"
	inventoryChangedEvent.Parent = ReplicatedStorage
end

-- All the PlayerAdded and event handling logic is here
-- The module itself is in InventoryManager.lua and can be required by other scripts

Players.PlayerAdded:Connect(function(player)
	-- Use task.spawn to ensure this doesn't block other PlayerAdded handlers
	task.spawn(function()
		-- Wait for PlayerDataStore to initialize stats
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
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveInventory(player.UserId, InventoryManager.GetInventory(player), true)
end)
