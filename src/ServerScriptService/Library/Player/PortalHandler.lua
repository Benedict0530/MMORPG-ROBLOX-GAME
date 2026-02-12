-- === ANTI-TELEPORT HACK SYSTEM ===
local MAX_RUN_SPEED = 40 -- Maximum legitimate run speed (studs/sec)
local MAX_DASH_SPEED = 150 -- Maximum legitimate dash speed (studs/sec)
local MAX_ALLOWED_SPEED = MAX_DASH_SPEED * 1.2 -- Allow some margin for lag
local POSITION_CHECK_INTERVAL = 0.2 -- seconds
local lastPositions = {} -- [userId] = {pos = Vector3, t = time, isDashing = false, lastDash = 0}
local respawnGracePeriods = {} -- [userId] = timestamp until which anti-tp checks are skipped
local joinedPlayers = {} -- [userId] = true if player has just joined (for first join grace)

-- Listen for dash event to mark dashing state
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PerformDashEvent = ReplicatedStorage:FindFirstChild("PerformDash")
if PerformDashEvent then
	PerformDashEvent.OnServerEvent:Connect(function(player)
		local userId = player.UserId
		if not lastPositions[userId] then lastPositions[userId] = {} end
		lastPositions[userId].isDashing = true
		lastPositions[userId].lastDash = tick()
		-- Remove dash state after dash duration
		task.delay(0.4, function()
			if lastPositions[userId] then lastPositions[userId].isDashing = false end
		end)
	end)
end

-- Mark portal teleporting as safe
local function isPortalTeleporting(player)
	return player:GetAttribute("IsPortalTeleporting") == true
end

-- Main anti-tp check loop
task.spawn(function()
	while true do
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			-- On first join, set a longer grace period for anti-tp
			if not joinedPlayers[player.UserId] then
				respawnGracePeriods[player.UserId] = tick() + 5 -- 5 seconds grace on first join
				joinedPlayers[player.UserId] = true
			end
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
            -- Exception: If player is dead, skip anti-teleport check (parts can scatter)
            local humanoid = character and character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health <= 0 then
                lastPositions[player.UserId] = nil -- Optionally clear last position to avoid false positives on respawn
				-- Set a grace period for anti-tp after respawn
				respawnGracePeriods[player.UserId] = tick() + 2.5 -- 2.5 seconds grace after death
                continue
            end
			-- If player just respawned (CurrentHealth just restored), skip anti-tp for a short grace period
			local graceUntil = respawnGracePeriods[player.UserId]
			if graceUntil and tick() < graceUntil then
				continue
			end
			if hrp then
				local userId = player.UserId
				local now = tick()
				local pos = hrp.Position
				local info = lastPositions[userId] or {}
				if info.pos and info.t then
					local dt = now - info.t
					if dt > 0 then
						local dist = (pos - info.pos).Magnitude
						local speed = dist / dt
						local isDashing = info.isDashing or false
						local lastDash = info.lastDash or 0
						-- Allow if portal teleporting, or dashing, or just respawned
						local recentlyDashed = (now - lastDash <= 1.2)
						local thrownByDash = false
						if hrp.Velocity then
							-- If vertical velocity is very high (positive or negative), likely thrown by dash collision
							if math.abs(hrp.Velocity.Y) > 80 then
								thrownByDash = true
							end
						end
						if not isPortalTeleporting(player) and not isDashing and not recentlyDashed then
							-- Ignore anti-tp if player is falling fast or thrown by dash collision
							local falling = false
							if hrp.Velocity and hrp.Velocity.Y < -50 then
								falling = true
							end
							if speed > MAX_ALLOWED_SPEED and not falling and not thrownByDash then
								-- Check if player initialization is done (Stats exists and is ready)
								local stats = player:FindFirstChild("Stats")
								local isReady = false
								if stats then
									-- Check for PlayerInitSignals/Player_<userId>/_Fired == true
									local ReplicatedStorage = game:GetService("ReplicatedStorage")
									local playerSignalsFolder = ReplicatedStorage:FindFirstChild("PlayerInitSignals")
									if playerSignalsFolder then
										local signal = playerSignalsFolder:FindFirstChild("Player_" .. tostring(userId))
										if signal then
											local fired = signal:FindFirstChild("_Fired")
											if fired and fired.Value == true then
												isReady = true
											end
										end
									end
								end
								if not isReady then
									-- Player is still initializing, skip anti-tp kick
									continue
								end
								-- Also skip anti-tp kick if grace period is active (should be redundant, but extra safe)
								local graceUntil2 = respawnGracePeriods[userId]
								if graceUntil2 and now < graceUntil2 then
									continue
								end
								warn("[AntiTPHack] Player " .. player.Name .. " detected for teleport hacking! Speed: " .. tostring(speed))
								-- Try to teleport player back to last valid spawn before kicking
								local mapName, spawnName
								if stats then
									local playerMapValue = stats:FindFirstChild("PlayerMap")
									local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
									if playerMapValue and lastSpawnValue then
										mapName = playerMapValue.Value
										spawnName = lastSpawnValue.Value
									end
								end
								local mapFolder = workspace:FindFirstChild("Maps")
								if mapFolder and mapName and spawnName then
									local map = mapFolder:FindFirstChild(mapName)
									if map then
										local spawnPart = map:FindFirstChild(spawnName)
										if spawnPart and character and hrp then
											hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
											warn("[AntiTPHack] Player " .. player.Name .. " teleported back to spawn " .. spawnName .. " in map " .. mapName)
										end
									end
								end
								task.wait(0.5)
								player:Kick("Anti-teleport hack detected.")
							end
						end
					end
				end
				lastPositions[userId] = lastPositions[userId] or {}
				lastPositions[userId].pos = pos
				lastPositions[userId].t = now
			end
		end
		task.wait(POSITION_CHECK_INTERVAL)
	end
end)
-- PortalHandler Module
local PortalHandler = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require UnifiedDataStoreManager for saving PlayerMap
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- Create or get TeleportGuiEvent for triggering client-side UI
local TeleportGuiEvent = ReplicatedStorage:FindFirstChild("TeleportGuiEvent")
if not TeleportGuiEvent then
	TeleportGuiEvent = Instance.new("RemoteEvent")
	TeleportGuiEvent.Name = "TeleportGuiEvent"
	TeleportGuiEvent.Parent = ReplicatedStorage
