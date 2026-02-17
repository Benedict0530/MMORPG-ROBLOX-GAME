-- DuelHandler.lua
-- Manages player-to-player duel invitations and duel state
local DuelHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Store active duel invitations: {invitedPlayer = inviterPlayer}
local activeDuelInvitations = {}

-- Store active duels: {player1UserId = player2UserId, player2UserId = player1UserId}
local activeDuels = {}
-- Store duel damage lock: {userId = true if damage is locked}
local duelDamageLocked = {}

-- Store duel stats tracking
local duelStats = {} -- {userId = {wins = 0, losses = 0, totalDuels = 0}}

-- Timeout for invitations (30 seconds)
local INVITATION_TIMEOUT = 30

-- Create Remote Events
local function setupRemoteEvents()
	-- Event for sending duel invitations to clients
	local duelInvitationEvent = ReplicatedStorage:FindFirstChild("DuelInvitationEvent")
	if not duelInvitationEvent then
		duelInvitationEvent = Instance.new("RemoteEvent")
		duelInvitationEvent.Name = "DuelInvitationEvent"
		duelInvitationEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelInvitationEvent")
	end
	
	-- Function for responding to duel invitations
	local duelResponseFunction = ReplicatedStorage:FindFirstChild("DuelResponseFunction")
	if not duelResponseFunction then
		duelResponseFunction = Instance.new("RemoteFunction")
		duelResponseFunction.Name = "DuelResponseFunction"
		duelResponseFunction.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelResponseFunction")
	end
	
	-- Event for duel starting
	local duelStartedEvent = ReplicatedStorage:FindFirstChild("DuelStartedEvent")
	if not duelStartedEvent then
		duelStartedEvent = Instance.new("RemoteEvent")
		duelStartedEvent.Name = "DuelStartedEvent"
		duelStartedEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelStartedEvent")
	end
	
	-- Event for duel ending
	local duelEndedEvent = ReplicatedStorage:FindFirstChild("DuelEndedEvent")
	if not duelEndedEvent then
		duelEndedEvent = Instance.new("RemoteEvent")
		duelEndedEvent.Name = "DuelEndedEvent"
		duelEndedEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelEndedEvent")
	end
	
	-- Event for duel finishing (last hit, for animation)
	local duelFinishingEvent = ReplicatedStorage:FindFirstChild("DuelFinishingEvent")
	if not duelFinishingEvent then
		duelFinishingEvent = Instance.new("RemoteEvent")
		duelFinishingEvent.Name = "DuelFinishingEvent"
		duelFinishingEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelFinishingEvent")
	end

	-- Event for player interaction (duel invite)
	local playerInteractionEvent = ReplicatedStorage:FindFirstChild("PlayerInteractionEvent")
	if not playerInteractionEvent then
		playerInteractionEvent = Instance.new("RemoteEvent")
		playerInteractionEvent.Name = "PlayerInteractionEvent"
		playerInteractionEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created PlayerInteractionEvent")
	end

	-- Event for duel finishing sync (winner triggers, server relays to loser)
	local duelFinishingSyncEvent = ReplicatedStorage:FindFirstChild("DuelFinishingSyncEvent")
	if not duelFinishingSyncEvent then
		duelFinishingSyncEvent = Instance.new("RemoteEvent")
		duelFinishingSyncEvent.Name = "DuelFinishingSyncEvent"
		duelFinishingSyncEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created DuelFinishingSyncEvent")
	end

	return duelInvitationEvent, duelResponseFunction, duelStartedEvent, duelEndedEvent, playerInteractionEvent, duelFinishingEvent, duelFinishingSyncEvent
end

