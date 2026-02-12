
-- DungeonHandler.server.lua
-- Handles dungeon entry requests from client (item entry)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Utility to create RemoteEvent if missing (non-blocking)
local function getOrCreateRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
		--print("[DungeonHandler] Created RemoteEvent:", name)
	end
	return event
end

-- Create all RemoteEvents immediately at script load (before any PlayerAdded)
local DungeonEntryEvent = getOrCreateRemoteEvent("DungeonEntryEvent")
local DungeonLeaveEvent = getOrCreateRemoteEvent("DungeonLeaveEvent")

--print("[DungeonHandler] All RemoteEvents created and ready")

-- Create DungeonTimers folder for tracking active timers
local DungeonTimersFolder = ReplicatedStorage:FindFirstChild("DungeonTimers")
if not DungeonTimersFolder then
	DungeonTimersFolder = Instance.new("Folder")
	DungeonTimersFolder.Name = "DungeonTimers"
	DungeonTimersFolder.Parent = ReplicatedStorage
	--print("[DungeonHandler] Created DungeonTimers folder")
else
	-- Clear all old IntValues from previous server session
	for _, child in ipairs(DungeonTimersFolder:GetChildren()) do
		if child:IsA("IntValue") then
			child:Destroy()
			--print("[DungeonHandler] Cleared old timer IntValue:", child.Name)
		end
	end
	--print("[DungeonHandler] Cleaned up DungeonTimers folder")
end

local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonsData"))
local InventoryManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("InventoryManager"))
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- Per-player dungeon timers (SINGLE source of truth)
local playerDungeonTimers = {} -- [userId] = {toMap = string, endTime = number, connection = RBXScriptConnection}
local playerTimerLoaded = {} -- [userId] = true when timer has finished loading from DataStore

-- Helper function to create/update timer IntValue for player
-- NOTE: IntValue stores REMAINING SECONDS, not absolute endTime, to avoid clock sync issues
local function updateTimerValue(userId, endTime)
	if not userId or not endTime then return end
	
	-- Validate endTime is in the future (at least 5 seconds remaining)
	local remaining = endTime - tick()
	if remaining <= 5 then
		warn("[DungeonHandler] Attempted to set expired timer for userId:", userId, "remaining:", remaining, "- not setting IntValue")
		return
	end
	
	local timerValue = DungeonTimersFolder:FindFirstChild(tostring(userId))
	if not timerValue then
		timerValue = Instance.new("IntValue")
		timerValue.Name = tostring(userId)
		timerValue.Parent = DungeonTimersFolder
		--print("[DungeonHandler] Created timer IntValue for userId:", userId)
	end
	-- Store REMAINING SECONDS instead of absolute endTime to avoid clock desync
	timerValue.Value = math.floor(remaining)
	--print("[DungeonHandler] Updated timer IntValue for userId:", userId, "remainingSeconds:", math.floor(remaining))
end

-- Helper function to remove timer IntValue for player
local function removeTimerValue(userId)
	if not userId then return end
	
	local timerValue = DungeonTimersFolder:FindFirstChild(tostring(userId))
	if timerValue then
		timerValue:Destroy()
		--print("[DungeonHandler] Removed timer IntValue for userId:", userId)
	end
end
local function clearDungeonTimer(userId, clearDataStore)
	if not userId then return end
	
	-- Disconnect timer connection if exists
	if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
		playerDungeonTimers[userId].connection:Disconnect()
	end
	
	-- Clear in-memory timer data
	playerDungeonTimers[userId] = nil
	
	-- Remove IntValue from DungeonTimers folder
	removeTimerValue(userId)
	
	-- Only clear from DataStore if explicitly requested (manual leave or expiry)
	if clearDataStore then
		UnifiedDataStoreManager.ClearDungeonTimer(userId)
		--print("[DungeonHandler] Cleared timer from DataStore for userId:", userId)
	else
		--print("[DungeonHandler] Cleared in-memory timer for userId:", userId)
	end