end
-- Table to track which portal a player last used (by UserId)
local playerPortalState = {} -- [userId] = portalKey
-- Table to debounce portal triggers per player per portal part
local portalDebounce = {} -- [userId][portalPart] = true/false

-- Map/portal configuration
local portals = {
	{
		fromMap = "Grimleaf Entrance",
		portalPath = {"NextPortal", "HitPart"},
		toMap = "Grimleaf 1",
		spawnName = "NextSpawn" -- Use NextSpawn in Grimleaf 1
	},
	{
		fromMap = "Grimleaf 1",
		portalPath = {"PrevPortal", "HitPart"},
		toMap = "Grimleaf Entrance",
		spawnName = "PrevSpawn" -- Use PrevSpawn in Grimleaf Entrance
	},
	{
		fromMap = "Grimleaf 1",
		portalPath = {"NextPortal", "HitPart"},
		toMap = "Grimleaf Exit",
		spawnName = "NextSpawn" -- Adjust as needed for Grimleaf Exit
	},
	{
		fromMap = "Grimleaf Exit",
		portalPath = {"PrevPortal", "HitPart"},
		toMap = "Grimleaf 1",
		spawnName = "PrevSpawn" -- Adjust as needed for Grimleaf Exit
	},
	{
		fromMap = "Grimleaf Exit",
		portalPath = {"NextPortal", "HitPart"},
		toMap = "Frozen Realm Entrance",
		spawnName = "NextSpawn" -- Adjust as needed for Grimleaf Exit
	},
	{
		fromMap = "Frozen Realm Entrance",
		portalPath = {"PrevPortal", "HitPart"},
		toMap = "Grimleaf Exit",
		spawnName = "PrevSpawn" -- Adjust as needed for Grimleaf Exit
	},
	-- {
	-- 	fromMap = "Frozen Realm Entrance",
	-- 	portalPath = {"NextPortal", "HitPart"},
	-- 	toMap = "Frozen Realm 1",
	-- 	spawnName = "NextSpawn" -- Adjust as needed for Frozen Realm Entrance
	-- },
	{
		fromMap = "Frozen Realm 1",
		portalPath = {"PrevPortal", "HitPart"},
		toMap = "Frozen Realm Entrance",
		spawnName = "PrevSpawn" -- Adjust as needed for Frozen Realm Entrance
	},
	{
		fromMap = "Grimleaf 1",
		portalPath = {"PVPPortal", "HitPart"},
		toMap = "PVP Area",
		spawnName = "NextSpawn" -- Adjust as needed for Grimleaf Exit
	},
	{
		fromMap = "PVP Area",
		portalPath = {"ExitPortal", "HitPart"},
		toMap = "Grimleaf 1",
		spawnName = "PvpExitSpawn" -- Adjust as needed for PVP Area
	},
	{
		fromMap = "Grimleaf 1",
		portalPath = {"Dungeon Portal", "HitPart"},
		toMap = "Grimleaf 1 Dungeon",
		spawnName = "DungeonSpawn" -- Adjust as needed for Dungeon Map
	}
	-- Add more portals here as needed
}

