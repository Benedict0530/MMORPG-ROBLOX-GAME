-- PvpSkyHandler.client.lua
-- Handles PvpSky switching based on PlayerMap changes (client-side only)
local PvpSkyHandler = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Wait for Stats to load
local stats = player:FindFirstChild("Stats")
if not stats then
	-- Wait indefinitely for Stats to appear
	while true do
		stats = player:FindFirstChild("Stats")
		if stats then break end
		player.ChildAdded:Wait()
	end
end
if not stats then
    warn("[PvpSkyHandler] Stats folder not found after waiting!")
    return
end

local playerMapValue = stats:WaitForChild("PlayerMap")

local function updatePvpSky()
	local currentMap = playerMapValue.Value
	
	if string.find(currentMap, "PVP") then
		-- Clone PvpSky from ReplicatedStorage to Lighting
		local pvpSkyTemplate = ReplicatedStorage:FindFirstChild("PvpSky")
		if pvpSkyTemplate then
			-- Remove any existing custom skies first
			local existingPvpSky = Lighting:FindFirstChild("PvpSky")
			if existingPvpSky then
				existingPvpSky:Destroy()
			end
			local existingDungeonSky = Lighting:FindFirstChild("DungeonSky")
			if existingDungeonSky then
				existingDungeonSky:Destroy()
			end
			-- Clone and parent the new PvpSky
			local pvpSkyCopy = pvpSkyTemplate:Clone()
			pvpSkyCopy.Parent = Lighting
			--print("[PvpSkyHandler] PvpSky applied - entered PVP map: " .. currentMap)
		else
			warn("[PvpSkyHandler] PvpSky not found in ReplicatedStorage")
		end
	elseif string.find(currentMap, "Dungeon") then
		-- Clone DungeonSky from ReplicatedStorage to Lighting
		local dungeonSkyTemplate = ReplicatedStorage:FindFirstChild("DungeonSky")
		if dungeonSkyTemplate then
			-- Remove any existing custom skies first
			local existingPvpSky = Lighting:FindFirstChild("PvpSky")
			if existingPvpSky then
				existingPvpSky:Destroy()
			end
			local existingDungeonSky = Lighting:FindFirstChild("DungeonSky")
			if existingDungeonSky then
				existingDungeonSky:Destroy()
			end
			-- Clone and parent the new DungeonSky
			local dungeonSkyCopy = dungeonSkyTemplate:Clone()
			dungeonSkyCopy.Parent = Lighting
			--print("[PvpSkyHandler] DungeonSky applied - entered Dungeon map: " .. currentMap)
		else
			warn("[PvpSkyHandler] DungeonSky not found in ReplicatedStorage")
		end
	else
		-- Remove all custom skies when leaving special areas
		local existingPvpSky = Lighting:FindFirstChild("PvpSky")
		if existingPvpSky then
			existingPvpSky:Destroy()
			--print("[PvpSkyHandler] PvpSky removed - left PVP map")
		end
		local existingDungeonSky = Lighting:FindFirstChild("DungeonSky")
		if existingDungeonSky then
			existingDungeonSky:Destroy()
			--print("[PvpSkyHandler] DungeonSky removed - left Dungeon map")
		end
	end
end

-- Listen for PlayerMap changes
playerMapValue:GetPropertyChangedSignal("Value"):Connect(updatePvpSky)

-- Initial check in case player already in PVP Area
updatePvpSky()

return PvpSkyHandler