-- Fire DuelFinishingEvent to both duelists
function DuelHandler.fireDuelFinishingEvent(userId1, userId2)
	local duelFinishingEvent = ReplicatedStorage:FindFirstChild("DuelFinishingEvent")
	local ServerStorage = game:GetService("ServerStorage")
	if duelFinishingEvent then
		local player1 = Players:GetPlayerByUserId(userId1)
		local player2 = Players:GetPlayerByUserId(userId2)

		print("[DuelHandler] Fired DuelFinishingEvent to both players (winner/loser flag sent)")

		-- Save equipped weapons before unequipping
		local equippedWeapons = {} -- [userId] = {primary = id, secondary = id}
		local function saveAndUnequipWeapons(player)
			if not player or not player.Character then return end
			local stats = player:FindFirstChild("Stats")
			local equipped = stats and stats:FindFirstChild("Equipped")
			local primaryId = equipped and equipped:FindFirstChild("id") and equipped:FindFirstChild("id").Value or nil
			local secondaryId = equipped and equipped:FindFirstChild("secondaryId") and equipped:FindFirstChild("secondaryId").Value or nil
			equippedWeapons[player.UserId] = {primary = primaryId, secondary = secondaryId}
			-- Unequip logic
			local WeaponManager = require(script.Parent.Parent.Items.WeaponManager)
			WeaponManager.UnequipWeapon(player)
			local SecondaryWeaponHandler = require(script.Parent.Parent.Combat.SecondaryWeaponHandler)
			if SecondaryWeaponHandler.UnequipSecondaryWeapon then
				SecondaryWeaponHandler:UnequipSecondaryWeapon(player)
			end
			for _, container in ipairs({player.Character, player.Backpack}) do
				if container then
					for _, item in ipairs(container:GetChildren()) do
						if item:IsA("Tool") then
							item:Destroy()
						end
					end
				end
			end
		end
		saveAndUnequipWeapons(player1)
		saveAndUnequipWeapons(player2)
		DuelHandler._lastEquippedWeapons = equippedWeapons

		if player1 and player2 then
			duelFinishingEvent:FireClient(player1, true, player2.UserId) -- winner gets opponent's userId
			duelFinishingEvent:FireClient(player2, false, player1.UserId) -- loser gets opponent's userId
		elseif player1 then
			duelFinishingEvent:FireClient(player1, true, nil)
		elseif player2 then
			duelFinishingEvent:FireClient(player2, false, nil)
		end

		-- Clone and parent FinishingVFX to the winner, colored by equipped orb
		if player1 and player1.Character then
			local finishingVFX = ServerStorage:FindFirstChild("FinishingVFX")
			if finishingVFX then
				local vfxClone = finishingVFX:Clone()
				-- Get orb color
				local OrbSpiritHandler = require(script.Parent.Parent.Items.OrbSpiritHandler)
				local orbName = OrbSpiritHandler.GetEquippedOrbName(player1)
				local orbType = orbName and orbName:match("^(.+)%s+Orb$") or orbName or "Normal"
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
				local color = orbTypeColors[orbType] or orbTypeColors["Normal"]
				-- Recursively update all ParticleEmitters in vfxClone
				local function updateParticles(obj)
					for _, child in ipairs(obj:GetDescendants()) do
						if child:IsA("ParticleEmitter") then
							child.Color = ColorSequence.new(color)
						end
					end
				end
				updateParticles(vfxClone)
				vfxClone.Parent = player1.Character
			end
		end

		   -- Clone and parent LosingVFX to the loser, colored by the winner's equipped orb
		   if player2 and player2.Character then
			   local losingVFX = ServerStorage:FindFirstChild("LosingVFX")
			   if losingVFX then
				   local vfxClone = losingVFX:Clone()
				   -- Get winner's orb color
				   local OrbSpiritHandler = require(script.Parent.Parent.Items.OrbSpiritHandler)
				   local orbName = OrbSpiritHandler.GetEquippedOrbName(player1)
				   local orbType = orbName and orbName:match("^(.+)%s+Orb$") or orbName or "Normal"
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
				   local color = orbTypeColors[orbType] or orbTypeColors["Normal"]
				   local function updateParticles(obj)
					   for _, child in ipairs(obj:GetDescendants()) do
						   if child:IsA("ParticleEmitter") then
							   child.Color = ColorSequence.new(color)
						   end
					   end
				   end
				   updateParticles(vfxClone)
				   vfxClone.Parent = player2.Character
			   end
		   end

		if player2 then
			local info = equippedWeapons[player2.UserId]
			if info then
				if info.primary and info.primary ~= "" then
					local InventoryManager = require(script.Parent.Parent.Items.InventoryManager)
					InventoryManager.setEquippedWeapon(player2, (info.primary:match("^(.-)_") or info.primary), info.primary)
				end
				local SecondaryWeaponHandler = require(script.Parent.Parent.Combat.SecondaryWeaponHandler)
				if info.secondary and info.secondary ~= "" and SecondaryWeaponHandler.EquipSecondaryWeaponById then
					pcall(function()
						SecondaryWeaponHandler:EquipSecondaryWeaponById(player2, info.secondary)
					end)
				end
			end
		end

	else
		warn("[DuelHandler] DuelFinishingEvent not found in ReplicatedStorage!")
	end
