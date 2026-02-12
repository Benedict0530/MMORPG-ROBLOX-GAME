-- PartyDataStore.lua
-- Handles party data management and storage

local Players = game:GetService("Players")

local PartyDataStore = {}

-- In-memory party storage: partyId -> {leader: Player, members: {Player1, Player2...}}
local parties = {}

-- Player to party mapping: playerId -> partyId
local playerPartyMap = {}

-- Party counter for unique IDs
local partyCounter = 0

-- Create a new party with a leader
function PartyDataStore.CreateParty(leaderPlayer)
	if not leaderPlayer or not leaderPlayer.Parent then
		--print("[PartyDataStore] ❌ Invalid leader player")
		return nil
	end
	
	-- Check if player is already in a party
	if playerPartyMap[leaderPlayer.UserId] then
		--print("[PartyDataStore] ⚠️ Player " .. leaderPlayer.Name .. " is already in a party")
		return nil
	end
	
	-- Create new party
	partyCounter = partyCounter + 1
	local partyId = "party_" .. partyCounter
	
	parties[partyId] = {
		leader = leaderPlayer,
		members = {leaderPlayer},
		createdAt = os.time()
	}
	
	playerPartyMap[leaderPlayer.UserId] = partyId
	
	--print("[PartyDataStore] ✅ Party created: " .. partyId .. " with leader: " .. leaderPlayer.Name)
	return partyId
end

-- Invite a player to a party
function PartyDataStore.InviteToParty(leaderPlayer, targetPlayer)
	if not leaderPlayer or not leaderPlayer.Parent then
		--print("[PartyDataStore] ❌ Invalid leader player")
		return false
	end
	
	if not targetPlayer or not targetPlayer.Parent then
		--print("[PartyDataStore] ❌ Invalid target player")
		return false
	end
	
	-- Check if leader is in a party
	local partyId = playerPartyMap[leaderPlayer.UserId]
	if not partyId then
		--print("[PartyDataStore] ⚠️ Leader " .. leaderPlayer.Name .. " is not in a party")
		-- Create a new party for the leader
		partyId = PartyDataStore.CreateParty(leaderPlayer)
		if not partyId then
			return false
		end
	end
	
	local party = parties[partyId]
	if not party then
		--print("[PartyDataStore] ❌ Party not found: " .. partyId)
		return false
	end
	
	-- Check if leader is the actual leader
	if party.leader ~= leaderPlayer then
		--print("[PartyDataStore] ❌ " .. leaderPlayer.Name .. " is not the party leader")
		return false
	end
	
	-- Check if target player is already in a party
	if playerPartyMap[targetPlayer.UserId] then
		--print("[PartyDataStore] ⚠️ Player " .. targetPlayer.Name .. " is already in a party")
		return false
	end
	
	-- Check if target player is already in this party
	for _, member in ipairs(party.members) do
		if member == targetPlayer then
			--print("[PartyDataStore] ⚠️ Player " .. targetPlayer.Name .. " is already in this party")
			return false
		end
	end
	
	-- Add member to party
	table.insert(party.members, targetPlayer)
	playerPartyMap[targetPlayer.UserId] = partyId
	
	--print("[PartyDataStore] ✅ Player " .. targetPlayer.Name .. " invited to party: " .. partyId)
	--print("[PartyDataStore] 👥 Party members: " .. #party.members)
	
	return true
end

-- Get party information
function PartyDataStore.GetParty(playerId)
	local partyId = playerPartyMap[playerId]
	if not partyId then
		return nil
	end
	
	return parties[partyId]
end

-- Get party ID from player
function PartyDataStore.GetPartyId(playerId)
	return playerPartyMap[playerId]
end

-- Check if player is in a party
function PartyDataStore.IsPlayerInParty(playerId)
	return playerPartyMap[playerId] ~= nil
end

-- Get all party members
function PartyDataStore.GetPartyMembers(partyId)
	if not parties[partyId] then
		return nil
	end
	
	return parties[partyId].members
end

-- Get party leader
function PartyDataStore.GetPartyLeader(partyId)
	if not parties[partyId] then
		return nil
	end
	
	return parties[partyId].leader
end

-- Print party info (for debugging)
function PartyDataStore.PrintPartyInfo(partyId)
	if not parties[partyId] then
		--print("[PartyDataStore] ❌ Party not found: " .. partyId)
		return
	end
	
	local party = parties[partyId]
	--print("[PartyDataStore] 📋 Party: " .. partyId)
	--print("[PartyDataStore] 👑 Leader: " .. party.leader.Name)
	--print("[PartyDataStore] 👥 Members: " .. #party.members)
	for i, member in ipairs(party.members) do
		--print("[PartyDataStore]    " .. i .. ". " .. member.Name)
	end
end

-- Remove a player from their party
function PartyDataStore.RemovePlayerFromParty(playerId)
	local partyId = playerPartyMap[playerId]
	if not partyId then
		--print("[PartyDataStore] ⚠️ Player with ID " .. playerId .. " is not in a party")
		return false
	end
	
	local party = parties[partyId]
	if not party then
		--print("[PartyDataStore] ❌ Party not found: " .. partyId)
		return false
	end
	
	-- Find and remove the player from members list
	for i, member in ipairs(party.members) do
		if member.UserId == playerId then
			table.remove(party.members, i)
			--print("[PartyDataStore] ✅ Removed player " .. member.Name .. " from party " .. partyId)
			break
		end
	end
	
	-- Remove player from party mapping
	playerPartyMap[playerId] = nil
	
	-- If no members left, disband the party
	if #party.members == 0 then
		--print("[PartyDataStore] 💔 Party " .. partyId .. " has no members, disbanding")
		parties[partyId] = nil
	end
	
	return true
end

-- Disband an entire party
function PartyDataStore.DisbandParty(partyId)
	if not parties[partyId] then
		--print("[PartyDataStore] ⚠️ Party not found: " .. partyId)
		return false
	end
	
	local party = parties[partyId]
	--print("[PartyDataStore] 💔 Disbanding party: " .. partyId)
	
	-- Remove all members from the party mapping
	for _, member in ipairs(party.members) do
		if member and member.Parent then
			playerPartyMap[member.UserId] = nil
			--print("[PartyDataStore] ✅ Removed " .. member.Name .. " from party mapping")
		else
			--print("[PartyDataStore] ⚠️ Member is invalid or already left")
		end
	end
	
	-- Delete the party
	parties[partyId] = nil
	--print("[PartyDataStore] ✅ Party " .. partyId .. " has been disbanded")
	
	return true
end

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(player)
	local partyId = playerPartyMap[player.UserId]
	if partyId then
		--print("[PartyDataStore] 🚪 Player " .. player.Name .. " is leaving, removing from party: " .. partyId)
		playerPartyMap[player.UserId] = nil
		
		-- Also remove from party members array
		local party = parties[partyId]
		if party then
			for i, member in ipairs(party.members) do
				if member == player then
					table.remove(party.members, i)
					--print("[PartyDataStore] ✅ Removed " .. player.Name .. " from party members array")
					break
				end
			end
			
			-- If no members left, disband the party
			if #party.members == 0 then
				--print("[PartyDataStore] 💔 Party " .. partyId .. " has no members, disbanding")
				parties[partyId] = nil
			end
		end
	end
end)

return PartyDataStore