-- Allow external reset of player portal state
function PortalHandler.ResetPlayerPortalState(userId)
	playerPortalState[userId] = nil
end

local function getDescendantByPath(parent, path)
	local obj = parent
	for _, name in ipairs(path) do
		obj = obj:FindFirstChild(name)
		if not obj then return nil end
	end
	return obj
end

-- Track all portal Touched connections for reset
local portalTouchedConnections = {} -- [portalPart] = connection

local function disconnectAllPortalTouched()
	for portalPart, conn in pairs(portalTouchedConnections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
		portalTouchedConnections[portalPart] = nil
	end
end

local function connectAllPortalTouched(onTouched)
	disconnectAllPortalTouched()
	local mapFolder = Workspace:FindFirstChild("Maps")
	if not mapFolder then return end
	for _, portal in ipairs(portals) do
		local fromMap = mapFolder:FindFirstChild(portal.fromMap)
		if fromMap then
			local portalPart = getDescendantByPath(fromMap, portal.portalPath)
			if portalPart and portalPart:IsA("BasePart") then
				--print("[PortalDebug] Connecting portal:", portal.fromMap, "->", portal.toMap, "| Part:", portalPart:GetFullName())
				portalTouchedConnections[portalPart] = portalPart.Touched:Connect(function(hit)
					onTouched(portal, portalPart, hit)
				end)
			else
				--print("[PortalDebug] MISSING portal part for:", portal.fromMap, "->", portal.toMap, "| Path:", table.concat(portal.portalPath, "/"))
			end
		end
	end
end

function PortalHandler.Init()
			   local function onPortalTouched(portal, portalPart, hit)
				   local character = hit.Parent
				   local player = Players:GetPlayerFromCharacter(character)
				   if not player then
					   --print("[PortalTeleportHandler] Not a player character")
					   return
				   end

				   -- Only trigger if player is alive
				   local humanoid = character:FindFirstChild("Humanoid")
				   if not humanoid or humanoid.Health <= 0 then
					   --print("[PortalTeleportHandler] Player is dead, ignoring portal trigger for", player.Name)
					   return
				   end

				   local userId = player.UserId
				   portalDebounce[userId] = portalDebounce[userId] or {}
				   -- Unique portal key for this portal
				   local portalKey = portal.fromMap .. "->" .. portal.toMap
				   local prevPortalKey = portal.toMap .. "->" .. portal.fromMap

				   -- Debounce: Only allow trigger if not already inside this portal
				   if portalDebounce[userId][portalPart] then
					   return
				   end
				   portalDebounce[userId][portalPart] = true

				   -- Only allow if not already at this portal, or if just came back from the other map
				   if playerPortalState[userId] == portalKey then
					   --print("[PortalTeleportHandler] Player", player.Name, "already used portal", portalKey, "- ignoring")
					   portalDebounce[userId][portalPart] = false
					   return
				   end

				   if playerPortalState[userId] == prevPortalKey then
					   --print("[PortalTeleportHandler] Player", player.Name, "returned from", portal.toMap, "- allowing portal use again")
				   end

				   --print("[PortalTeleportHandler] Portal touched by", hit and hit.Parent and hit.Parent.Name)
				   --print("[PortalTeleportHandler] Player detected:", player.Name)

				   -- If portal name contains 'Dungeon', do not teleport, just fire client to show DungeonUI
				   if string.find(portal.toMap, "Dungeon") or string.find(portal.fromMap, "Dungeon") then
					   --print("[PortalTeleportHandler] Dungeon portal detected, showing DungeonUI instead of teleporting.")
					   -- Fire a dedicated event to show DungeonUI on client, passing toMap as parameter
					   local ReplicatedStorage = game:GetService("ReplicatedStorage")
					   local DungeonUIEvent = ReplicatedStorage:FindFirstChild("DungeonUIEvent")
					   if not DungeonUIEvent then
						   DungeonUIEvent = Instance.new("RemoteEvent")
						   DungeonUIEvent.Name = "DungeonUIEvent"
						   DungeonUIEvent.Parent = ReplicatedStorage
					   end
					   DungeonUIEvent:FireClient(player, portal.toMap)
					   -- Reset debounce after short delay
					   task.delay(2, function()
						   portalDebounce[userId][portalPart] = false
					   end)
					   return
				   end

				   local mapFolder = Workspace:FindFirstChild("Maps")
				   local toMap = mapFolder and mapFolder:FindFirstChild(portal.toMap)
				   if toMap then
					   local spawnPart = toMap:FindFirstChild(portal.spawnName)
						   if spawnPart and spawnPart:IsA("BasePart") then
							   local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
							   if humanoidRootPart then
								   --print("[PortalTeleportHandler] Teleporting", player.Name, "to", portal.toMap)
                                   
								   -- Fire TeleportGuiEvent to show UI on client immediately
								   TeleportGuiEvent:FireClient(player, portal.toMap)
                                   
								   local stats = player:FindFirstChild("Stats")
								   if stats then
									   local playerMapValue = stats:FindFirstChild("PlayerMap")
									   local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
									   if playerMapValue then
										   playerMapValue.Value = portal.toMap
									   end
									   if lastSpawnValue then
										   lastSpawnValue.Value = portal.spawnName or "SpawnLocation"
									   end
									   --print("[PortalTeleportHandler] Set PlayerMap=", portal.toMap, ", LastSpawnName=", portal.spawnName or "SpawnLocation")
								   -- Save stats with throttle (not forced immediate) to avoid DataStore queue backup
								   UnifiedDataStoreManager.SaveStats(player, false)
								   end
								   -- Set IsPortalTeleporting flag to prevent respawn logic from interfering
								   player:SetAttribute("IsPortalTeleporting", true)
								   --print("[PortalTeleportHandler] Teleporting to part:", spawnPart.Name, "at position", tostring(spawnPart.Position))
								   humanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
								   playerPortalState[userId] = portalKey
								   task.delay(10, function()
									   player:SetAttribute("IsPortalTeleporting", false)
								   end)
							   else
								   --print("[PortalTeleportHandler] No HumanoidRootPart found for", player.Name)
							   end
					   else
						   --print("[PortalTeleportHandler] No spawn part found in", portal.toMap)
					   end
				   else
					   --print("[PortalTeleportHandler] No toMap found:", portal.toMap)
				   end

				   task.delay(2, function()
					   portalDebounce[userId][portalPart] = false
				   end)
			   end


	-- Connect all portal Touched events
	connectAllPortalTouched(onPortalTouched)

	-- Listen for changes to the Maps folder and reconnect portal events if maps are added/removed
	local mapFolder = Workspace:FindFirstChild("Maps")
	if mapFolder then
		mapFolder.ChildAdded:Connect(function()
			--print("[PortalTeleportHandler] Map added, reconnecting portal events...")
			connectAllPortalTouched(onPortalTouched)
		end)
		mapFolder.ChildRemoved:Connect(function()
			--print("[PortalTeleportHandler] Map removed, reconnecting portal events...")
			connectAllPortalTouched(onPortalTouched)
		end)
	end

	-- Export SetupPlayer function for Init.server.lua to call
	function PortalHandler.SetupPlayer(player)
		-- Always start with a fresh debounce table for this player
		portalDebounce[player.UserId] = {}
		-- On first Stats folder creation, reset anti-tp grace period (for first spawn/teleport)
		player.ChildAdded:Connect(function(child)
			if child.Name == "Stats" then
				respawnGracePeriods[player.UserId] = tick() + 3 -- 3 seconds grace after stats created
			end
		end)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			local stats = player:FindFirstChild("Stats")
			if stats then
				local playerMapValue = stats:FindFirstChild("PlayerMap")
				if playerMapValue then
					playerMapValue:GetPropertyChangedSignal("Value"):Connect(function()
						-- When PlayerMap changes, clear portal state and debounce for this player (do NOT touch LastSpawnName)
						playerPortalState[player.UserId] = nil
						portalDebounce[player.UserId] = {}
						-- Reconnect all portal Touched events to ensure they're always fresh
						connectAllPortalTouched(onPortalTouched)

						-- Remove PVP health bar if not in PVP Area
						if playerMapValue.Value ~= "PVP Area" then
							local char = player.Character
							if char then
								local head = char:FindFirstChild("Head")
								if head then
									local bar = head:FindFirstChild("PVPHealthBar")
									if bar then bar:Destroy() end
								end
							end
						end
					end)
				end
			end
		end)
	end
	
	-- PlayerAdded handler moved to Init.server.lua for centralized initialization
end

return PortalHandler