end

-- Check if a player is already in a duel
local function isPlayerInDuel(userId)
	return activeDuels[userId] ~= nil
end

-- Check if a player has a pending invitation
local function hasPendingInvitation(player)
	return activeDuelInvitations[player] ~= nil
end

-- Send duel invitation
local function sendDuelInvitation(inviter, invited)
	if not inviter or not invited then
		warn("[DuelHandler] Invalid players for duel invitation")
		return false
	end
	
	-- Check if inviter is in a duel
	if isPlayerInDuel(inviter.UserId) then
		print("[DuelHandler] " .. inviter.Name .. " is already in a duel")
		return false
	end
	
	-- Check if invited player is in a duel
	if isPlayerInDuel(invited.UserId) then
		print("[DuelHandler] " .. invited.Name .. " is already in a duel")
		local duelInvitationEvent = ReplicatedStorage:FindFirstChild("DuelInvitationEvent")
		if duelInvitationEvent then
			duelInvitationEvent:FireClient(inviter, invited, "AlreadyInDuel")
		end
		return false
	end
	
	-- Check if invited player already has a pending invitation
	if hasPendingInvitation(invited) then
		print("[DuelHandler] " .. invited.Name .. " already has a pending duel invitation")
		local duelInvitationEvent = ReplicatedStorage:FindFirstChild("DuelInvitationEvent")
		if duelInvitationEvent then
			duelInvitationEvent:FireClient(inviter, invited, "HasPendingInvite")
		end
		return false
	end
	
	-- Store the invitation
	activeDuelInvitations[invited] = inviter
	print("[DuelHandler] ✅ Stored invitation: " .. inviter.Name .. " -> " .. invited.Name)
	
	-- Send invitation to invited player
	local duelInvitationEvent = ReplicatedStorage:FindFirstChild("DuelInvitationEvent")
	if duelInvitationEvent then
		print("[DuelHandler] 📤 Firing DuelInvitationEvent to " .. invited.Name)
		print("[DuelHandler] Event parameters: inviter=" .. inviter.Name .. ", errorType=nil")
		duelInvitationEvent:FireClient(invited, inviter, nil)
		print("[DuelHandler] ✅ DuelInvitationEvent fired successfully")
	else
		warn("[DuelHandler] ❌ DuelInvitationEvent NOT FOUND in ReplicatedStorage!")
	end
	
	-- Set timeout to auto-decline after 30 seconds
	task.delay(INVITATION_TIMEOUT, function()
		if activeDuelInvitations[invited] == inviter then
			activeDuelInvitations[invited] = nil
			print("[DuelHandler] Duel invitation from " .. inviter.Name .. " to " .. invited.Name .. " timed out")
		end
	end)
	
	return true
end