end
-- Handle player request to leave dungeon
DungeonLeaveEvent.OnServerEvent:Connect(function(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local playerMapValue = stats:FindFirstChild("PlayerMap")
	local currentMap = playerMapValue and playerMapValue.Value
	local ddata = currentMap and DungeonsData[currentMap]
	if ddata and ddata.TimeLimitMinutes and ddata.OutMap and ddata.OutSpawn then
		-- 1. Clear timer (including DataStore since manual leave)
		--print("[DungeonHandler] Clearing dungeon timer for player", player.Name, player.UserId)
		clearDungeonTimer(player.UserId, true)
		-- 2. Save stats to datastore
		UnifiedDataStoreManager.SaveStats(player, false)
		-- 3. Teleport player to exit
		local outMap = ddata.OutMap or "Grimleaf 1"
		local outSpawn = ddata.OutSpawn or "DungeonExitSpawn"
		local mapFolder = workspace:FindFirstChild("Maps")
		local outMapObj = mapFolder and mapFolder:FindFirstChild(outMap)
		local outSpawnPart = outMapObj and outMapObj:FindFirstChild(outSpawn)
		if outSpawnPart then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				player:SetAttribute("IsPortalTeleporting", true)
				hrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
				task.delay(10, function()
					player:SetAttribute("IsPortalTeleporting", false)
				end)
			end
		end
		-- Update stats
		if playerMapValue then playerMapValue.Value = outMap end
		local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
		if lastSpawnValue then lastSpawnValue.Value = outSpawn end
		-- Optionally notify client
		local TeleportGuiEvent = game:GetService("ReplicatedStorage"):FindFirstChild("TeleportGuiEvent")
		if TeleportGuiEvent then
			TeleportGuiEvent:FireClient(player, outMap)
		end
	end
	-- Always clear timer as a failsafe
	--print("[DungeonHandler] (Failsafe) Clearing dungeon timer for player", player.Name, player.UserId)
	clearDungeonTimer(player.UserId, true)
end)

local function saveDungeonTimer(userId, toMap, endTime)
	if not userId or not toMap or not endTime then 
		warn("[DungeonHandler] Invalid timer save params:", userId, toMap, endTime)
		return 
	end
	
	local remaining = endTime - tick()
	local data = DungeonsData[toMap]
	if data and data.TimeLimitMinutes and data.OutMap and data.OutSpawn then
		-- Update in-memory timer
		if not playerDungeonTimers[userId] then
			playerDungeonTimers[userId] = {}
		end
		playerDungeonTimers[userId].toMap = toMap
		playerDungeonTimers[userId].endTime = endTime
		
		-- Update IntValue for client tracking
		updateTimerValue(userId, endTime)
		
		-- Save to DataStore (for session persistence)
		UnifiedDataStoreManager.SaveDungeonTimer(userId, toMap, endTime)
		--print("[DungeonHandler] Saved timer to DataStore for userId:", userId, "map:", toMap, "remaining:", math.floor(remaining), "seconds")
	end
end

local function getPlayerTimer(userId)
	if not userId then return nil end
	return playerDungeonTimers[userId]
end

local playerHeartbeatPause = {} -- [userId] = true if Heartbeat should skip this player

local function teleportPlayerToDungeon(player, toMap)
	--print("[DungeonHandler] Teleporting", player.Name, "to dungeon:", toMap)
	local stats = player:FindFirstChild("Stats")
	if not stats then --[[print("[DungeonHandler][DEBUG] No Stats folder for", player.Name);]] return end
	local playerMapValue = stats:FindFirstChild("PlayerMap")
	local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
	--print("[DungeonHandler][DEBUG] PlayerMap before teleport:", playerMapValue and playerMapValue.Value)
	--print("[DungeonHandler][DEBUG] LastSpawnName before teleport:", lastSpawnValue and lastSpawnValue.Value)
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
		--print("[DungeonHandler][DEBUG] Set PlayerMap to:", toMap)
	end
	if lastSpawnValue then
		lastSpawnValue.Value = spawnName
		--print("[DungeonHandler][DEBUG] Set LastSpawnName to:", spawnName)
	end
	if spawnPart then
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Set IsPortalTeleporting to true to avoid anti-tp false positive
			player:SetAttribute("IsPortalTeleporting", true)
			hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
			--print("[DungeonHandler] Player teleported to dungeon spawn:", spawnName)
			-- Pause Heartbeat check for this player until loading screen is gone
			playerHeartbeatPause[player.UserId] = true
			-- Remove IsPortalTeleporting after a short delay
			task.delay(10, function()
				player:SetAttribute("IsPortalTeleporting", false)
			end)
		end
	else
		warn("[DungeonHandler] Could not find dungeon spawn part for:", toMap, "spawn:", spawnName)
	end

	-- Start dungeon timer for this player if dungeon has a time limit and OutMap/OutSpawn
	if data and data.TimeLimitMinutes and data.OutMap and data.OutSpawn then
		local userId = player.UserId
		-- Only set a new timer if the player does not already have a valid timer for this dungeon
		local timerData = getPlayerTimer(userId)
		local shouldSetTimer = true
		
		if timerData and timerData.toMap == toMap and timerData.endTime and tick() < timerData.endTime then
			shouldSetTimer = false
			--print("[DungeonHandler] Player", player.Name, "already has valid timer for", toMap)
		end
		
		if shouldSetTimer then
			--print("[DungeonHandler] Setting new timer for", player.Name, "in", toMap)
			
			-- Cancel any previous timer for THIS player
			if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
				playerDungeonTimers[userId].connection:Disconnect()
			end
			local timeLimit = data.TimeLimitMinutes * 60
			local endTime = tick() + timeLimit
			saveDungeonTimer(userId, toMap, endTime) -- This will also update IntValue
			
			-- Listen for player leaving (cleanup connection only, keep timer data)
			local function cleanup()
				if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
					playerDungeonTimers[userId].connection:Disconnect()
					playerDungeonTimers[userId].connection = nil
				end
				-- Keep toMap and endTime for rejoin
			end
			
			local conn = player.AncestryChanged:Connect(function(_, parent)
				if not parent then cleanup() end
			end)
			
			-- Store connection in player's timer data
			if not playerDungeonTimers[userId] then
				playerDungeonTimers[userId] = {}
			end
			playerDungeonTimers[userId].connection = conn
			-- Start timer countdown task
			task.spawn(function()
				while playerDungeonTimers[userId] and playerDungeonTimers[userId].endTime and tick() < playerDungeonTimers[userId].endTime do
					task.wait(1)
				end
				
				-- Verify timer still exists for THIS player
				if not playerDungeonTimers[userId] or not playerDungeonTimers[userId].endTime then 
					return -- Timer was cleared
				end
				
				-- Timer expired, teleport player out
				--print("[DungeonHandler] Dungeon timer expired for", player.Name, "userId:", userId)
				
				-- Clear timer completely (including DataStore since expired) - IntValue will be removed automatically
				clearDungeonTimer(userId, true)
				
				-- Teleport player to OutMap/OutSpawn from DungeonsData
				local outMap = data.OutMap or "Grimleaf 1"
				local outSpawn = data.OutSpawn or "DungeonExitSpawn"
				local mapFolder = workspace:FindFirstChild("Maps")
				local outMapObj = mapFolder and mapFolder:FindFirstChild(outMap)
				local outSpawnPart = outMapObj and outMapObj:FindFirstChild(outSpawn)
				if outSpawnPart then
					local character = player.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					if hrp then
						player:SetAttribute("IsPortalTeleporting", true)
						hrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
						--print("[DungeonHandler] Player teleported out of dungeon to:", outMap, outSpawn)
						task.delay(10, function()
							player:SetAttribute("IsPortalTeleporting", false)
						end)
					end
				end
				-- Update stats
				local stats = player:FindFirstChild("Stats")
				if stats then
					local playerMapValue = stats:FindFirstChild("PlayerMap")
					local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
					if playerMapValue then playerMapValue.Value = outMap end
					if lastSpawnValue then lastSpawnValue.Value = outSpawn end
				end
				-- Optionally notify client (could fire TeleportGuiEvent)
				if TeleportGuiEvent then
					TeleportGuiEvent:FireClient(player, outMap)
				end
			end)
		end
	end
end

-- Heartbeat-based dungeon state check for all players (always running)

local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("Stats")
		if stats then
			local playerMapValue = stats:FindFirstChild("PlayerMap")
			local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
			local currentMap = playerMapValue and playerMapValue.Value
			local ddata = currentMap and DungeonsData[currentMap]
			local userId = player.UserId
			local timerData = getPlayerTimer(userId)
			
			-- CRITICAL: Validate timer belongs to THIS player
			if timerData and timerData.toMap and timerData.endTime and tick() < timerData.endTime then
				-- Double-check timer hasn't expired (with 1 second buffer)
				local remaining = timerData.endTime - tick()
				if remaining <= 1 then
					--print("[DungeonHandler][HEARTBEAT] Timer expired for", player.Name, "userId:", userId, "clearing")
				clearDungeonTimer(userId, true)
				else
					-- Player has valid timer - check if they're in the right place
					if not ddata or currentMap ~= timerData.toMap then
						-- Player should be in dungeon but isn't - teleport them back
						--print("[DungeonHandler][HEARTBEAT] Player", player.Name, "(userId:", userId, ") has timer for", timerData.toMap, "but is in", currentMap, "- teleporting back")
						teleportPlayerToDungeon(player, timerData.toMap)
						continue
					end
				end
			else
				if timerData then
					-- print("[DungeonHandler][DEBUG] Player", player.Name, "timerData found but not valid for teleport. toMap:", timerData.toMap, "endTime:", timerData.endTime, "tick():", tick())
				else
					-- print("[DungeonHandler][DEBUG] Player", player.Name, "no valid timerData for teleport check.")
				end
			end
			-- Orphaned dungeon check: only teleport out if timerData is nil or expired
			if ddata and ddata.TimeLimitMinutes and ddata.OutMap and ddata.OutSpawn and (not timerData or not timerData.endTime or tick() >= timerData.endTime) then
				if not timerData then
					--print("[DungeonHandler][DEBUG] Player", player.Name, "being teleported out: timerData is nil on Heartbeat.")
				elseif not timerData.endTime then
					--print("[DungeonHandler][DEBUG] Player", player.Name, "being teleported out: timerData.endTime is nil on Heartbeat.")
				elseif tick() >= timerData.endTime then
					--print("[DungeonHandler][DEBUG] Player", player.Name, "being teleported out: timer expired (now:", tick(), ", endTime:", timerData.endTime, ")")
				end
				local outMap = ddata.OutMap or "Grimleaf 1"
				local outSpawn = ddata.OutSpawn or "DungeonExitSpawn"
				local mapFolder = workspace:FindFirstChild("Maps")
				local outMapObj = mapFolder and mapFolder:FindFirstChild(outMap)
				local outSpawnPart = outMapObj and outMapObj:FindFirstChild(outSpawn)
				-- Failsafe: Always teleport out, even if character or HRP is missing (queue for respawn)
				local function teleportOut()
					local character = player.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					if hrp then
						player:SetAttribute("IsPortalTeleporting", true)
						hrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
						task.delay(10, function()
							player:SetAttribute("IsPortalTeleporting", false)
						end)
					else
						-- If HRP missing, queue teleport on next CharacterAdded
						player.CharacterAdded:Once(function(char)
							local newHrp = char:WaitForChild("HumanoidRootPart", 5)
							if newHrp and outSpawnPart then
								player:SetAttribute("IsPortalTeleporting", true)
								newHrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
								task.delay(10, function()
									player:SetAttribute("IsPortalTeleporting", false)
								end)
							end
						end)
					end
				end
				if outSpawnPart then
					teleportOut()
				end
				-- Update stats
				if playerMapValue then playerMapValue.Value = outMap end
				if lastSpawnValue then lastSpawnValue.Value = outSpawn end
				UnifiedDataStoreManager.SaveStats(player, false)
			clearDungeonTimer(player.UserId, true)
				-- Optionally notify client
				local TeleportGuiEvent = game:GetService("ReplicatedStorage"):FindFirstChild("TeleportGuiEvent")
				if TeleportGuiEvent then
					TeleportGuiEvent:FireClient(player, outMap)
				end
			-- Resume timer if valid (this handles rejoins)
			elseif timerData and timerData.toMap and timerData.endTime and tick() < timerData.endTime then
				local ddata2 = DungeonsData[timerData.toMap]
				if ddata2 and ddata2.TimeLimitMinutes and ddata2.OutMap and ddata2.OutSpawn then
					local outMap = ddata2.OutMap or "Grimleaf 1"
					local outSpawn = ddata2.OutSpawn or "DungeonExitSpawn"
					
					-- Only resume if timer doesn't already have a connection AND timer hasn't expired
					if not playerDungeonTimers[userId] or not playerDungeonTimers[userId].connection then
						local remaining = timerData.endTime - tick()
						
						-- Double-check timer still has time before resuming
						if remaining <= 1 then
							--print("[DungeonHandler][HEARTBEAT] Timer expired during resume check for", player.Name, "not resuming")
						else
								--print("[DungeonHandler][HEARTBEAT] Resuming timer for", player.Name, "userId:", userId, "remaining:", math.floor(remaining), "seconds")
						
							-- Clean up old connection if exists
							if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
								playerDungeonTimers[userId].connection:Disconnect()
							end
							
							local function cleanup()
								if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
									playerDungeonTimers[userId].connection:Disconnect()
									playerDungeonTimers[userId].connection = nil
								end
							end
							
							local conn = player.AncestryChanged:Connect(function(_, parent)
								if not parent then cleanup() end
							end)
							
							if not playerDungeonTimers[userId] then
								playerDungeonTimers[userId] = {}
							end
							playerDungeonTimers[userId].connection = conn
							
							task.spawn(function()
								while playerDungeonTimers[userId] and playerDungeonTimers[userId].endTime and tick() < playerDungeonTimers[userId].endTime do
									task.wait(1)
								end
								if not playerDungeonTimers[userId] or not playerDungeonTimers[userId].endTime then return end
								
								clearDungeonTimer(userId, true)
								
								-- Teleport player to OutMap/OutSpawn from DungeonsData
								local mapFolder = workspace:FindFirstChild("Maps")
								local outMapObj = mapFolder and mapFolder:FindFirstChild(outMap)
								local outSpawnPart = outMapObj and outMapObj:FindFirstChild(outSpawn)
								if outSpawnPart then
									local character = player.Character
									local hrp = character and character:FindFirstChild("HumanoidRootPart")
									if hrp then
										player:SetAttribute("IsPortalTeleporting", true)
										hrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
										task.delay(10, function()
											player:SetAttribute("IsPortalTeleporting", false)
										end)
									end
								end
								-- Update stats
								local stats = player:FindFirstChild("Stats")
								if stats then
									local playerMapValue = stats:FindFirstChild("PlayerMap")
									local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
									if playerMapValue then playerMapValue.Value = outMap end
									if lastSpawnValue then lastSpawnValue.Value = outSpawn end
									UnifiedDataStoreManager.SaveStats(player, false)
								end
								-- Optionally notify client
								local TeleportGuiEvent = game:GetService("ReplicatedStorage"):FindFirstChild("TeleportGuiEvent")
								if TeleportGuiEvent then
									TeleportGuiEvent:FireClient(player, outMap)
								end
							end)
						end
					end
				end
			end
		end
	end
end)

