-- PortalHandler Module
local PortalHandler = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require UnifiedDataStoreManager for saving PlayerMap
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
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
		toMap = "Frozen Realm",
		spawnName = "NextSpawn" -- Adjust as needed for Grimleaf Exit
	},
	{
		fromMap = "Frozen Realm",
		portalPath = {"PrevPortal", "HitPart"},
		toMap = "Grimleaf Exit",
		spawnName = "PrevSpawn" -- Adjust as needed for Grimleaf Exit
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
				print("[PortalDebug] Connecting portal:", portal.fromMap, "->", portal.toMap, "| Part:", portalPart:GetFullName())
				portalTouchedConnections[portalPart] = portalPart.Touched:Connect(function(hit)
					onTouched(portal, portalPart, hit)
				end)
			else
				print("[PortalDebug] MISSING portal part for:", portal.fromMap, "->", portal.toMap, "| Path:", table.concat(portal.portalPath, "/"))
			end
		end
	end
end

function PortalHandler.Init()
	       local function onPortalTouched(portal, portalPart, hit)
		       local character = hit.Parent
		       local player = Players:GetPlayerFromCharacter(character)
		       if not player then
			       print("[PortalTeleportHandler] Not a player character")
			       return
		       end

		       -- Only trigger if player is alive
		       local humanoid = character:FindFirstChild("Humanoid")
		       if not humanoid or humanoid.Health <= 0 then
			       print("[PortalTeleportHandler] Player is dead, ignoring portal trigger for", player.Name)
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
			       print("[PortalTeleportHandler] Player", player.Name, "already used portal", portalKey, "- ignoring")
			       portalDebounce[userId][portalPart] = false
			       return
		       end

		       if playerPortalState[userId] == prevPortalKey then
			       print("[PortalTeleportHandler] Player", player.Name, "returned from", portal.toMap, "- allowing portal use again")
		       end

		       print("[PortalTeleportHandler] Portal touched by", hit and hit.Parent and hit.Parent.Name)
		       print("[PortalTeleportHandler] Player detected:", player.Name)

		       local mapFolder = Workspace:FindFirstChild("Maps")
		       local toMap = mapFolder and mapFolder:FindFirstChild(portal.toMap)
		       if toMap then
			       local spawnPart = toMap:FindFirstChild(portal.spawnName)
			       if spawnPart and spawnPart:IsA("BasePart") then
				       local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				       if humanoidRootPart then
					       print("[PortalTeleportHandler] Teleporting", player.Name, "to", portal.toMap)
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
						       print("[PortalTeleportHandler] Set PlayerMap=", portal.toMap, ", LastSpawnName=", portal.spawnName or "SpawnLocation")
					       -- Save stats with throttle (not forced immediate) to avoid DataStore queue backup
					       UnifiedDataStoreManager.SaveStats(player, false)
					       end
					       -- Set IsPortalTeleporting flag to prevent respawn logic from interfering
					       player:SetAttribute("IsPortalTeleporting", true)
					       print("[PortalTeleportHandler] Teleporting to part:", spawnPart.Name, "at position", tostring(spawnPart.Position))
					       humanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
					       playerPortalState[userId] = portalKey
					       task.delay(10, function()
						       player:SetAttribute("IsPortalTeleporting", false)
					       end)
				       else
					       print("[PortalTeleportHandler] No HumanoidRootPart found for", player.Name)
				       end
			       else
				       print("[PortalTeleportHandler] No spawn part found in", portal.toMap)
			       end
		       else
			       print("[PortalTeleportHandler] No toMap found:", portal.toMap)
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
			print("[PortalTeleportHandler] Map added, reconnecting portal events...")
			connectAllPortalTouched(onPortalTouched)
		end)
		mapFolder.ChildRemoved:Connect(function()
			print("[PortalTeleportHandler] Map removed, reconnecting portal events...")
			connectAllPortalTouched(onPortalTouched)
		end)
	end

	-- Listen for PlayerMap stat changes to reset portal state when player returns to previous map
	Players.PlayerAdded:Connect(function(player)
		-- Always start with a fresh debounce table for this player
		portalDebounce[player.UserId] = {}
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
	end)
end

return PortalHandler