-- Start a duel between two players
local function startDuel(player1, player2)
	if not player1 or not player2 then
		warn("[DuelHandler] Invalid players for starting duel")
		return false
	end
	
	-- Double-check neither player is in a duel
	if isPlayerInDuel(player1.UserId) or isPlayerInDuel(player2.UserId) then
		warn("[DuelHandler] One or both players are already in a duel")
		return false
	end
	
	-- Get both characters
	local char1 = player1.Character
	local char2 = player2.Character
	
	if not char1 or not char2 then
		warn("[DuelHandler] One or both players don't have a character")
		return false
	end
	
	local root1 = char1:FindFirstChild("HumanoidRootPart")
	local root2 = char2:FindFirstChild("HumanoidRootPart")
	
	if not root1 or not root2 then
		warn("[DuelHandler] One or both players missing HumanoidRootPart")
		return false
	end
	
	-- Check if both players are in the same map
	local stats1 = player1:FindFirstChild("Stats")
	local stats2 = player2:FindFirstChild("Stats")
	
	if stats1 and stats2 then
		local map1 = stats1:FindFirstChild("PlayerMap")
		local map2 = stats2:FindFirstChild("PlayerMap")
		
		if map1 and map2 and map1.Value ~= map2.Value then
			print("[DuelHandler] Players in different maps - cannot start duel")
			print("[DuelHandler] " .. player1.Name .. " in: " .. map1.Value)
			print("[DuelHandler] " .. player2.Name .. " in: " .. map2.Value)
			-- End duel as draw (no winner)
			DuelHandler.EndDuel(player1.UserId, player2.UserId, nil, "different_maps")
			return false
		end
	end
	
	-- Check if either player is in a SafeZone
	if player1:GetAttribute("SafeZone") == true then
		print("[DuelHandler] " .. player1.Name .. " is in SafeZone - cannot start duel")
		-- End duel as draw (no winner)
		DuelHandler.EndDuel(player1.UserId, player2.UserId, nil, "safe_zone")
		return false
	end
	
	if player2:GetAttribute("SafeZone") == true then
		print("[DuelHandler] " .. player2.Name .. " is in SafeZone - cannot start duel")
		-- End duel as draw (no winner)
		DuelHandler.EndDuel(player1.UserId, player2.UserId, nil, "safe_zone")
		return false
	end
	
	-- Calculate center point between both players
	local centerPosition = (root1.Position + root2.Position) / 2
	
	-- Distance between players (3 studs apart)
	local duelDistance = 3
	local halfDistance = duelDistance / 2
	
	-- Calculate positions: Player1 on one side, Player2 on the other
	-- Use the direction vector between them to maintain orientation
	local direction = (root2.Position - root1.Position).Unit
	
	-- Position player1 on one side of center, player2 on other side
	local position1 = centerPosition - (direction * halfDistance)
	local position2 = centerPosition + (direction * halfDistance)
	
	-- Function to find ground position using raycast
	local function findGroundPosition(position)
		-- Ray parameters: start above position, cast downward
		local rayOrigin = Vector3.new(position.X, position.Y + 50, position.Z)
		local rayDirection = Vector3.new(0, -100, 0) -- Cast 100 studs down
		
		-- Create raycast params to ignore players
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {char1, char2}
		
		-- Cast ray
		local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
		
		if rayResult then
			-- Found ground, return position slightly above surface
			local groundPosition = rayResult.Position + Vector3.new(0, 3, 0) -- 3 studs above ground
			print("[DuelHandler] Found ground at Y=" .. math.floor(rayResult.Position.Y))
			return groundPosition
		else
			-- No ground found, use original position
			warn("[DuelHandler] No ground found at position, using original")
			return position
		end
	end
	
	-- Find safe ground positions for both players
	local safePosition1 = findGroundPosition(position1)
	local safePosition2 = findGroundPosition(position2)
	
	-- Ensure both positions are at the same Y level for fair duel
	local averageY = (safePosition1.Y + safePosition2.Y) / 2
	safePosition1 = Vector3.new(safePosition1.X, averageY, safePosition1.Z)
	safePosition2 = Vector3.new(safePosition2.X, averageY, safePosition2.Z)
	
	-- Create CFrames facing each other with ground-adjusted positions
	-- Player1 looks towards Player2
	local cframe1 = CFrame.new(safePosition1, safePosition2)
	-- Player2 looks towards Player1
	local cframe2 = CFrame.new(safePosition2, safePosition1)
	
	-- Set IsPortalTeleporting flag to prevent anti-tp hack detection
	player1:SetAttribute("IsPortalTeleporting", true)
	player2:SetAttribute("IsPortalTeleporting", true)
	
	-- Teleport both players
	print("[DuelHandler] Teleporting players to duel positions...")
	print("[DuelHandler] Position 1: Y=" .. math.floor(safePosition1.Y) .. ", Position 2: Y=" .. math.floor(safePosition2.Y))
	root1.CFrame = cframe1
	root2.CFrame = cframe2
	
	-- Anchor both players so they cannot move during duel
	root1.Anchored = true
	root2.Anchored = true
	print("[DuelHandler] ✅ Players anchored and positioned " .. duelDistance .. " studs apart on even ground, facing each other")
	
	-- Remove IsPortalTeleporting flag after a short delay
	task.delay(0.2, function()
		player1:SetAttribute("IsPortalTeleporting", false)
		player2:SetAttribute("IsPortalTeleporting", false)
	end)
	
	-- Register the duel (bidirectional mapping)
	activeDuels[player1.UserId] = player2.UserId
	activeDuels[player2.UserId] = player1.UserId

	-- Lock damage for both players
	duelDamageLocked[player1.UserId] = true
	duelDamageLocked[player2.UserId] = true
	print("[DuelHandler][DEBUG] duelDamageLocked set to true for", player1.UserId, player2.UserId)
	print("[DuelHandler] Duel started between " .. player1.Name .. " and " .. player2.Name)

	-- Fire DuelStartedEvent for both players so clients can disable attacks
	local duelStartedEvent = ReplicatedStorage:FindFirstChild("DuelStartedEvent")
	if duelStartedEvent then
		 duelStartedEvent:FireClient(player1)
		 duelStartedEvent:FireClient(player2)
		 print("[DuelHandler] Fired DuelStartedEvent to both players")
	else
		 warn("[DuelHandler] DuelStartedEvent not found in ReplicatedStorage!")
	end

	-- Countdown: 3, 2, 1, Start (show to both players)
	local countdownEvent = ReplicatedStorage:FindFirstChild("DuelCountdownEvent")
	if not countdownEvent then
		countdownEvent = Instance.new("RemoteEvent")
		countdownEvent.Name = "DuelCountdownEvent"
		countdownEvent.Parent = ReplicatedStorage
	end
	task.spawn(function()
		for i = 3, 1, -1 do
			countdownEvent:FireClient(player1, i)
			countdownEvent:FireClient(player2, i)
			task.wait(1)
		end
		countdownEvent:FireClient(player1, "Start")
		countdownEvent:FireClient(player2, "Start")

		-- Double-check both players are still in a duel before unlocking damage
		if activeDuels[player1.UserId] == player2.UserId and activeDuels[player2.UserId] == player1.UserId then
			duelDamageLocked[player1.UserId] = false
			duelDamageLocked[player2.UserId] = false
			print("[DuelHandler][DEBUG] duelDamageLocked set to false for", player1.UserId, player2.UserId)
		else
			print("[DuelHandler][DEBUG] Players not in duel at countdown end. Not unlocking damage.")
		end
	end)

	   return true