-- Clean up pause flag when player leaves


Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	--print("[DungeonHandler] Player", player.Name, "userId:", userId, "leaving - cleaning up")
	
	-- Always try to save dungeon timer if player is in a dungeon with a time limit
	local stats = player:FindFirstChild("Stats")
	local playerMapValue = stats and stats:FindFirstChild("PlayerMap")
	local currentMap = playerMapValue and playerMapValue.Value
	local ddata = currentMap and DungeonsData[currentMap]
	local timerData = getPlayerTimer(userId)

	-- Save timer to DataStore for session persistence
	if timerData and timerData.endTime and timerData.toMap then
		local remaining = timerData.endTime - tick()
		-- Only save if timer has time remaining
		if remaining > 5 then
			saveDungeonTimer(player.UserId, timerData.toMap, timerData.endTime)
			--print("[DungeonHandler] Player", player.Name, "left with", math.floor(remaining), "seconds remaining on timer")
		else
			--print("[DungeonHandler] Player", player.Name, "timer expired or about to expire, not saving")
		end
	else
		--print("[DungeonHandler] Player", player.Name, "left with no active dungeon timer")
	end
	
	-- Clean up in-memory timer data
	if playerDungeonTimers[userId] and playerDungeonTimers[userId].connection then
		playerDungeonTimers[userId].connection:Disconnect()
	end
	playerDungeonTimers[userId] = nil
	playerTimerLoaded[userId] = nil
	
	-- Remove IntValue
	removeTimerValue(userId)
	
	--print("[DungeonHandler] Cleaned up in-memory timer data for userId:", userId)
