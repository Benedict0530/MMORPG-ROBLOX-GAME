-- SafeZoneHandler.lua
-- Handles SafeZone detection and sets player SafeZone attribute

local Players = game:GetService("Players")

local SafeZoneHandler = {}

-- Table to track which players are in which zones
local playersInZones = {}

-- Get all SafeZone parts from workspace Maps folder
local function getAllSafeZones()
	local safeZones = {}
	local mapsFolder = workspace:FindFirstChild("Maps")
	
	if not mapsFolder then
		warn("[SafeZoneHandler] Maps folder not found in workspace")
		return safeZones
	end
	
	-- Recursively find all parts named "SafeZone"
	local function findSafeZoneParts(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("BasePart") and child.Name == "SafeZone" then
				table.insert(safeZones, child)
			end
			-- Recursively search in children
			if child:IsA("Folder") or child:IsA("Model") then
				findSafeZoneParts(child)
			end
		end
	end
	
	findSafeZoneParts(mapsFolder)
	
	return safeZones
end

-- Check if a position is inside a SafeZone part
local function isPositionInSafeZone(position, safeZonePart)
	if not safeZonePart or not safeZonePart:IsA("BasePart") then
		return false
	end
	
	-- Get the part's position, size, and CFrame
	local partCFrame = safeZonePart.CFrame
	local partSize = safeZonePart.Size
	
	-- Transform the position to the part's local space
	local relativePosition = partCFrame:PointToObjectSpace(position)
	
	-- Check if the position is within the bounds of the part
	local halfSize = partSize / 2
	return math.abs(relativePosition.X) <= halfSize.X and
	       math.abs(relativePosition.Y) <= halfSize.Y and
	       math.abs(relativePosition.Z) <= halfSize.Z
end

-- Update player's SafeZone attribute based on their position
local function updatePlayerSafeZoneStatus(player)
	if not player.Character then return end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local position = humanoidRootPart.Position
	local safeZones = getAllSafeZones()
	local isInSafeZone = false
	
	-- Check if player is in any SafeZone
	for _, safeZonePart in ipairs(safeZones) do
		if isPositionInSafeZone(position, safeZonePart) then
			isInSafeZone = true
			break
		end
	end
	
	-- Set or update the SafeZone attribute on the player
	player:SetAttribute("SafeZone", isInSafeZone)
	
	-- Track status change for debugging
	local playerId = player.UserId
	local wasInZone = playersInZones[playerId]
	
	if isInSafeZone and not wasInZone then
		print("[SafeZoneHandler] " .. player.Name .. " entered SafeZone")
		playersInZones[playerId] = true
	elseif not isInSafeZone and wasInZone then
		print("[SafeZoneHandler] " .. player.Name .. " left SafeZone")
		playersInZones[playerId] = false
	end
end

-- Setup continuous monitoring for a player
local function setupPlayerMonitoring(player)
	-- Initial setup
	playersInZones[player.UserId] = false
	player:SetAttribute("SafeZone", false)
	
	-- Wait for character
	local function onCharacterAdded(character)
		-- Wait for HumanoidRootPart
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoidRootPart then return end
		
		-- Reset SafeZone status on respawn
		player:SetAttribute("SafeZone", false)
		playersInZones[player.UserId] = false
		
		-- Monitor position changes using Heartbeat (more frequent updates)
		local lastUpdateTime = 0
		local UPDATE_INTERVAL = 0.5 -- Check every 0.5 seconds
		
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			local currentTime = tick()
			if currentTime - lastUpdateTime >= UPDATE_INTERVAL then
				lastUpdateTime = currentTime
				
				-- Check if player and character still exist
				if not player.Parent or not character.Parent then
					connection:Disconnect()
					return
				end
				
				updatePlayerSafeZoneStatus(player)
			end
		end)
		
		-- Clean up connection when character is removed
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				connection:Disconnect()
			end
		end)
	end
	
	-- Setup for current character
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	-- Setup for future characters (respawns)
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- Initialize the SafeZone system
function SafeZoneHandler.Initialize()
	print("[SafeZoneHandler] Initializing SafeZone system...")
	
	-- Check if Maps folder exists
	local mapsFolder = workspace:FindFirstChild("Maps")
	if not mapsFolder then
		warn("[SafeZoneHandler] Maps folder not found in workspace. SafeZone system will not work properly.")
		return
	end
	
	-- Get all SafeZones
	local safeZones = getAllSafeZones()
	print("[SafeZoneHandler] Found " .. #safeZones .. " SafeZone parts")
	
	-- Setup monitoring for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayerMonitoring(player)
	end
	
	-- Setup monitoring for new players
	Players.PlayerAdded:Connect(function(player)
		setupPlayerMonitoring(player)
	end)
	
	-- Cleanup when players leave
	Players.PlayerRemoving:Connect(function(player)
		playersInZones[player.UserId] = nil
	end)
	
	print("[SafeZoneHandler] SafeZone system initialized successfully")
end

-- Public function to check if player is in SafeZone (alternative to checking attribute)
function SafeZoneHandler.IsPlayerInSafeZone(player)
	if not player then return false end
	return player:GetAttribute("SafeZone") == true
end

return SafeZoneHandler