end

-- End a duel between two players
-- Reason can be: "death", "different_maps", "safe_zone", "left_game", or nil for normal end
function DuelHandler.EndDuel(player1UserId, player2UserId, winnerId, reason)
	-- Remove duel tracking
	activeDuels[player1UserId] = nil
	activeDuels[player2UserId] = nil
	duelDamageLocked[player1UserId] = nil
	duelDamageLocked[player2UserId] = nil
	
	local player1 = Players:GetPlayerByUserId(player1UserId)
	local player2 = Players:GetPlayerByUserId(player2UserId)
	
	-- Unanchor, reset stats, destroy VFX, and restore ragdoll (respawn) for both players
	local function resetPlayerState(player)
		if not player then return end
		local char = player.Character
		local needsRespawn = false
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				print("[DuelHandler] Unanchored " .. player.Name)
			end
			-- If character has no Humanoid or is missing joints, respawn
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or not char:FindFirstChild("Head") or not char:FindFirstChild("HumanoidRootPart") then
				needsRespawn = true
			end
			-- Destroy FinishingVFX if present
			local vfx = char:FindFirstChild("FinishingVFX")
			if vfx then
				vfx:Destroy()
				print("[DuelHandler] Destroyed FinishingVFX for " .. player.Name)
			end
		end
		-- Reset stats for default PVP
		if player:FindFirstChild("Stats") then
			local stats = player.Stats
			if stats:FindFirstChild("DuelState") then
				stats.DuelState.Value = false
				print("[DuelHandler] Reset DuelState for " .. player.Name)
			end
			if stats:FindFirstChild("DuelOpponent") then
				stats.DuelOpponent.Value = ""
				print("[DuelHandler] Reset DuelOpponent for " .. player.Name)
			end
			-- Add more stat resets here as needed
		end
		-- If ragdolled, respawn the player
		if needsRespawn then
			print("[DuelHandler] Respawning player after ragdoll:", player.Name)
			player:LoadCharacter()
			-- Clear initializing flag after respawn so PVP works
			local DamageManager = require(script.Parent.Parent.Combat.DamageManager)
			player.CharacterAdded:Once(function()
				task.wait(0.1)
				DamageManager.ClearPlayerInitializing(player)
			end)
		end
	end
	resetPlayerState(player1)
	resetPlayerState(player2)
	
	if player1 and player2 then
		print("[DuelHandler] Duel ended between " .. player1.Name .. " and " .. player2.Name)
		
		-- Update stats
		if winnerId then
			if not duelStats[winnerId] then
				duelStats[winnerId] = {wins = 0, losses = 0, totalDuels = 0}
			end
			duelStats[winnerId].wins = duelStats[winnerId].wins + 1
			duelStats[winnerId].totalDuels = duelStats[winnerId].totalDuels + 1
			
			local loserId = (winnerId == player1UserId) and player2UserId or player1UserId
			if not duelStats[loserId] then
				duelStats[loserId] = {wins = 0, losses = 0, totalDuels = 0}
			end
			duelStats[loserId].losses = duelStats[loserId].losses + 1
			duelStats[loserId].totalDuels = duelStats[loserId].totalDuels + 1
		else
			print("[DuelHandler] Duel ended as a draw (no winner)")
		end
		
		-- Notify both players
		local duelEndedEvent = ReplicatedStorage:FindFirstChild("DuelEndedEvent")
		if duelEndedEvent then
			duelEndedEvent:FireClient(player1, winnerId, reason)
			duelEndedEvent:FireClient(player2, winnerId, reason)
			print("[DuelHandler] Notified both players of duel end (reason: " .. tostring(reason) .. ")")
		end
	task.delay(2.5, function()
		-- Only re-equip the winner's weapons, not the loser's, for safety
	local equippedWeapons = DuelHandler._lastEquippedWeapons or {}
	if winnerId then
		local winnerPlayer = Players:GetPlayerByUserId(winnerId)
		local info = equippedWeapons[winnerId]
		if winnerPlayer and info then
			print("[DuelHandler][DEBUG] Re-equipping weapons for winner:", winnerPlayer.Name, "primary:", info.primary, "secondary:", info.secondary)
			if info.primary and info.primary ~= "" then
				local InventoryManager = require(script.Parent.Parent.Items.InventoryManager)
				InventoryManager.setEquippedWeapon(winnerPlayer, (info.primary:match("^(.-)_") or info.primary), info.primary)
				print("[DuelHandler][DEBUG] Primary weapon re-equipped for", winnerPlayer.Name, info.primary)
			end
			local SecondaryWeaponHandler = require(script.Parent.Parent.Combat.SecondaryWeaponHandler)
			if info.secondary and info.secondary ~= "" and SecondaryWeaponHandler.EquipSecondaryWeaponById then
				local ok, err = pcall(function()
					SecondaryWeaponHandler:EquipSecondaryWeaponById(winnerPlayer, info.secondary)
				end)
				if not ok then
					warn("[DuelHandler][DEBUG] Failed to re-equip secondary weapon:", err)
				else
					print("[DuelHandler][DEBUG] Secondary weapon re-equipped for", winnerPlayer.Name)
				end
			end
		end
	end
	DuelHandler._lastEquippedWeapons = nil
	end)
	end
