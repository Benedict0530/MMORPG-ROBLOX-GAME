-- OrbSpiritHandler.lua
-- Handles player spirit orb management, cloning, and attachment
--
-- ============================================================================
-- CRITICAL: ORB BUFF ARCHITECTURE
-- ============================================================================
-- **ORBS DO NOT ADD TO STATS - ONLY TO DAMAGE CALCULATIONS**
-- 
-- The stat system is completely separate from orb effects:
-- 1. Player stats (Attack, Defence, MaxHealth, etc.) = BASE VALUES ONLY
--    - NEVER modified by orb multipliers under ANY circumstance
--    - NEVER saved with multipliers applied
--    - Updated ONLY by: stat allocation, level-up, admin commands
--    - Saved to DataStore as pure base values
--
-- 2. Orb multipliers are stored SEPARATELY in playerOrbMultipliers table
--    - Retrieved ONLY when calculating damage in DamageManager
--    - Applied ONLY to Attack stat during damage formula calculation
--    - Example: Base Attack 100 with 1.5x orb multiplier
--      → For damage calc: 100 * 1.5 = 150 (temporary, calculation only)
--      → Player.Stats.Attack always stays 100 (base value)
--
-- 3. UI displays pure base stats (no orb additions)
--    - Shows actual stat values from player.Stats folder
--    - Multipliers displayed separately as "bonus multiplier" info
--    - No fake stat values ever shown
--
-- WHY THIS DESIGN:
-- - Prevents stat value corruption from ever occurring
-- - Keeps all calculations simple and predictable
-- - Clean separation: progression = stats, damage scaling = multipliers
-- - No reverse-calculation logic needed
--
-- ============================================================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local OrbSpiritHandler = {}

local playerBaseStats = {}
-- Active particle effects per player (to prevent overlapping effects)
local activeParticleEffects = {}

-- Track last known character per player for respawn detection
local lastKnownCharacters = {}

-- Track base stats (without orb buffs) per player
-- These are the ACTUAL stat values shown to players and saved to DataStore
-- NEVER modified by orb multipliers - only by stat allocation, level-up, admin commands

-- Track orb multipliers per player (for DamageManager to use, NOT applied to stats)
-- These are ONLY used in DamageManager.calculateDamage() when computing damage
-- Stats themselves NEVER get multiplied - they remain base values always
local playerOrbMultipliers = {}

-- Track original stat values BEFORE orb bonuses are applied (for session-based buffs)
-- These allow us to restore base values when unequipping orbs or reloading
-- [REMOVED] playerOrbBonusedStats and all orb stat bonus tracking

-- Track if orb has been equipped for a player (for initial UI display timing)
local playerOrbEquipped = {}

-- Track if we're currently equipping an orb (to prevent duplicate calls)
local isEquippingOrb = {}

-- Track when we're changing stats from admin command (to prevent listener recursion)
local isChangingStatsFromAdmin = {}

-- Orb type color table (RGB values for particle effects)
local orbTypeColors = {
	Fire = Color3.fromRGB(255, 102, 51),
	Wind = Color3.fromRGB(0, 85, 0),
	Water = Color3.fromRGB(0, 0, 255),
	Earth = Color3.fromRGB(83, 28, 0),
	Shadow = Color3.fromRGB(170, 0, 255),
	Dark = Color3.fromRGB(0, 0, 0),
	Light = Color3.fromRGB(255, 255, 255),
	Radiant = Color3.fromRGB(255, 250, 110),
	Normal = Color3.fromRGB(255, 255, 255),
}

-- Orb type transparency table for slash particles (0 = opaque, 1 = invisible)
local orbTypeTransparency = {
	Fire = 0,
	Wind = 0,
	Water = 0,
	Earth = 0,
	Shadow = 0,
	Dark = 0,
	Light = 0,
	Radiant = 0,
	Normal = 0.97,
}

-- Public function to unequip orb: clears EquippedOrb slot and removes all orb visuals/effects
function OrbSpiritHandler.UnequipOrb(player)
       print("[OrbSpiritHandler] UnequipOrb called for player:", player and player.Name or tostring(player))
       if not player then return false end
       local stats = player:FindFirstChild("Stats")
       if not stats then return false end
       -- Remove orb visuals and effects BEFORE clearing EquippedOrb slot (so orbName is available)
       OrbSpiritHandler.UnequipSpiritOrb(player)
       -- Now clear EquippedOrb slot
       local equippedOrb = stats:FindFirstChild("EquippedOrb")
       if equippedOrb then
	       local nameValue = equippedOrb:FindFirstChild("name")
	       local idValue = equippedOrb:FindFirstChild("id")
	       if nameValue then nameValue.Value = "" end
	       if idValue then idValue.Value = "" end
       end
       return true
end

-- Extract the orb type from orb name (e.g., "Dark Orb" -> "Dark")
local function getOrbType(orbName)
	return orbName:match("^(.+)%s+Orb$") or orbName
