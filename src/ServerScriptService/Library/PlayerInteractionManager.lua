-- PlayerInteractionManager.lua
-- Server-side handler for player interactions
-- Manages RemoteEvent communication between client and server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PartyHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("PartyHandler"))

local PlayerInteractionManager = {}

-- Get or create the RemoteEvent for player interactions
local function getPlayerInteractionEvent()
	local event = ReplicatedStorage:FindFirstChild("PlayerInteractionEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PlayerInteractionEvent"
		event.Parent = ReplicatedStorage
	end
	return event
end

-- Get or create the RemoteEvent for party invitations
local function getPartyInvitationEvent()
	local event = ReplicatedStorage:FindFirstChild("PartyInvitationEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PartyInvitationEvent"
		event.Parent = ReplicatedStorage
	end
	return event
end

-- Get or create the RemoteEvent for party created notification
local function getPartyCreatedEvent()
	local event = ReplicatedStorage:FindFirstChild("PartyCreatedEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PartyCreatedEvent"
		event.Parent = ReplicatedStorage
	end
	return event
end

-- Get or create the RemoteEvent for party member left notification
local function getPartyMemberLeftEvent()
	local event = ReplicatedStorage:FindFirstChild("PartyMemberLeftEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PartyMemberLeftEvent"
		event.Parent = ReplicatedStorage
	end
	return event
end

-- Get or create the RemoteEvent for party actions (leave/kick/disband)
local function getPartyActionEvent()
	local event = ReplicatedStorage:FindFirstChild("PartyActionEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PartyActionEvent"
		event.Parent = ReplicatedStorage
	end
	return event
end

-- Get or create the RemoteFunction for party response
local function getPartyResponseFunction()
	local func = ReplicatedStorage:FindFirstChild("PartyResponseFunction")
	if not func then
		func = Instance.new("RemoteFunction")
		func.Name = "PartyResponseFunction"
		func.Parent = ReplicatedStorage
	end
	return func
end

-- Initialize the handler
function PlayerInteractionManager.Initialize()
	local playerInteractionEvent = getPlayerInteractionEvent()
	local partyInvitationEvent = getPartyInvitationEvent()
	local partyCreatedEvent = getPartyCreatedEvent()
	local partyMemberLeftEvent = getPartyMemberLeftEvent()
	local partyResponseFunction = getPartyResponseFunction()
	local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("PartyDataStore"))
	
	-- Listen for interaction requests from clients
	playerInteractionEvent.OnServerEvent:Connect(function(clickingPlayer, interactionType, targetPlayer)
		print("[PlayerInteractionManager] 📨 Received interaction from " .. clickingPlayer.Name)
		print("[PlayerInteractionManager] 🎯 Interaction Type: " .. tostring(interactionType))
		print("[PlayerInteractionManager] 👤 Target Player: " .. targetPlayer.Name)
		
		-- Validate players
		if not clickingPlayer or not clickingPlayer.Parent then
			print("[PlayerInteractionManager] ⚠️ Clicking player no longer exists")
			return
		end
		
		if not targetPlayer or not targetPlayer.Parent then
			print("[PlayerInteractionManager] ⚠️ Target player no longer exists")
			return
		end
		
		-- Handle different interaction types
		if interactionType == "Party Invite" then
			print("[PlayerInteractionManager] 🎪 Sending party invitation to " .. targetPlayer.Name)
			-- Send invitation to target player's client
			partyInvitationEvent:FireClient(targetPlayer, clickingPlayer)
		else
			print("[PlayerInteractionManager] ❓ Unknown interaction type: " .. tostring(interactionType))
		end
	end)
	
	-- Handle party invitation response from client
	partyResponseFunction.OnServerInvoke = function(respondingPlayer, inviterPlayer, response)
		print("[PlayerInteractionManager] 📲 Party response from " .. respondingPlayer.Name)
		print("[PlayerInteractionManager] ✉️ Inviter: " .. inviterPlayer.Name)
		print("[PlayerInteractionManager] 🔔 Response: " .. tostring(response))
		
		if response == "Accept" then
			print("[PlayerInteractionManager] ✅ Party invitation accepted")
			-- Process party acceptance
			local success, memberNames = PartyHandler.InviteParty(inviterPlayer, respondingPlayer)
			if success then
				print("[PlayerInteractionManager] 🎉 Party created successfully with members: " .. table.concat(memberNames, ", "))
				
				-- Get the party to notify ALL members with fresh data
				local party = PartyDataStore.GetParty(inviterPlayer.UserId)
				if party then
					-- Build fresh member list for THIS update
					local freshMemberNames = {}
					for _, member in ipairs(party.members) do
						if member and member.Parent then
							table.insert(freshMemberNames, member.Name)
							print("[PlayerInteractionManager] 📝 Fresh member in list: " .. member.Name)
						end
					end
					
					print("[PlayerInteractionManager] 🔔 Fresh member list to broadcast: " .. table.concat(freshMemberNames, ", "))
					print("[PlayerInteractionManager] 👑 Party leader: " .. party.leader.Name)
					
					-- Notify ALL party members (including the new member) with FRESH member list and leader name
					for _, member in ipairs(party.members) do
						if member and member.Parent then
							partyCreatedEvent:FireClient(member, freshMemberNames, party.leader.Name)
							print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " with fresh member list and leader info")
						end
					end
				end
				
				return true, memberNames
			else
				print("[PlayerInteractionManager] ❌ Failed to create party")
				return false, nil
			end
		elseif response == "Decline" then
			print("[PlayerInteractionManager] ❌ Party invitation declined")
			return false, nil
		end
	end
	
	-- Handle player leaving - notify remaining party members
	Players.PlayerRemoving:Connect(function(leftPlayer)
		print("[PlayerInteractionManager] 👋 Player leaving: " .. leftPlayer.Name)
		
		-- Get the party this player was in
		local party = PartyDataStore.GetParty(leftPlayer.UserId)
		if party then
			print("[PlayerInteractionManager] 🎪 Notifying remaining party members about " .. leftPlayer.Name .. " leaving")
			
			-- Get updated member list (excluding the left player)
			local updatedMembers = {}
			for _, member in ipairs(party.members) do
				if member ~= leftPlayer and member.Parent then
					table.insert(updatedMembers, member.Name)
				end
			end
			
			-- Notify all remaining party members with updated member list
			for _, member in ipairs(party.members) do
				if member ~= leftPlayer and member.Parent then
					partyMemberLeftEvent:FireClient(member, updatedMembers)
					print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " with updated member list: " .. table.concat(updatedMembers, ", "))
				end
			end
		end
	end)
	
	-- Handle party actions (leave/kick/disband)
	local partyActionEvent = getPartyActionEvent()
	partyActionEvent.OnServerEvent:Connect(function(actionPlayer, action, targetMemberName)
		print("[PlayerInteractionManager] 🎬 Party action from " .. actionPlayer.Name .. ": " .. action)
		
		-- Validate player still exists
		if not actionPlayer or not actionPlayer.Parent then
			print("[PlayerInteractionManager] ⚠️ Action player no longer exists")
			return
		end
		
		-- Get the player's current party
		local party = PartyDataStore.GetParty(actionPlayer.UserId)
		if not party then
			print("[PlayerInteractionManager] ⚠️ Player " .. actionPlayer.Name .. " is not in a party")
			return
		end
		
		-- Determine if player is the leader
		local isLeader = (party.leader == actionPlayer)
		print("[PlayerInteractionManager] 👑 Is leader: " .. tostring(isLeader))
		
		if action == "leave" then
			print("[PlayerInteractionManager] 🚪 Player " .. actionPlayer.Name .. " is leaving the party")
			
			-- If leader is leaving, disband entire party
			if isLeader then
				print("[PlayerInteractionManager] 💔 Leader left - disbanding party")
				-- Notify all members that party is disbanded
				for _, member in ipairs(party.members) do
					if member and member.Parent then
						partyMemberLeftEvent:FireClient(member, {})  -- Empty list signals party disbanded
						print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " that party disbanded")
					end
				end
				-- Disband the party
				PartyDataStore.DisbandParty(party.id)
			else
				-- Regular member leaving - remove just that member
				PartyDataStore.RemovePlayerFromParty(actionPlayer.UserId)
				
				-- Get updated member list
				local updatedMembers = {}
				for _, member in ipairs(party.members) do
					if member ~= actionPlayer and member.Parent then
						table.insert(updatedMembers, member.Name)
					end
				end
				
				-- Notify remaining members
				for _, member in ipairs(party.members) do
					if member ~= actionPlayer and member.Parent then
						partyMemberLeftEvent:FireClient(member, updatedMembers)
						print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " that " .. actionPlayer.Name .. " left")
					end
				end
				
				print("[PlayerInteractionManager] ✅ " .. actionPlayer.Name .. " removed from party")
			end
			
		elseif action == "kick" then
			-- Only leader can kick
			if not isLeader then
				print("[PlayerInteractionManager] ⚠️ Non-leader " .. actionPlayer.Name .. " tried to kick a member")
				return
			end
			
			print("[PlayerInteractionManager] 🔨 Leader " .. actionPlayer.Name .. " is kicking " .. targetMemberName)
			
			-- Find the target member to kick
			local targetMember = nil
			for _, member in ipairs(party.members) do
				if member and member.Name == targetMemberName then
					targetMember = member
					break
				end
			end
			
			if not targetMember then
				print("[PlayerInteractionManager] ⚠️ Target member " .. targetMemberName .. " not found in party")
				return
			end
			
			-- Remove the kicked member
			PartyDataStore.RemovePlayerFromParty(targetMember.UserId)
			
			-- Get updated member list
			local updatedMembers = {}
			for _, member in ipairs(party.members) do
				if member ~= targetMember and member.Parent then
					table.insert(updatedMembers, member.Name)
				end
			end
			
			-- Notify the kicked member with empty list so they hide their UI
			if targetMember and targetMember.Parent then
				partyMemberLeftEvent:FireClient(targetMember, {})
				print("[PlayerInteractionManager] 📢 Notified " .. targetMemberName .. " that they were kicked (party list hidden)")
			end
			
			-- Notify all remaining members (including leader)
			for _, member in ipairs(party.members) do
				if member ~= targetMember and member.Parent then
					partyMemberLeftEvent:FireClient(member, updatedMembers)
					print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " that " .. targetMemberName .. " was kicked")
				end
			end
			
			print("[PlayerInteractionManager] ✅ " .. targetMemberName .. " has been kicked from party")
			
		elseif action == "disband" then
			-- Only leader can disband
			if not isLeader then
				print("[PlayerInteractionManager] ⚠️ Non-leader " .. actionPlayer.Name .. " tried to disband party")
				return
			end
			
			print("[PlayerInteractionManager] 💔 Leader is disbanding the entire party")
			-- Notify all members that party is disbanded
			for _, member in ipairs(party.members) do
				if member and member.Parent then
					partyMemberLeftEvent:FireClient(member, {})  -- Empty list signals party disbanded
					print("[PlayerInteractionManager] 📢 Notified " .. member.Name .. " that party disbanded")
				end
			end
			-- Disband the party
			PartyDataStore.DisbandParty(party.id)
		else
			print("[PlayerInteractionManager] ⚠️ Unknown party action: " .. action)
		end
	end)
	
	print("[PlayerInteractionManager] ✅ Server handler initialized successfully")
end

return PlayerInteractionManager