end

-- Check if two players are dueling each other
-- Check if a player's damage is locked due to duel countdown
function DuelHandler.IsDuelDamageLocked(userId)
    local locked = duelDamageLocked[userId]
    print("[DuelHandler][DEBUG] IsDuelDamageLocked for userId", userId, "=", tostring(locked))
    return locked == true
end
function DuelHandler.ArePlayersDueling(player1UserId, player2UserId)
	return activeDuels[player1UserId] == player2UserId
end

-- Get duel opponent for a player
function DuelHandler.GetDuelOpponent(playerUserId)
	local opponentUserId = activeDuels[playerUserId]
	if opponentUserId then
		return Players:GetPlayerByUserId(opponentUserId)
	end
	return nil
end

-- Handle duel response
local function handleDuelResponse(invitedPlayer, inviterPlayer, response)
	-- Check if invitation still exists
	if activeDuelInvitations[invitedPlayer] ~= inviterPlayer then
		warn("[DuelHandler] No active duel invitation found or invitation expired")
		return false
	end
	
	-- Remove the invitation
	activeDuelInvitations[invitedPlayer] = nil
	
	if response == "Accept" then
		print("[DuelHandler] " .. invitedPlayer.Name .. " accepted duel from " .. inviterPlayer.Name)
		-- Start the duel
		return startDuel(inviterPlayer, invitedPlayer)
	elseif response == "Decline" then
		print("[DuelHandler] " .. invitedPlayer.Name .. " declined duel from " .. inviterPlayer.Name)
		-- Could notify inviter that invitation was declined
		return false
	end
	
	return false