end

-- Get OrbData module
local OrbData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrbData"))

-- Clear orb multipliers when orb is unequipped
local function clearOrbMultipliers(player)
	local userId = player.UserId
	if playerOrbMultipliers[userId] then
		playerOrbMultipliers[userId] = nil
		playerOrbEquipped[userId] = nil
		--print("[OrbSpiritHandler] Cleared orb multipliers for " .. player.Name)
	end
end

-- [REMOVED] OrbSpiritHandler.UpdateOrbBonusedStats


-- Forcefully reset Stats folder from cached base stats (for robust DataStore saving)

-- These add to the stat values temporarily and are NOT saved to DataStore
-- [REMOVED] applyOrbStatBonuses


-- [REMOVED] removeOrbStatBonuses

-- [REMOVED] OrbSpiritHandler.RestoreBaseStatsBeforeCache

-- Store orb multipliers (NO stat modification - only for DamageManager use)
-- CRITICAL: These multipliers are NEVER applied to actual stat values
-- They are ONLY used in DamageManager.calculateDamage() to boost damage calculations
-- Stats in player.Stats folder always remain base values (not affected by orbs)
local function storeOrbMultipliers(player, orbName)
	if not orbName or orbName == "" then return end
	
	local userId = player.UserId
	local orbData = OrbData.GetOrbData(orbName)
	if not orbData or not orbData.stats then
		warn("[OrbSpiritHandler] Orb data not found for: " .. orbName)
		return
	end
	
	-- Store multipliers (they will ONLY be used in DamageManager for damage calculations)
	-- These are NOT applied to stats - stats remain base values
	playerOrbMultipliers[userId] = orbData.stats
	playerOrbEquipped[userId] = true -- Mark orb as equipped
	--print("[OrbSpiritHandler] Stored multipliers for orb '" .. orbName .. "': Attack=" .. tostring(orbData.stats.Attack) .. " (only used in DamageManager for damage calc)")
end

-- Update base stats when player's stats change (after level up, stat allocation, etc)
-- This ONLY captures the actual stat values - never applies any multipliers
-- Called by: LevelSystem (on level up), StatsManager (on stat allocation), AdminCommandsHandler (on admin changes)
function OrbSpiritHandler.UpdateBaseStats(player)
	if not player then return end
	
	local userId = player.UserId
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	
	   -- Remove orb bonuses before capturing base stats
	   local orbWasActive = false
	   -- [REMOVED] orbWasActive and removeOrbStatBonuses
	   -- Now capture current stats as new base values (guaranteed to be base-only)
	   if not playerBaseStats[userId] then
		   playerBaseStats[userId] = {}
	   end
	   playerBaseStats[userId].Attack = stats:FindFirstChild("Attack") and stats:FindFirstChild("Attack").Value or 1
	   playerBaseStats[userId].Defence = stats:FindFirstChild("Defence") and stats:FindFirstChild("Defence").Value or 1
	   playerBaseStats[userId].MaxHealth = stats:FindFirstChild("MaxHealth") and stats:FindFirstChild("MaxHealth").Value or 10
	   playerBaseStats[userId].MaxMana = stats:FindFirstChild("MaxMana") and stats:FindFirstChild("MaxMana").Value or 5
	   playerBaseStats[userId].Dexterity = stats:FindFirstChild("Dexterity") and stats:FindFirstChild("Dexterity").Value or 1
	   --print("[OrbSpiritHandler] ✓ Updated base stats for " .. player.Name .. " - Attack=" .. tostring(playerBaseStats[userId].Attack) .. ", Defence=" .. tostring(playerBaseStats[userId].Defence))
	   -- Reapply orb bonuses if they were active
	   -- [REMOVED] reapplying orb stat bonuses
end

-- Clone and parent spirit orb to player based on their SpiritOrb stat