end)




-- Main script logic (was DungeonHandler.Init)
local _pendingRobuxDungeon = {}

DungeonEntryEvent.OnServerEvent:Connect(function(player, toMap, robux)
	local data = DungeonsData[toMap]
	if not data then return end

	if robux == true then
		-- Robux entry: store pending dungeon for this player
		_pendingRobuxDungeon[player.UserId] = toMap
		--print("[DungeonHandler] Registered pending Robux dungeon for", player.Name, toMap)
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
MarketplaceService.ProcessReceipt = function(receiptInfo)
	if receiptInfo.ProductId == DEV_PRODUCT_ID then
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if player then
			if _pendingRobuxDungeon and _pendingRobuxDungeon[player.UserId] then
				local toMap = _pendingRobuxDungeon[player.UserId]
				teleportPlayerToDungeon(player, toMap)
				_pendingRobuxDungeon[player.UserId] = nil
			else
				warn("[DungeonHandler] No pending Robux dungeon for player", player.Name)
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end


-- On player join, if they have an active dungeon timer, always teleport them into the correct dungeon

Players.PlayerAdded:Connect(function(player)
	local userId = player.UserId
	
	-- Mark as not loaded initially
	playerTimerLoaded[userId] = false
	
	-- Load dungeon timer from DataStore ONCE and cache it
	task.spawn(function()
		local timerData = UnifiedDataStoreManager.LoadDungeonTimer(userId)
		if timerData and timerData.toMap and timerData.endTime then
			local remaining = timerData.endTime - tick()
			
			-- Only use timer if it has at least 5 seconds remaining
			if remaining > 5 then
				-- Initialize player's timer data
				if not playerDungeonTimers[userId] then
					playerDungeonTimers[userId] = {}
				end
				playerDungeonTimers[userId].toMap = timerData.toMap
				playerDungeonTimers[userId].endTime = timerData.endTime
				
				-- Create IntValue for client tracking
				updateTimerValue(userId, timerData.endTime)
				
				--print("[DungeonHandler] Loaded timer for", player.Name, "userId:", userId, "map:", timerData.toMap, "remaining:", math.floor(remaining), "seconds")
			else
				-- Timer expired or about to expire, don't load it
				--print("[DungeonHandler] Timer expired for", player.Name, "userId:", userId, "remaining:", math.floor(remaining), "seconds - not loading")
			end
		else
			--print("[DungeonHandler] No valid timer loaded for", player.Name, "userId:", userId)
		end
		-- Mark timer as loaded for THIS player
		playerTimerLoaded[userId] = true
	end)
	
	player.CharacterAdded:Connect(function()
		-- Wait for THIS player's timer to finish loading before proceeding
		local maxWait = 50 -- 5 seconds max
		local waited = 0
		while not playerTimerLoaded[userId] and waited < maxWait do
			task.wait(0.1)
			waited = waited + 1
		end
		
		if not playerTimerLoaded[userId] then
			warn("[DungeonHandler] Timer loading timed out for", player.Name, "userId:", userId)
		end
		-- Delay to ensure stats are loaded
		task.wait(1)
		local stats = player:FindFirstChild("Stats")
		if not stats then return end
		local playerMapValue = stats:FindFirstChild("PlayerMap")
		local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
		local userId = player.UserId
		local timerData = getPlayerTimer(userId)
		
		if timerData and timerData.toMap and timerData.endTime and tick() < timerData.endTime then
			--print("[DungeonHandler] Player", player.Name, "userId:", userId, "has valid timer, teleporting to", timerData.toMap)
			-- Set PlayerMap to dungeon before teleporting to prevent race conditions
			if playerMapValue then
				playerMapValue.Value = timerData.toMap
			end
			teleportPlayerToDungeon(player, timerData.toMap)
			return -- Skip fallback logic
		end
		-- Fallback: if player is in a dungeon but timer is missing/expired, teleport out
		local currentMap = playerMapValue and playerMapValue.Value
		local ddata = currentMap and DungeonsData[currentMap]
		if ddata and ddata.TimeLimitMinutes and ddata.OutMap and ddata.OutSpawn then
			local outMap = ddata.OutMap or "Grimleaf 1"
			local outSpawn = ddata.OutSpawn or "DungeonExitSpawn"
			local mapFolder = workspace:FindFirstChild("Maps")
			local outMapObj = mapFolder and mapFolder:FindFirstChild(outMap)
			local outSpawnPart = outMapObj and outMapObj:FindFirstChild(outSpawn)
			if outSpawnPart then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					player:SetAttribute("IsPortalTeleporting", true)
					hrp.CFrame = outSpawnPart.CFrame + Vector3.new(0, 3, 0)
					task.delay(10, function()
						player:SetAttribute("IsPortalTeleporting", false)
					end)
				end
			end
			if playerMapValue then playerMapValue.Value = outMap end
			if lastSpawnValue then lastSpawnValue.Value = outSpawn end
			UnifiedDataStoreManager.SaveStats(player, false)
			-- Optionally notify client
			local TeleportGuiEvent = game:GetService("ReplicatedStorage"):FindFirstChild("TeleportGuiEvent")
			if TeleportGuiEvent then
				TeleportGuiEvent:FireClient(player, outMap)
			end
		end
	end)
end)
-- No return statement needed for ServerScript
