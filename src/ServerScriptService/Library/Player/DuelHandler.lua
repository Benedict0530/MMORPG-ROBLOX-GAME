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
	
	-- Event for player interaction (duel invite)
	local playerInteractionEvent = ReplicatedStorage:FindFirstChild("PlayerInteractionEvent")
	if not playerInteractionEvent then
		playerInteractionEvent = Instance.new("RemoteEvent")
		playerInteractionEvent.Name = "PlayerInteractionEvent"
		playerInteractionEvent.Parent = ReplicatedStorage
		print("[DuelHandler] Created PlayerInteractionEvent")
	end
	
	return duelInvitationEvent, duelResponseFunction, duelStartedEvent, duelEndedEvent, playerInteractionEvent
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
		   -- Unlock damage after countdown
		   duelDamageLocked[player1.UserId] = nil
		   duelDamageLocked[player2.UserId] = nil
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
	
	-- Unanchor both players' HumanoidRootParts
	if player1 and player1.Character then
		local root1 = player1.Character:FindFirstChild("HumanoidRootPart")
		if root1 then
			root1.Anchored = false
			print("[DuelHandler] Unanchored " .. player1.Name)
		end
	end
	
	if player2 and player2.Character then
		local root2 = player2.Character:FindFirstChild("HumanoidRootPart")
		if root2 then
			root2.Anchored = false
			print("[DuelHandler] Unanchored " .. player2.Name)
		end
	end
	
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
	end
end

-- Check if two players are dueling each other
-- Check if a player's damage is locked due to duel countdown
function DuelHandler.IsDuelDamageLocked(userId)
	return duelDamageLocked[userId] and true or false
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
	local duelInvitationEvent, duelResponseFunction, duelStartedEvent, duelEndedEvent, playerInteractionEvent = setupRemoteEvents()
	
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
