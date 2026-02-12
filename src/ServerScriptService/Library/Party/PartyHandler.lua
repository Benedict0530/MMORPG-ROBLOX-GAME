-- PartyHandler.lua
-- Module for handling party-related interactions

local ServerScriptService = game:GetService("ServerScriptService")
local PartyDataStore = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Party"):WaitForChild("PartyDataStore"))

local PartyHandler = {}

-- Send party invite to another player
function PartyHandler.InviteParty(clickingPlayer, targetPlayer)
	--print("[PartyHandler] 📨 Party Invite Function Called")
	--print("[PartyHandler] From: " .. clickingPlayer.Name .. " To: " .. targetPlayer.Name)
	
	-- Check if target player is already in a party
	if PartyDataStore.IsPlayerInParty(targetPlayer.UserId) then
		--print("[PartyHandler] ❌ Player " .. targetPlayer.Name .. " is already in a party")
		return false, nil
	end
	
	-- Invite player to party (will create party if needed)
	local success = PartyDataStore.InviteToParty(clickingPlayer, targetPlayer)
	
	if success then
		--print("[PartyHandler] ✅ Party Invite Processed Successfully")
		
		-- Get party info for logging
		local partyId = PartyDataStore.GetPartyId(clickingPlayer.UserId)
		PartyDataStore.PrintPartyInfo(partyId)
		
		-- Get party members list
		local party = PartyDataStore.GetParty(clickingPlayer.UserId)
		if party then
			local memberNames = {}
			for _, member in ipairs(party.members) do
				table.insert(memberNames, member.Name)
			end
			return true, memberNames
		end
	else
		--print("[PartyHandler] ❌ Party Invite Failed")
	end
	
	return false, nil
end

return PartyHandler

