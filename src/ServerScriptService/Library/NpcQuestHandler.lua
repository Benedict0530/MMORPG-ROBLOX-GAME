-- NpcQuestHandler.lua
-- Handles quest NPCs with proximity prompts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NpcQuestHandler = {}
local QuestDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("QuestDataStore"))

-- Create or get RemoteEvent for quest NPC interactions
local function createQuestRemoteEvent()
	local existing = ReplicatedStorage:FindFirstChild("QuestNpcInteraction")
	if existing then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = "QuestNpcInteraction"
	event.Parent = ReplicatedStorage
	print("[NpcQuestHandler] Created RemoteEvent: QuestNpcInteraction")
	return event
end

-- Create or get RemoteEvent for quest acceptance
local function createQuestAcceptanceEvent()
	local existing = ReplicatedStorage:FindFirstChild("QuestAcceptance")
	if existing then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = "QuestAcceptance"
	event.Parent = ReplicatedStorage
	print("[NpcQuestHandler] Created RemoteEvent: QuestAcceptance")
	return event
end

local QuestNpcInteractionEvent = createQuestRemoteEvent()
local QuestAcceptanceEvent = createQuestAcceptanceEvent()

-- Function to get map name from NPC's location
local function getMapFromNpc(npc)
	local mapsFolder = Workspace:FindFirstChild("Maps")
	if not mapsFolder then return "Unknown" end
	
	local parent = npc.Parent
	while parent and parent ~= Workspace do
		-- Check if this is a direct child of Maps folder
		if parent.Parent == mapsFolder then
			return parent.Name
		end
		parent = parent.Parent
	end
	return "Unknown"
end

-- Function to setup quest NPC with proximity prompt
local function setupQuestNpc(npc)
	if npc:FindFirstChild("ProximityPrompt") then
		print("[NpcQuestHandler] ⚠️ QuestNpc already has ProximityPrompt:", npc.Name)
		return
	end
	
	local mapName = getMapFromNpc(npc)
	print("[NpcQuestHandler] Found QuestNpc:", npc.Name, "in map:", mapName)
	
	-- Debug: Show all children of QuestNpc
	print("[NpcQuestHandler] QuestNpc children:")
	for _, child in ipairs(npc:GetChildren()) do
		print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	end
	
	-- Find or create HumanoidRootPart to attach prompt
	local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
	if not rootPart then
		print("[NpcQuestHandler] ❌ QuestNpc missing HumanoidRootPart/Torso:", npc.Name)
		print("[NpcQuestHandler] Attaching ProximityPrompt to NPC root instead")
		rootPart = npc
	end
	
	-- Attach ProximityPrompt to visible part (Head works best)
	local promptPart = npc:FindFirstChild("LeftHand") or rootPart
	
	-- Create and configure ProximityPrompt
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Parent = promptPart
	proximityPrompt.ActionText = "Talk"
	proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	proximityPrompt.MaxActivationDistance = 10
	
	print("[NpcQuestHandler] ✅ ProximityPrompt created on:", promptPart.Name)
	
	-- Handle interaction
	proximityPrompt.Triggered:Connect(function(player)
		print("[NpcQuestHandler] ✅ Player", player.Name, "interacted with QuestNpc in map:", mapName)
		-- Fire RemoteEvent to client with quest NPC details
		QuestNpcInteractionEvent:FireClient(player, {
			npcName = npc.Name,
			npc = npc,
			mapName = mapName,
			position = npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChild("HumanoidRootPart").Position or Vector3.new(0, 0, 0),
			promptPartName = promptPart.Name
		})
	end)
	
	print("[NpcQuestHandler] ✅ Setup complete for QuestNpc in", mapName)
end

-- Function to scan all maps for QuestNpc
local function scanMapsForQuestNpcs()
	print("[NpcQuestHandler] Scanning maps for QuestNpcs...")
	local count = 0
	
	-- Look in Workspace/Maps folder
	local mapsFolder = Workspace:FindFirstChild("Maps")
	if not mapsFolder then
		print("[NpcQuestHandler] ⚠️ No 'Maps' folder found in Workspace")
		return
	end
	
	for _, map in ipairs(mapsFolder:GetChildren()) do
		if map:IsA("Folder") or map:IsA("Model") then
			local questNpc = map:FindFirstChild("QuestNpc")
			if questNpc and questNpc:IsA("Model") then
				setupQuestNpc(questNpc)
				count = count + 1
			end
		end
	end
	
	print("[NpcQuestHandler] Found and setup", count, "QuestNpcs")
end

-- Monitor for new maps being added
local mapsFolder = Workspace:WaitForChild("Maps")
mapsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Folder") or child:IsA("Model") then
		task.wait(0.5) -- Wait for map to fully load
		local questNpc = child:FindFirstChild("QuestNpc")
		if questNpc and questNpc:IsA("Model") then
			print("[NpcQuestHandler] New map detected:", child.Name)
			setupQuestNpc(questNpc)
		end
	end
end)

-- Initial scan
scanMapsForQuestNpcs()

-- Handle quest acceptance from client
QuestAcceptanceEvent.OnServerEvent:Connect(function(player, questId)
	print("[NpcQuestHandler] Player", player.Name, "accepted quest", questId)
	QuestDataStore.AcceptQuest(player, questId)
	-- Save quest data immediately
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.SaveQuestData(player, true)
end)

print("[NpcQuestHandler] NPC Quest Handler loaded successfully")

return NpcQuestHandler