-- Remove spirit orb from player
function OrbSpiritHandler.UnequipSpiritOrb(player)
	if not player or not player.Character then return false end

	local stats = player:FindFirstChild("Stats")
	if not stats then return false end

	-- Get orb name from EquippedOrb folder (new inventory system)
	local orbName = ""
	local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
	if equippedOrbFolder then
		local nameValue = equippedOrbFolder:FindFirstChild("name")
		if nameValue then
			orbName = nameValue.Value
		end
	end
	
	-- Fallback to old SpiritOrb stat if EquippedOrb is not set
	if orbName == "" then
		local spiritOrbStat = stats:FindFirstChild("SpiritOrb")
		if spiritOrbStat then
			orbName = spiritOrbStat.Value
		end
	end

	-- Remove all orb-related Accessories, Folders, and Models from the character and all parts
	local character = player.Character
	if character then
		local function getFullPath(obj)
			local path = obj.Name
			local parent = obj.Parent
			while parent and parent ~= workspace and parent ~= nil do
				path = parent.Name .. "." .. path
				parent = parent.Parent
			end
			return path
		end
		print("[OrbSpiritHandler] --- ORB VFX PART DEBUG (ON UNEQUIP) ---")
		-- Remove all Accessories with 'Orb' in the name
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") and child.Name:lower():find("orb") then
				print("[OrbSpiritHandler] Removing Accessory '", child.Name, "' from character:", getFullPath(child))
				child:Destroy()
			end
		end
		-- Recursively remove all Folders, Models, Attachments, and ParticleEmitters matching the orb type from all parts
		local function recursiveVFXCleanup(obj, orbType)
			for _, child in ipairs(obj:GetChildren()) do
				local nameTrimmed = child.Name:lower():gsub("^%s+", ""):gsub("%s+$", "")
				local orbTypeTrimmed = (orbType or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
				if child:IsA("Folder") or child:IsA("Model") or child:IsA("Attachment") then
					if nameTrimmed == orbTypeTrimmed then
						print("[OrbSpiritHandler] Recursively removing VFX '", child.Name, "' from:", getFullPath(child))
						child:Destroy()
					else
						recursiveVFXCleanup(child, orbType)
					end
				elseif child:IsA("ParticleEmitter") then
					print("[OrbSpiritHandler] Removing ParticleEmitter '", child.Name, "' from:", getFullPath(child))
					child:Destroy()
				else
					recursiveVFXCleanup(child, orbType)
				end
			end
		end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				recursiveVFXCleanup(part, orbType)
			end
		end
		print("[OrbSpiritHandler] --- END ORB VFX PART DEBUG (ON UNEQUIP) ---")
		-- Remove old slash particles
		local upperTorso = character:FindFirstChild("UpperTorso")
		if upperTorso then
			for _, slashName in ipairs({"Slash1", "Slash2"}) do
				local slash = upperTorso:FindFirstChild(slashName)
				if slash then
					slash:Destroy()
				end
			end
		end
	end

	-- Also remove slash particles
	OrbSpiritHandler.UnequipSlashParticles(player)

	-- Set HasOrbBuff flag in Stats folder to false (orb unequipped)
	do
		local stats = player:FindFirstChild("Stats")
		if stats then
			local hasOrbBuff = stats:FindFirstChild("HasOrbBuff")
			if not hasOrbBuff then
				hasOrbBuff = Instance.new("BoolValue")
				hasOrbBuff.Name = "HasOrbBuff"
				hasOrbBuff.Parent = stats
			end
			hasOrbBuff.Value = false
			--print("[OrbSpiritHandler] Set HasOrbBuff to false for " .. player.Name)
		end
	end

	-- Remove orb stat bonuses (restore to original values)
	-- [REMOVED] OrbSpiritHandler.RemoveOrbStatBonuses

	-- Clear multipliers (don't restore stats, they were never modified)
	clearOrbMultipliers(player)

	return true
end


-- Initialize spirit orb on character spawn (for respawns)
function OrbSpiritHandler.InitializePlayerOrbOnRespawn(player)
	if not player then return end
	
	-- Wait for character to load
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	
	task.spawn(function()
		task.wait(0.5) -- Wait for stats to be loaded
		
		-- Equip orb from inventory system
		OrbSpiritHandler.EquipOrbFromInventory(player)
	end)
end


-- Setup automatic respawn re-equipping for a player
function OrbSpiritHandler.SetupPlayerRespawnListener(player)
	if not player then return end

	-- Equip on initial character
	OrbSpiritHandler.InitializePlayerOrbOnRespawn(player)

	-- Track initial character
	if player.Character then
		lastKnownCharacters[player.UserId] = player.Character
	end

	-- Setup auto-detect and apply orb VFX/slash on every respawn
	player.CharacterAdded:Connect(function(character)
		-- Wait for Humanoid
		local humanoid = character:WaitForChild("Humanoid", 10)
		-- Setup death cleanup for orb visuals
		if humanoid then
			humanoid.Died:Connect(function()
				OrbSpiritHandler.UnequipSpiritOrb(player)
			end)
		end

		-- Always attempt to equip orb VFX/slash on character spawn
		task.defer(function()
			OrbSpiritHandler.EquipOrbFromInventory(player)
		end)

		-- Listen for EquippedOrb.name changes to always apply VFX
		local function setupOrbNameListener()
			local stats = player:FindFirstChild("Stats")
			if not stats then return end
			local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
			if not equippedOrbFolder or not equippedOrbFolder:IsA("Folder") then return end
			local orbNameValue = equippedOrbFolder:FindFirstChild("name")
			if not orbNameValue then return end

			-- Connect property changed event
			orbNameValue:GetPropertyChangedSignal("Value"):Connect(function()
				if orbNameValue.Value ~= "" then
					OrbSpiritHandler.EquipOrbFromInventory(player)
				end
			end)
		end

		-- Setup listener after short delay to ensure folders/values exist
		task.defer(setupOrbNameListener)
	end)
end



-- Clone Slash1 and Slash2 particles to player's UpperTorso and set their color
function OrbSpiritHandler.EquipSlashParticles(player, orbHandle)
	if not player or not player.Character then
		warn("[OrbSpiritHandler] Player or character is nil")
		return false
	end

	local character = player.Character
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso then
		warn("[OrbSpiritHandler] UpperTorso not found for player " .. player.Name)
		return false
	end

	-- Get orb type from inventory system (EquippedOrb folder)
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[OrbSpiritHandler] Stats not found for player " .. player.Name)
		return false
	end
	
	local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
	if not equippedOrbFolder then
		--print("[OrbSpiritHandler] No EquippedOrb folder found, skipping slash particles")
		return false
	end
	
	local orbNameValue = equippedOrbFolder:FindFirstChild("name")
	local orbName = orbNameValue and orbNameValue.Value or ""
	if not orbName or orbName == "" then 
		--print("[OrbSpiritHandler] No orb equipped, skipping slash particles")
		return false
	end
	
	local orbType = getOrbType(orbName)
	--print("[OrbSpiritHandler] Equipping slash particles for orb type '" .. orbType .. "'")
	
	-- Get color from orb type table (default to white if not found)
	local particleColor = orbTypeColors[orbType] or Color3.fromRGB(255, 255, 255)

	-- Clone Slash1 and Slash2 from ServerStorage.OrbSlash or create them
	local orbSlashFolder = ServerStorage:FindFirstChild("OrbSlash")
	
	for _, slashName in ipairs({"Slash1", "Slash2"}) do
		local slashTemplate = nil
		
		if orbSlashFolder then
			slashTemplate = orbSlashFolder:FindFirstChild(slashName)
		end
		
		-- If template doesn't exist, create a simple particle emitter
		if not slashTemplate then
			--print("[OrbSpiritHandler] Creating default slash particles for " .. slashName)
			slashTemplate = Instance.new("Part")
			slashTemplate.Name = slashName
			slashTemplate.CanCollide = false
			slashTemplate.CanTouch = false
			slashTemplate.Transparency = 1
			slashTemplate.Size = Vector3.new(1, 1, 1)
			
			local particleEmitter = Instance.new("ParticleEmitter")
			particleEmitter.Parent = slashTemplate
			particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			particleEmitter.Rate = 50
			particleEmitter.Lifetime = NumberRange.new(0.5)
			particleEmitter.Speed = NumberRange.new(10)
			particleEmitter.Enabled = false
		end
		
		-- Remove any existing slash particles
		local existingSlash = upperTorso:FindFirstChild(slashName)
		if existingSlash then
			existingSlash:Destroy()
		end

		-- Clone the slash particles
		local newSlash = slashTemplate:Clone()
		newSlash.Parent = upperTorso

		-- Change particle color and transparency to match orb type
		OrbSpiritHandler.UpdateParticleColor(newSlash, particleColor, orbType)

		-- Disable particles initially
		OrbSpiritHandler.SetParticlesEnabled(newSlash, false)

		--print("[OrbSpiritHandler] Successfully equipped " .. slashName .. " to UpperTorso for player " .. player.Name .. " with color type " .. orbType)
	end

	return true
end

-- Recursively update all particle colors and transparency in a model/folder
function OrbSpiritHandler.UpdateParticleColor(parent, color, orbType)
	if not parent or not color then return end

	-- Check if this is a ParticleEmitter
	if parent:IsA("ParticleEmitter") then
		parent.Color = ColorSequence.new(color)
		
		-- Set transparency based on orb type
		local transparency = orbTypeTransparency[orbType] or 0
		parent.Transparency = NumberSequence.new(transparency)
		return
	end

	-- Recursively search children
	for _, child in ipairs(parent:GetChildren()) do
		OrbSpiritHandler.UpdateParticleColor(child, color, orbType)
	end
end

-- Recursively enable or disable all particle emitters in a model/folder
function OrbSpiritHandler.SetParticlesEnabled(parent, enabled)
	if not parent then return end

	-- Check if this is a ParticleEmitter
	if parent:IsA("ParticleEmitter") then
		parent.Enabled = enabled
		return
	end

	-- Recursively search children
	for _, child in ipairs(parent:GetChildren()) do
		OrbSpiritHandler.SetParticlesEnabled(child, enabled)
	end
end

-- Trigger slash particle effect (enable for 0.5 seconds)
function OrbSpiritHandler.TriggerSlashParticles(player)
	if not player or not player.Character then return end

	local character = player.Character
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso then return end

	-- Check if already active to prevent overlapping effects
	if activeParticleEffects[player] then return end

	-- Mark as active
	activeParticleEffects[player] = true

	-- Enable particles for Slash1 and Slash2
	for _, slashName in ipairs({"Slash1", "Slash2"}) do
		local slash = upperTorso:FindFirstChild(slashName)
		if slash then
			OrbSpiritHandler.SetParticlesEnabled(slash, true)
		end
	end

	-- Disable after 0.3 seconds
	task.wait(0.1)
	for _, slashName in ipairs({"Slash1", "Slash2"}) do
		local slash = upperTorso:FindFirstChild(slashName)
		if slash then
			OrbSpiritHandler.SetParticlesEnabled(slash, false)
		end
	end

	-- Mark as inactive
	activeParticleEffects[player] = nil
end

-- Remove slash particles from player
function OrbSpiritHandler.UnequipSlashParticles(player)
	if not player or not player.Character then return false end

	local character = player.Character
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso then return false end

	for _, slashName in ipairs({"Slash1", "Slash2"}) do
		local slash = upperTorso:FindFirstChild(slashName)
		if slash then
			slash:Destroy()
			--print("[OrbSpiritHandler] Removed " .. slashName .. " from UpperTorso for player " .. player.Name)
		end
	end

	-- Clear active effect flag if any
	activeParticleEffects[player] = nil

	return true
end

-- Check if player has a spirit orb equipped
function OrbSpiritHandler.HasSpiritOrb(player)
	if not player then return false end

	local stats = player:FindFirstChild("Stats")
	if not stats then return false end

	-- Check the new inventory-based EquippedOrb folder
	local equippedOrb = stats:FindFirstChild("EquippedOrb")
	if not equippedOrb or not equippedOrb:IsA("Folder") then return false end

	local orbName = equippedOrb:FindFirstChild("name")
	if not orbName then return false end

	return orbName.Value ~= "" and orbName.Value ~= nil
end

-- Get the equipped orb name from inventory
function OrbSpiritHandler.GetEquippedOrbName(player)
	if not player then return "" end

	local stats = player:FindFirstChild("Stats")
	if not stats then return "" end

	local equippedOrb = stats:FindFirstChild("EquippedOrb")
	if not equippedOrb or not equippedOrb:IsA("Folder") then return "" end

	local orbName = equippedOrb:FindFirstChild("name")
	if orbName then
		return orbName.Value
	end

	return ""
end

-- Extend weapon HitPart to 3 studs if player has spirit orb
function OrbSpiritHandler.ExtendWeaponHitPart(hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then return end

	-- Store original size if not already stored
	if not hitPart:GetAttribute("OriginalSize") then
		hitPart:SetAttribute("OriginalSize", hitPart.Size)
	end

	-- Extend the Z-axis (length) to 5 studs
	local originalSize = hitPart:GetAttribute("OriginalSize")
	hitPart.Size = Vector3.new(originalSize.X, originalSize.Y, 5)
end

-- Reset weapon HitPart to original size
function OrbSpiritHandler.ResetWeaponHitPart(hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local originalSize = hitPart:GetAttribute("OriginalSize")
	if originalSize then
		hitPart.Size = originalSize
	end
end

-- Public function to forcefully clear all cached player data (for debugging/cleanup)
function OrbSpiritHandler.ForceCleanupAllPlayerData()
	activeParticleEffects = {}
	lastKnownCharacters = {}
	--print("[OrbSpiritHandler] Forcefully cleaned up all cached player orb data (base stat cache removed)")
end

-- Cleanup player orb data when they disconnect
local function cleanupPlayerOrbData(player)
	if not player or not player.Parent then
		return  -- Player already removed, skip cleanup
	end
	
	local userId = player.UserId
	
	
	-- Clear multipliers
	if playerOrbMultipliers[userId] then
		playerOrbMultipliers[userId] = nil
	end
	
	-- Clear orb equipped flag
	if playerOrbEquipped[userId] then
		playerOrbEquipped[userId] = nil
	end
	
	-- [REMOVED] playerOrbBonusedStats cleanup
	
	--print("[OrbSpiritHandler] Cleaned up orb data for " .. player.Name .. " (userId: " .. userId .. ")")
	
	-- Remove from particle effects tracking
	if activeParticleEffects[userId] then
		activeParticleEffects[userId] = nil
	end
	
	-- Remove from equipping flag
	if isEquippingOrb[userId] then
		isEquippingOrb[userId] = nil
	end
	
	-- Remove from character tracking
	if lastKnownCharacters[userId] then
		lastKnownCharacters[userId] = nil
	end
end


-- Public wrapper to cleanup player orb data
-- Called after saving to clean up cached tables
function OrbSpiritHandler.CleanupPlayerOrbData(player)
	cleanupPlayerOrbData(player)
end


-- Monitor players leaving to cleanup orb data
-- NOTE: PlayerDataStore already handles this via RemoveOrbStatBonuses before save
-- We don't need to cleanup here since RemoveOrbStatBonuses will handle restoration
-- and cleanup will happen after save in PlayerDataStore
-- Players.PlayerRemoving:Connect(function(player)
--	cleanupPlayerOrbData(player)
-- end)

-- Get equipped orb from inventory system (EquippedOrb folder in Stats)
function OrbSpiritHandler.GetEquippedOrbFromInventory(player)
	if not player then return nil end
	
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	
	local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
	if not equippedOrbFolder or not equippedOrbFolder:IsA("Folder") then return nil end
	
	local nameValue = equippedOrbFolder:FindFirstChild("name")
	local idValue = equippedOrbFolder:FindFirstChild("id")
	
	if not nameValue or not idValue then return nil end
	
	return {
		name = nameValue.Value,
		id = idValue.Value
	}
end

-- Equip orb from inventory system (uses EquippedOrb folder instead of SpiritOrb stat)
function OrbSpiritHandler.EquipOrbFromInventory(player)
    if not player then
        warn("[OrbSpiritHandler] Player is nil")
        return false
    end
    local userId = player.UserId
    if isEquippingOrb[userId] then
        warn("[OrbSpiritHandler] Already equipping orb for userId " .. tostring(userId) .. ", skipping.")
        return false
    end
    isEquippingOrb[userId] = true
    local cleanup = function()
        isEquippingOrb[userId] = nil
    end
    local ok, result = pcall(function()
        --print("[OrbSpiritHandler] EquipOrbFromInventory called for player " .. player.Name)
        OrbSpiritHandler.UnequipSpiritOrb(player)
        
        -- Get the current equipped orb from Stats.EquippedOrb folder
        -- This was already set by InventoryManager.setEquippedOrb before this function was called
        local equippedOrbData = OrbSpiritHandler.GetEquippedOrbFromInventory(player)
        --print("[OrbSpiritHandler] Reading equipped orb from Stats:", equippedOrbData and equippedOrbData.name or "nil", equippedOrbData and equippedOrbData.id or "nil")
        
        -- Update HasOrbBuff flag
        do
            local stats = player:FindFirstChild("Stats")
            if stats then
                local hasOrbBuff = stats:FindFirstChild("HasOrbBuff")
                if not hasOrbBuff then
                    hasOrbBuff = Instance.new("BoolValue")
                    hasOrbBuff.Name = "HasOrbBuff"
                    hasOrbBuff.Parent = stats
                end
                if equippedOrbData and equippedOrbData.name and equippedOrbData.name ~= "" then
                    hasOrbBuff.Value = true
                    --print("[OrbSpiritHandler] Set HasOrbBuff to true for " .. player.Name)
                else
                    hasOrbBuff.Value = false
                    --print("[OrbSpiritHandler] Set HasOrbBuff to false for " .. player.Name)
                end
            else
                warn("[OrbSpiritHandler] Stats folder missing for player " .. player.Name)
            end
        end
    
        if not equippedOrbData or not equippedOrbData.name or equippedOrbData.name == "" then
            warn("[OrbSpiritHandler] Player " .. player.Name .. " has no equipped orb in inventory system")
            return false
        end
        local character = player.Character
        if not character then
            warn("[OrbSpiritHandler] Player " .. player.Name .. " has no character")
            return false
        end
        local stats = player:FindFirstChild("Stats")
        if not stats then
            warn("[OrbSpiritHandler] Player " .. player.Name .. " has no Stats folder")
            return false
        end
        -- Remove old orb accessory, VFX, etc.
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Accessory") and child.Name:match("[Oo]rb") then
                --print("[OrbSpiritHandler] Removing old orb accessory: " .. child.Name)
                child:Destroy()
                break
            end
        end
        -- Remove all HandVFX and particles from all parts before equipping new one
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                for _, child in ipairs(part:GetChildren()) do
                    if child.Name:find("VFX") or child:IsA("ParticleEmitter") then
                        child:Destroy()
                    end
                end
            end
        end
        -- Remove old slash particles
        local upperTorso = character:FindFirstChild("UpperTorso")
        if upperTorso then
            for _, slashName in ipairs({"Slash1", "Slash2"}) do
                local slash = upperTorso:FindFirstChild(slashName)
                if slash then
                    --print("[OrbSpiritHandler] Removing old slash particle: " .. slashName)
                    slash:Destroy()
                end
            end
        end
        task.wait(0.1) -- Wait for cleanup
		local orbName = equippedOrbData.name
		local orbId = equippedOrbData.id
		local newOrbType = getOrbType(orbName)
        -- Find the orb in ServerStorage
        local orbsFolder = ServerStorage:FindFirstChild("Orbs")
        local orbTemplate = nil
        if orbsFolder then
            --print("[OrbSpiritHandler] OrbsFolder found. Children:")
            for _, v in ipairs(orbsFolder:GetChildren()) do
                --print("  ", v.Name)
            end
            orbTemplate = orbsFolder:FindFirstChild(orbName)
        else
            warn("[OrbSpiritHandler] OrbsFolder not found in ServerStorage!")
        end
        -- Also check OrbItems folder
        if not orbTemplate then
            local orbItemsFolder = ServerStorage:FindFirstChild("OrbItems")
            if orbItemsFolder then
                --print("[OrbSpiritHandler] OrbItemsFolder found. Children:")
                for _, v in ipairs(orbItemsFolder:GetChildren()) do
                    --print("  ", v.Name)
                end
                orbTemplate = orbItemsFolder:FindFirstChild(orbName)
            else
                warn("[OrbSpiritHandler] OrbItemsFolder not found in ServerStorage!")
            end
        end
        if not orbTemplate then
            warn("[OrbSpiritHandler] Orb '" .. orbName .. "' not found in ServerStorage. Searched Orbs and OrbItems folders.")
            return false
        end
        --print("[OrbSpiritHandler] Found orb template: " .. orbTemplate.Name)
        -- Clone and equip orb
        local newOrb = orbTemplate:Clone()
        newOrb.Parent = character
        --print("[OrbSpiritHandler] Equipped orb '" .. orbName .. "' for player " .. player.Name)
        task.wait(0.1)
        -- Set position offset
        local handle = newOrb:FindFirstChild("Handle")
        if handle then
            local accessoryWeld = handle:FindFirstChild("AccessoryWeld")
            if accessoryWeld then
                if accessoryWeld:IsA("Attachment") then
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                    if humanoidRootPart then
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = humanoidRootPart
                        weld.Part1 = handle
                        weld.Parent = handle
                        --print("[OrbSpiritHandler] WeldConstraint created between HumanoidRootPart and Handle")
                    end
                else
                    accessoryWeld.C0 = CFrame.new(0, 0, -1.5)
                    --print("[OrbSpiritHandler] AccessoryWeld C0 set for Handle")
                end
            end
        end
		-- Equip HandVFX to all parts with Motor6D connections
		local handVfxFolder = ServerStorage:FindFirstChild("HandVFX")
		if handVfxFolder then
			local handVfxTemplate = handVfxFolder:FindFirstChild(newOrbType)
			if handVfxTemplate then
				-- Find all parts with Motor6D connections
				local partsWithMotor6D = {}
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						for _, child in ipairs(part:GetChildren()) do
							if child:IsA("Motor6D") then
								table.insert(partsWithMotor6D, part)
								break
							end
						end
					end
				end
				-- Debug: Log all parts that will get a VFX folder
				local function getFullPath(obj)
					local path = obj.Name
					local parent = obj.Parent
					while parent and parent ~= workspace and parent ~= nil do
						path = parent.Name .. "." .. path
						parent = parent.Parent
					end
					return path
				end
				print("[OrbSpiritHandler] --- ORB VFX PART DEBUG (ON EQUIP) ---")
				for _, part in ipairs(partsWithMotor6D) do
					print("[OrbSpiritHandler] Will attach VFX to part:", getFullPath(part))
				end
				print("[OrbSpiritHandler] --- END ORB VFX PART DEBUG (ON EQUIP) ---")
				-- Clone VFX to each part with Motor6D
				for _, part in ipairs(partsWithMotor6D) do
					local newVfx = handVfxTemplate:Clone()
					newVfx.Parent = part
				end
			else
				warn("[OrbSpiritHandler] HandVFX template '" .. newOrbType .. "' not found in HandVFXFolder!")
			end
		else
			warn("[OrbSpiritHandler] HandVFXFolder not found in ServerStorage!")
		end
		-- Equip slash particles
		if handle then
			OrbSpiritHandler.EquipSlashParticles(player, handle)
		else
			warn("[OrbSpiritHandler] No Handle found on orb for EquipSlashParticles!")
		end
        -- Store multipliers (for DamageManager to use ONLY - never applied to stats)
        storeOrbMultipliers(player, orbName)
        
        -- Notify client UI to refresh stats display (orb bonus changed)
        local refreshStatsUIEvent = ReplicatedStorage:FindFirstChild("RefreshStatsUI")
        if refreshStatsUIEvent then
            refreshStatsUIEvent:FireClient(player)
            --print("[OrbSpiritHandler] RefreshStatsUI event fired for player " .. player.Name)
        end
        
        --print("[OrbSpiritHandler] ✓ Successfully equipped orb VFX/particles for " .. player.Name .. ": " .. orbName)
    end)
    cleanup()
    if not ok then
        warn("[OrbSpiritHandler] Exception in EquipOrbFromInventory for userId " .. tostring(userId) .. ": " .. tostring(result))
        return false
    end
    return result == nil and true or result
end

-- Listen for EquippedOrbChanged event from inventory system to equip orb
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquippedOrbChangedEvent = ReplicatedStorage:FindFirstChild("EquippedOrbChanged")
if not EquippedOrbChangedEvent then
	EquippedOrbChangedEvent = Instance.new("RemoteEvent")
	EquippedOrbChangedEvent.Name = "EquippedOrbChanged"
	EquippedOrbChangedEvent.Parent = ReplicatedStorage
end

EquippedOrbChangedEvent.OnServerEvent:Connect(function(player)
	--print("[OrbSpiritHandler] EquippedOrbChanged event fired for " .. player.Name)
	task.wait(0.15) -- Wait for stats to be saved and data to sync
	local success = OrbSpiritHandler.EquipOrbFromInventory(player)
	if success then
		--print("[OrbSpiritHandler] Successfully applied orb VFX for " .. player.Name)
	else
		warn("[OrbSpiritHandler] Failed to apply orb VFX for " .. player.Name)
	end
end)

-- Clear cached base stats for a player (used when resetting stats)

-- CRITICAL: Capture base stats right after character loads (before orb equip)
-- This ensures we capture the true base stats from DataStore before any orb logic

-- Set admin stat change flag (suspend listeners during admin stat changes)
function OrbSpiritHandler.SetAdminStatChangeFlag(player, enabled)
	if not player then return end
	local userId = player.UserId
	if enabled then
		isChangingStatsFromAdmin[userId] = true
		--print("[OrbSpiritHandler] Suspended stat listeners for admin change: " .. player.Name)
	else
		isChangingStatsFromAdmin[userId] = nil
		--print("[OrbSpiritHandler] Resumed stat listeners after admin change: " .. player.Name)
	end
end

-- Get base stats for a player (returns table with base values)
-- These are ALWAYS base stats - never affected by orb multipliers
-- Orb multipliers are applied separately in DamageManager.calculateDamage()
function OrbSpiritHandler.GetBaseStats(player)
	   -- Base stats are now always the current stats in the folder, as base stat caching is removed
	   if not player then return {} end
	   local stats = player:FindFirstChild("Stats")
	   if not stats then return {} end
	   return {
		   Attack = stats:FindFirstChild("Attack") and stats.Attack.Value or 1,
		   Defence = stats:FindFirstChild("Defence") and stats.Defence.Value or 1,
		   MaxHealth = stats:FindFirstChild("MaxHealth") and stats.MaxHealth.Value or 10,
		   MaxMana = stats:FindFirstChild("MaxMana") and stats.MaxMana.Value or 5,
		   Dexterity = stats:FindFirstChild("Dexterity") and stats.Dexterity.Value or 1
	   }
end

-- Get orb multipliers for a player (used ONLY by DamageManager to apply buff in damage calculation)
-- CRITICAL: These are NOT applied to stats - stats remain base values always
-- Used in DamageManager.calculateDamage() to multiply Attack before damage formula
function OrbSpiritHandler.GetOrbMultipliers(player)
	if not player then return {} end
	local userId = player.UserId
	return playerOrbMultipliers[userId] or {}
end

-- Check if player's orb has been equipped (for initial UI display timing)
function OrbSpiritHandler.IsOrbEquipped(player)
	if not player then return false end
	local userId = player.UserId
	return playerOrbEquipped[userId] or false
end

-- Create RemoteFunction for clients to get base stats
local getBaseStatsFunction = ReplicatedStorage:FindFirstChild("GetBaseStatsFunction")
if not getBaseStatsFunction then
	getBaseStatsFunction = Instance.new("RemoteFunction")
	getBaseStatsFunction.Name = "GetBaseStatsFunction"
	getBaseStatsFunction.Parent = ReplicatedStorage
end

getBaseStatsFunction.OnServerInvoke = function(player)
	return OrbSpiritHandler.GetBaseStats(player)
end

-- Create RemoteFunction for clients to get orb multipliers (for damage display UI)
local getOrbMultiplierFunction = ReplicatedStorage:FindFirstChild("GetOrbMultiplierFunction")
if not getOrbMultiplierFunction then
	getOrbMultiplierFunction = Instance.new("RemoteFunction")
	getOrbMultiplierFunction.Name = "GetOrbMultiplierFunction"
	getOrbMultiplierFunction.Parent = ReplicatedStorage
end

getOrbMultiplierFunction.OnServerInvoke = function(player)
	return OrbSpiritHandler.GetOrbMultipliers(player)
end

-- Create RemoteFunction for clients to check if orb has been equipped
local isOrbEquippedFunction = ReplicatedStorage:FindFirstChild("IsOrbEquippedFunction")
if not isOrbEquippedFunction then
	isOrbEquippedFunction = Instance.new("RemoteFunction")
	isOrbEquippedFunction.Name = "IsOrbEquippedFunction"
	isOrbEquippedFunction.Parent = ReplicatedStorage
end

isOrbEquippedFunction.OnServerInvoke = function(player)
	return OrbSpiritHandler.IsOrbEquipped(player)
end

-- [REMOVED] OrbSpiritHandler.ApplyOrbStatBonuses

-- Returns orb multipliers for a player (Attack, Defence, etc.)
function OrbSpiritHandler.GetOrbMultipliers(userId)
	return playerOrbMultipliers[userId]
end

return OrbSpiritHandler
