-- NPCManager.lua
-- Handles NPC animations and idle behavior

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local NPCManager = {}

-- Animation settings
local IDLE_ANIMATION_ID = "rbxassetid://98470276839261"
local NPC_COLLISION_GROUP = "Players"

-- Track NPCs we've already set up
local setupNPCs = {}

-- Create collision group if it doesn't exist
local function initCollisionGroups()
	local success = pcall(function()
		PhysicsService:RegisterCollisionGroup(NPC_COLLISION_GROUP)
	end)
	if success then
		--print("[NPCManager] Collision group 'Players' created successfully")
	else
		--print("[NPCManager] Collision group 'Players' already exists")
	end
end

initCollisionGroups()

-- Function to check if a humanoid is an NPC (not a player, not an enemy)
local function isNPC(character)
	if not character:IsA("Model") then return false end
	if not character:FindFirstChild("Humanoid") then return false end
	
	-- Check if marked with IsNPC attribute
	if character:GetAttribute("IsNPC") then return true end
	
	-- Check if it's a player character
	if Players:GetPlayerFromCharacter(character) then return false end
	
	-- Check if it's an enemy (has "Enemy" in name or specific attributes)
	if string.find(string.lower(character.Name), "enemy") then return false end
	if character:GetAttribute("IsEnemy") then return false end
	
	-- Check if it's under Workspace/Enemies folder
	local fullPath = character:GetFullName()
	if string.find(string.lower(fullPath), "workspace.enemies") then return false end
	
	return true
end

-- Function to setup NPC animation
local function setupNPCAnimation(npc)
	if setupNPCs[npc] then return end
	
	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid then 
		--print("[NPCManager] ❌ NPC missing Humanoid:", npc.Name)
		return 
	end
	
	-- Mark this model as an NPC so other scripts know not to damage it
	npc:SetAttribute("IsNPC", true)
	
	-- Debug: Check humanoid state
	--print("[NPCManager] Humanoid Health:", humanoid.Health, "MaxHealth:", humanoid.MaxHealth)
	
	-- Ensure humanoid is alive (dead humanoids don't animate)
	if humanoid.Health <= 0 then
		--print("[NPCManager] ⚠️ Humanoid is dead! Restoring health for:", npc.Name)
		humanoid.MaxHealth = 100
		humanoid.Health = 100
	end
	
	-- Create animation
	local animation = Instance.new("Animation")
	animation.AnimationId = IDLE_ANIMATION_ID
	
	-- Load animation onto humanoid
	local animationTrack
	local success = pcall(function()
		animationTrack = humanoid:LoadAnimation(animation)
	end)
	
	if not success or not animationTrack then
		--print("[NPCManager] ❌ Failed to load animation for:", npc.Name)
		return
	end
	
	-- Debug: Check animation track
	--print("[NPCManager] Animation loaded. Playing animation...")
	animationTrack.Looped = true
	
	local playSuccess = pcall(function()
		animationTrack:Play()
	end)
	
	if not playSuccess then
		--print("[NPCManager] ❌ Failed to play animation for:", npc.Name)
		return
	end
	
	--print("[NPCManager] ✅ Animation playing. State:", animationTrack.TimePosition, "Speed:", animationTrack.Speed)
	
	-- Set collision group for ALL NPC parts (recursive - every descendant)
	local function setCollisionForParts(model)
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function()
					part.CollisionGroup = NPC_COLLISION_GROUP
				end)
			end
		end
	end
	
	setCollisionForParts(npc)
	
	--print("[NPCManager] Setup NPC:", npc.Name, "with idle animation. Parts added to collision group.")
	setupNPCs[npc] = {animation = animation, track = animationTrack, humanoid = humanoid}
end

-- Find all existing NPCs in workspace (recursive - checks all descendants at any depth)
local function findAllNPCs()
	--print("[NPCManager] Scanning workspace for existing NPCs...")
	local count = 0
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and isNPC(descendant) then
			setupNPCAnimation(descendant)
			count = count + 1
		end
	end
	--print("[NPCManager] Found and setup", count, "NPCs")
end

-- Monitor for new models being added to workspace
Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and isNPC(descendant) then
		--print("[NPCManager] New NPC detected:", descendant.Name, "at", descendant:GetFullName())
		task.wait(0.1) -- Wait for model to fully load
		setupNPCAnimation(descendant)
	end
end)

-- Monitor for NPC removal
Workspace.DescendantRemoving:Connect(function(descendant)
	if setupNPCs[descendant] then
		if setupNPCs[descendant].track then
			setupNPCs[descendant].track:Stop()
		end
		--print("[NPCManager] NPC removed:", descendant.Name)
		setupNPCs[descendant] = nil
	end
end)

-- Initial setup for existing NPCs
findAllNPCs()

--print("[NPCManager] NPC Manager loaded successfully")

return NPCManager