end

-- Handle player death during duel
local function handlePlayerDeathInDuel(player)
	local opponentUserId = activeDuels[player.UserId]
	if opponentUserId then
		print("[DuelHandler] Player " .. player.Name .. " died during duel")
		-- End the duel with opponent as winner
		DuelHandler.EndDuel(player.UserId, opponentUserId, opponentUserId, "death")
	end
end

-- Handle player leaving during duel
local function handlePlayerLeaving(player)
	-- Remove any pending invitations
	activeDuelInvitations[player] = nil
	
	-- Check for invitations sent by this player
	for invited, inviter in pairs(activeDuelInvitations) do
		if inviter == player then
			activeDuelInvitations[invited] = nil
		end
	end
	
	-- Handle duel if player was in one
	local opponentUserId = activeDuels[player.UserId]
	if opponentUserId then
		print("[DuelHandler] Player " .. player.Name .. " left during duel")
		-- End the duel (could count as forfeit)
		DuelHandler.EndDuel(player.UserId, opponentUserId, opponentUserId, "left_game")
	end
end

-- Initialize the DuelHandler
function DuelHandler.Initialize()
	print("[DuelHandler] 🔧 Initializing DuelHandler...")
	
	-- Setup remote events
	local duelInvitationEvent, duelResponseFunction, duelStartedEvent, duelEndedEvent, playerInteractionEvent, duelFinishingEvent, duelFinishingSyncEvent = setupRemoteEvents()
	
	print("[DuelHandler] ✅ Remote events setup complete")
	print("[DuelHandler] - DuelInvitationEvent:", duelInvitationEvent and "FOUND" or "NOT FOUND")
	print("[DuelHandler] - DuelResponseFunction:", duelResponseFunction and "FOUND" or "NOT FOUND")
	print("[DuelHandler] - DuelStartedEvent:", duelStartedEvent and "FOUND" or "NOT FOUND")
	print("[DuelHandler] - DuelEndedEvent:", duelEndedEvent and "FOUND" or "NOT FOUND")
	print("[DuelHandler] - PlayerInteractionEvent:", playerInteractionEvent and "FOUND" or "NOT FOUND")
	
	-- Listen for player interactions (duel invites)
	playerInteractionEvent.OnServerEvent:Connect(function(player, interactionType, targetPlayer)
		print("[DuelHandler] 📨 Received PlayerInteractionEvent")
		print("[DuelHandler] - Player:", player and player.Name or "NIL")
		print("[DuelHandler] - InteractionType:", interactionType or "NIL")
		print("[DuelHandler] - TargetPlayer:", targetPlayer and targetPlayer.Name or "NIL")
		
		if interactionType == "Duel Invite" then
			print("[DuelHandler] ⚔️ Processing Duel Invite from " .. player.Name .. " to " .. targetPlayer.Name)
			sendDuelInvitation(player, targetPlayer)
		else
			print("[DuelHandler] ℹ️ Not a Duel Invite, ignoring (type: " .. tostring(interactionType) .. ")")
		end
	end)

	print("[DuelHandler] ✅ PlayerInteractionEvent listener connected")

	-- Listen for DuelFinishingSyncEvent from winner and relay to loser
	duelFinishingSyncEvent.OnServerEvent:Connect(function(winnerPlayer, opponentUserId)
		print("[DuelHandler][FinishingSync] Received from winner:", winnerPlayer and winnerPlayer.Name, "for opponentUserId:", opponentUserId)
		if not opponentUserId then print("[DuelHandler][FinishingSync] opponentUserId is nil!") return end
		local loserPlayer = Players:GetPlayerByUserId(opponentUserId)
		print("[DuelHandler][FinishingSync] loserPlayer:", loserPlayer and loserPlayer.Name or "nil")
		if loserPlayer and loserPlayer.Character then
			print("[DuelHandler][FinishingSync] Relaying to loser:", loserPlayer.Name)
			-- Unanchor root and apply knockback
			local rootPart = loserPlayer.Character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.Anchored = false
				local backward = -rootPart.CFrame.LookVector
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Velocity = backward * 60 + Vector3.new(0, 30, 0)
				bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bodyVelocity.P = 1e4
				bodyVelocity.Parent = rootPart
				game:GetService("Debris"):AddItem(bodyVelocity, 0.5)
				task.delay(0.5, function()
					if loserPlayer.Character and loserPlayer.Character.Parent then
						-- Set health to 0 to ensure death event triggers
						local humanoid = loserPlayer.Character:FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.Health > 0 then
							humanoid.Health = 0
						end
						loserPlayer.Character:BreakJoints()
					end
				end)
			end
			duelFinishingSyncEvent:FireClient(loserPlayer)
		else
			print("[DuelHandler][FinishingSync] Loser player not found for userId:", opponentUserId)
		end
	end)
	
	-- Handle duel responses
	duelResponseFunction.OnServerInvoke = function(player, inviterPlayer, response)
		print("[DuelHandler] Received duel response from " .. player.Name .. ": " .. response)
		return handleDuelResponse(player, inviterPlayer, response)
	end
	
	-- Listen for player deaths
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				handlePlayerDeathInDuel(player)
			end)
		end)
	end)
	
	-- Monitor map changes during duels - end duel as draw if players go to different maps
	task.spawn(function()
		while true do
			task.wait(1) -- Check every second
			
			-- Check all active duels
			local checkedPairs = {}
			for userId1, userId2 in pairs(activeDuels) do
				-- Skip if we already checked this pair
				local pairKey = math.min(userId1, userId2) .. "_" .. math.max(userId1, userId2)
				if checkedPairs[pairKey] then
					continue
				end
				checkedPairs[pairKey] = true
				
				local player1 = Players:GetPlayerByUserId(userId1)
				local player2 = Players:GetPlayerByUserId(userId2)
				
				if player1 and player2 then
					local stats1 = player1:FindFirstChild("Stats")
					local stats2 = player2:FindFirstChild("Stats")
					
					if stats1 and stats2 then
						local map1 = stats1:FindFirstChild("PlayerMap")
						local map2 = stats2:FindFirstChild("PlayerMap")
						
						if map1 and map2 and map1.Value ~= map2.Value then
							print("[DuelHandler] Players in different maps - ending duel as draw")
							print("[DuelHandler] " .. player1.Name .. " in: " .. map1.Value)
							print("[DuelHandler] " .. player2.Name .. " in: " .. map2.Value)
							-- End duel with no winner (draw)
						DuelHandler.EndDuel(userId1, userId2, nil, "different_maps")
						end
					end
				end
			end
		end
	end)
	
	-- Listen for players leaving
	Players.PlayerRemoving:Connect(function(player)
		handlePlayerLeaving(player)
	end)
	
	print("[DuelHandler] Initialization complete")
end

return DuelHandler
