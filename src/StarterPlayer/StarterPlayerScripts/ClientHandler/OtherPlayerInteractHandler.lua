-- OtherPlayerInteractHandler.client.lua
-- Client-side handler for detecting player clicks
-- Works on both PC (mouse) and mobile (touch)
local OtherPlayerInteractHandler = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")
local playerInteractionUi = gameGui:WaitForChild("PlayerInteraction")
local playerButton = playerInteractionUi:WaitForChild("PlayerButton")
local playerNameLabel = playerButton:WaitForChild("PlayerNameLabel")
local invitePartyButton = playerButton:WaitForChild("InvitePartyButton")
local inviteDuelButton = playerButton:WaitForChild("InviteDuelButton")

-- Get RemoteEvent for player interactions
-- Center-screen message utility
local function showCenterScreenMessage(text, duration)
	duration = duration or 2
	local messageGui = playerGui:FindFirstChild("CenterScreenMessage")
	if not messageGui then
		messageGui = Instance.new("ScreenGui")
		messageGui.Name = "CenterScreenMessage"
		messageGui.ResetOnSpawn = false
		messageGui.Parent = playerGui
		local label = Instance.new("TextLabel")
		label.Name = "MessageLabel"
		label.Size = UDim2.new(0.6, 0, 0.1, 0)
		label.Position = UDim2.new(0.2, 0, 0.45, 0)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(30,30,30)
		label.TextColor3 = Color3.fromRGB(255,255,255)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Visible = false
		label.Parent = messageGui
	end
	local label = messageGui:FindFirstChild("MessageLabel")
	if label then
		label.Text = text
		label.Visible = true
		label.BackgroundTransparency = 0.3
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.2
		-- Fade out after duration
		task.spawn(function()
			task.wait(duration)
			if label then
				for i=0,1,0.1 do
					label.TextTransparency = i
					label.TextStrokeTransparency = 0.2 + i*0.8
					label.BackgroundTransparency = 0.3 + i*0.7
					task.wait(0.03)
				end
				label.Visible = false
			end
		end)
	end
end
local function getPlayerInteractionEvent()
	return ReplicatedStorage:WaitForChild("PlayerInteractionEvent")
end

-- Get RemoteFunction for party responses
local function getPartyResponseFunction()
	return ReplicatedStorage:WaitForChild("PartyResponseFunction")
end

-- Get RemoteEvent for party creation notification
local function getPartyCreatedEvent()
	return ReplicatedStorage:WaitForChild("PartyCreatedEvent")
end

-- Get RemoteEvent for party member left notification
local function getPartyMemberLeftEvent()
	return ReplicatedStorage:WaitForChild("PartyMemberLeftEvent")
end

-- Get RemoteEvent for party action (leave/kick)
local function getPartyActionEvent()
	return ReplicatedStorage:WaitForChild("PartyActionEvent")
end

-- Get RemoteEvent for duel invitations
local function getDuelInvitationEvent()
	return ReplicatedStorage:WaitForChild("DuelInvitationEvent")
end

-- Get RemoteFunction for duel responses
local function getDuelResponseFunction()
	return ReplicatedStorage:WaitForChild("DuelResponseFunction")
end

-- Get RemoteEvent for duel started
local function getDuelStartedEvent()
	return ReplicatedStorage:WaitForChild("DuelStartedEvent")
end

-- Get RemoteEvent for duel ended
local function getDuelEndedEvent()
	return ReplicatedStorage:WaitForChild("DuelEndedEvent")
end

-- Shared function to handle player click
local clickDebounce = false
local CLICK_DEBOUNCE = 0.3
local currentSelectedPlayer = nil

local function hidePlayerInteractionUI()
	playerInteractionUi.Visible = false
	currentSelectedPlayer = nil
end

local function handlePlayerClick(targetPart)
	-- Don't process if debounce is active
	if clickDebounce then return end
	
	if not targetPart then 
		--print("[OtherPlayerInteractHandler.client] DEBUG: No target part")
		return 
	end
	
	--print("[OtherPlayerInteractHandler.client] DEBUG: Clicked on " .. targetPart.Name)
	
	-- Find humanoid parent
	local character = targetPart.Parent
	local searchDepth = 0
	while character and not character:FindFirstChild("Humanoid") do
		searchDepth = searchDepth + 1
		character = character.Parent
		if searchDepth > 10 then break end
	end
	
	if not character or not character:FindFirstChild("Humanoid") then
		--print("[OtherPlayerInteractHandler.client] DEBUG: Not a player character")
		return
	end
	
	-- Find player from character
	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if not targetPlayer then
		--print("[OtherPlayerInteractHandler.client] DEBUG: Character is not owned by any player")
		return
	end
	
	-- Prevent clicking own character
	if targetPlayer == player then
		--print("[OtherPlayerInteractHandler.client] DEBUG: Clicked on own character")
		return
	end
	
	-- Prevent NPC clicking
	if character:GetAttribute("IsNPC") then
		--print("[OtherPlayerInteractHandler.client] DEBUG: Target is an NPC")
		return
	end
	
	-- Player clicked on another player - print to client
	--print("[OtherPlayerInteractHandler.client] 🖱️ You clicked on player: " .. targetPlayer.Name)
	
	-- Check if clicking the same player again - toggle UI off
	if currentSelectedPlayer == targetPlayer then
		hidePlayerInteractionUI()
		--print("[OtherPlayerInteractHandler.client] 👆 Same player clicked - hiding UI")
		return
	end
	
	-- Update UI with player name and show it
	playerNameLabel.Text = targetPlayer.Name
	playerInteractionUi.Visible = true
	currentSelectedPlayer = targetPlayer
	--print("[OtherPlayerInteractHandler.client] ✅ Showing interaction UI for: " .. targetPlayer.Name)
	
	-- Prevent rapid clicks
	clickDebounce = true
	task.delay(CLICK_DEBOUNCE, function() 
		clickDebounce = false 
	end)
end

-- Detect player click on humanoid - Mouse input (PC)
local function setupMouseTargetDetection()
	-- Listen for mouse clicks on players
	mouse.Button1Down:Connect(function()
		--print("[OtherPlayerInteractHandler.client] DEBUG: Mouse clicked")
		-- Check if mouse is over something
		if mouse.Target == nil then 
			--print("[OtherPlayerInteractHandler.client] DEBUG: Mouse.Target is nil")
			return 
		end
		
		--print("[OtherPlayerInteractHandler.client] DEBUG: Mouse.Target = " .. mouse.Target.Name)
		handlePlayerClick(mouse.Target)
	end)
	
	-- Monitor distance to selected player
	RunService.Heartbeat:Connect(function()
		if not currentSelectedPlayer or not currentSelectedPlayer.Character then
			hidePlayerInteractionUI()
			return
		end
		
		local selectedRoot = currentSelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		
		if not selectedRoot or not myRoot then
			hidePlayerInteractionUI()
			return
		end
		
		-- Check if player is more than 30 studs away
		local distance = (selectedRoot.Position - myRoot.Position).Magnitude
		if distance > 30 then
			hidePlayerInteractionUI()
			--print("[OtherPlayerInteractHandler.client] 📏 Player too far away (distance: " .. math.floor(distance) .. " studs)")
		end
	end)
	
	-- Handle player button click
	playerButton.MouseButton1Click:Connect(function()
		if currentSelectedPlayer then
			--print("[OtherPlayerInteractHandler.client] 🎯 Player button clicked for: " .. currentSelectedPlayer.Name)
			--print("[OtherPlayerInteractHandler.client] Button Action: Interacting with " .. currentSelectedPlayer.Name)
			
			-- Toggle invite buttons visibility
			if invitePartyButton.Visible or inviteDuelButton.Visible then
				invitePartyButton.Visible = false
				inviteDuelButton.Visible = false
				--print("[OtherPlayerInteractHandler.client] 🚫 Invite buttons hidden")
			else
				invitePartyButton.Visible = true
				inviteDuelButton.Visible = true
				--print("[OtherPlayerInteractHandler.client] ✅ Invite buttons shown")
			end
		else
			--print("[OtherPlayerInteractHandler.client] ⚠️ Button clicked but no player selected")
		end
	end)
	
	-- Handle invite party button click
	invitePartyButton.MouseButton1Click:Connect(function()
		print("[OtherPlayerInteractHandler.client] 👆 Party invite button clicked!")
		print("[OtherPlayerInteractHandler.client] currentSelectedPlayer:", currentSelectedPlayer and currentSelectedPlayer.Name or "NIL")
		
		if currentSelectedPlayer then
			-- Check if local player is in a party and not leader
			local partyUI = gameGui:FindFirstChild("PartyUI")
			local partyList = partyUI and partyUI:FindFirstChild("PartyList")
			local title = partyUI and partyUI:FindFirstChild("Title")
			local isInParty = partyList and partyList.Visible
			local isLeader = false
			if isInParty and title and title.Visible and title.Text:find(player.Name) then
				isLeader = true
			end
			if isInParty and not isLeader then
				print("[OtherPlayerInteractHandler.client] ⚠️ Player is in party but not leader")
				showCenterScreenMessage("Please ask the party leader to invite.")
				return
			end
			print("[OtherPlayerInteractHandler.client] 📨 Sending Party Invite to server...")
			print("[OtherPlayerInteractHandler.client] Target:", currentSelectedPlayer.Name)
			-- Fire event to server with interaction type and target player
			local playerInteractionEvent = getPlayerInteractionEvent()
			playerInteractionEvent:FireServer("Party Invite", currentSelectedPlayer)
			-- Hide both invite buttons
			invitePartyButton.Visible = false
			inviteDuelButton.Visible = false
			print("[OtherPlayerInteractHandler.client] ✅ Party Invite sent to server")
		else
			print("[OtherPlayerInteractHandler.client] ⚠️ No player selected for party invite")
		end
	end)
	
	-- Handle invite duel button click
	inviteDuelButton.MouseButton1Click:Connect(function()
		print("[OtherPlayerInteractHandler.client] 👆 Duel invite button clicked!")
		print("[OtherPlayerInteractHandler.client] currentSelectedPlayer:", currentSelectedPlayer and currentSelectedPlayer.Name or "NIL")
		
		if currentSelectedPlayer then
			print("[OtherPlayerInteractHandler.client] ⚔️ Sending Duel Invite to server...")
			print("[OtherPlayerInteractHandler.client] Target:", currentSelectedPlayer.Name)
			-- Fire event to server with interaction type and target player
			local playerInteractionEvent = getPlayerInteractionEvent()
			playerInteractionEvent:FireServer("Duel Invite", currentSelectedPlayer)
			-- Hide both invite buttons
			invitePartyButton.Visible = false
			inviteDuelButton.Visible = false
			print("[OtherPlayerInteractHandler.client] ✅ Duel Invite sent to server")
		else
			print("[OtherPlayerInteractHandler.client] ⚠️ No player selected for duel invite")
		end
	end)
end

-- Setup party creation listener (for both inviter and invited player)
local function setupPartyCreationListener()
	local partyCreatedEvent = getPartyCreatedEvent()
	local partyMemberLeftEvent = getPartyMemberLeftEvent()
	local partyActionEvent = getPartyActionEvent()
	
	-- Get party UI elements
	local partyUI = gameGui:WaitForChild("PartyUI")
	local partyList = partyUI:WaitForChild("PartyList")
	local playerTemplate = partyList:WaitForChild("PlayerTemplate")
    local Title = partyUI:WaitForChild("Title")
	local leaveButton = partyUI:WaitForChild("Leave")
	local kickButton = partyUI:WaitForChild("Kick")
	
	-- Track individual player templates by member name
	local memberTemplates = {}
	local memberClickConnections = {}  -- Track click connections for each member
	
	-- Track active member left connection to disconnect old ones
	local memberLeftConnection
	
	-- Track party info
	local currentPartyLeader = nil
	local currentPlayerRole = nil  -- "leader" or "member"
	local selectedMemberForAction = nil
	
	-- Function to handle member template click
	local function handleMemberTemplateClick(memberName)
		--print("[OtherPlayerInteractHandler.client] 🖱️ Clicked on party member: " .. memberName)
		
		-- Check if clicking the same member - toggle button visibility
		if selectedMemberForAction == memberName then
			--print("[OtherPlayerInteractHandler.client] 🔄 Toggling button visibility for: " .. memberName)
			-- Only toggle the relevant button
			if memberName == player.Name then
				-- Toggling self click - only toggle leave button
				leaveButton.Visible = not leaveButton.Visible
				--print("[OtherPlayerInteractHandler.client] 👁️ Leave button visible: " .. tostring(leaveButton.Visible))
			else
				-- Toggling other member click (leader only) - only toggle kick button
				kickButton.Visible = not kickButton.Visible
				--print("[OtherPlayerInteractHandler.client] 👁️ Kick button visible: " .. tostring(kickButton.Visible))
			end
			return
		end
		
		-- Check if player can click this member
		local canClickMember = false
		
		if currentPlayerRole == "leader" then
			-- Leader can click any member
			canClickMember = true
			--print("[OtherPlayerInteractHandler.client] 👑 Leader can click any member")
		elseif currentPlayerRole == "member" then
			-- Member can only click themselves
			if memberName == player.Name then
				canClickMember = true
				--print("[OtherPlayerInteractHandler.client] 👤 Member can only click their own template")
			else
				--print("[OtherPlayerInteractHandler.client] ❌ Members can only click their own template")
				return
			end
		end
		
		if canClickMember then
			selectedMemberForAction = memberName
			--print("[OtherPlayerInteractHandler.client] ✅ Selected member for action: " .. selectedMemberForAction)
			
			-- Show appropriate buttons based on who is clicking
			if memberName == player.Name then
				-- Clicking on yourself - show only Leave button
				leaveButton.Visible = true
				kickButton.Visible = false
				--print("[OtherPlayerInteractHandler.client] 📋 Showing only Leave button (clicking self)")
			else
				-- Leader clicking on another member - show only Kick button
				leaveButton.Visible = false
				kickButton.Visible = true
				--print("[OtherPlayerInteractHandler.client] 📋 Showing only Kick button (clicking other member)")
			end
		end
	end
	
	-- Function to populate party list with individual templates for each member
	local function populatePartyList(memberNames, leaderName)
		-- Validate member names
		--print("[OtherPlayerInteractHandler.client] 📋 populatePartyList called with " .. #memberNames .. " members: " .. table.concat(memberNames, ", "))
		--print("[OtherPlayerInteractHandler.client] 👑 Party leader: " .. leaderName)
		
		-- Update party info
		currentPartyLeader = leaderName
		if leaderName == player.Name then
			currentPlayerRole = "leader"
			--print("[OtherPlayerInteractHandler.client] 👑 You are the party leader")
		else
			currentPlayerRole = "member"
			--print("[OtherPlayerInteractHandler.client] 👤 You are a party member")
		end
		
		-- Find which members are new and which are removed
		local newMembers = {}
		local existingMembers = {}
		
		-- Check for new members
		for _, memberName in ipairs(memberNames) do
			if not memberTemplates[memberName] then
				table.insert(newMembers, memberName)
				--print("[OtherPlayerInteractHandler.client] ✨ New member detected: " .. memberName)
			else
				table.insert(existingMembers, memberName)
				--print("[OtherPlayerInteractHandler.client] ♻️ Existing member: " .. memberName)
			end
		end
		
		-- Remove templates for members no longer in party
		for memberName, template in pairs(memberTemplates) do
			local stillInParty = false
			for _, name in ipairs(memberNames) do
				if name == memberName then
					stillInParty = true
					break
				end
			end
			
			if not stillInParty then
				--print("[OtherPlayerInteractHandler.client] 🗑️ Removing template for member: " .. memberName)
				template:Destroy()
				memberTemplates[memberName] = nil
				
				-- Disconnect click connection for this member
				if memberClickConnections[memberName] then
					memberClickConnections[memberName]:Disconnect()
					memberClickConnections[memberName] = nil
					--print("[OtherPlayerInteractHandler.client] 🔌 Disconnected click connection for " .. memberName)
				end
			end
		end
		
		-- Create individual template for each NEW member
		for _, memberName in ipairs(newMembers) do
			if memberName and memberName ~= "" then
				--print("[OtherPlayerInteractHandler.client] 🔨 Creating individual template for new member: " .. memberName)
				
				-- Create fresh template instance for this member
				local individualTemplate = playerTemplate:Clone()
				individualTemplate.Visible = true
				individualTemplate.Name = "Player_" .. memberName
				
				-- Find and set the player name label
				local playerNameLabel = individualTemplate:FindFirstChild("PlayerName")
				if not playerNameLabel then
					local function findPlayerNameLabel(parent)
						if parent.Name == "PlayerName" then
							return parent
						end
						for _, child in ipairs(parent:GetChildren()) do
							local found = findPlayerNameLabel(child)
							if found then return found end
						end
						return nil
					end
					playerNameLabel = findPlayerNameLabel(individualTemplate)
				end
				
				-- Set the name
				if playerNameLabel then
					playerNameLabel.Text = memberName
					--print("[OtherPlayerInteractHandler.client] ✅ Set individual template name: " .. memberName)
				else
					--print("[OtherPlayerInteractHandler.client] ❌ Could not find PlayerName label for " .. memberName)
				end
				
				-- Setup click connection for this member's template
				if individualTemplate:IsA("ImageButton") or individualTemplate:IsA("TextButton") then
					local memberClickConnection = individualTemplate.MouseButton1Click:Connect(function()
						handleMemberTemplateClick(memberName)
					end)
					memberClickConnections[memberName] = memberClickConnection
					--print("[OtherPlayerInteractHandler.client] 🔗 Connected click handler for " .. memberName)
				end
				
				-- Add to party list and store reference
				individualTemplate.Parent = partyList
				memberTemplates[memberName] = individualTemplate
				--print("[OtherPlayerInteractHandler.client] 👤 Created individual template for " .. memberName)
			end
		end
		
		-- Update existing templates (in case name changes, though unlikely)
		for _, memberName in ipairs(existingMembers) do
			local template = memberTemplates[memberName]
			if template and template.Parent then
				local playerNameLabel = template:FindFirstChild("PlayerName")
				if not playerNameLabel then
					local function findPlayerNameLabel(parent)
						if parent.Name == "PlayerName" then
							return parent
						end
						for _, child in ipairs(parent:GetChildren()) do
							local found = findPlayerNameLabel(child)
							if found then return found end
						end
						return nil
					end
					playerNameLabel = findPlayerNameLabel(template)
				end
				
				if playerNameLabel then
					playerNameLabel.Text = memberName
					--print("[OtherPlayerInteractHandler.client] 🔄 Updated existing template: " .. memberName)
				end
			end
		end
		
		-- Adjust canvas size based on number of members
		local memberCount = #memberNames
		if memberCount > 0 then
			local templateSize = playerTemplate.Size.Y.Offset
			local totalHeight = templateSize * memberCount + (memberCount - 1) * 5 -- 5 studs padding between members
			
			if partyList:IsA("ScrollingFrame") then
				partyList.CanvasSize = UDim2.new(0, partyList.AbsoluteSize.X, 0, totalHeight)
				--print("[OtherPlayerInteractHandler.client] 📏 Canvas size adjusted to height: " .. totalHeight)
			else
				partyList.Size = UDim2.new(partyList.Size.X.Scale, partyList.Size.X.Offset, 0, totalHeight)
				--print("[OtherPlayerInteractHandler.client] 📏 PartyList size adjusted to height: " .. totalHeight)
			end
		end
		
		--print("[OtherPlayerInteractHandler.client] ✅ Party list updated with " .. memberCount .. " individual member templates")
	end
	
	-- Function to refresh member left listener with fresh connection
	local function setupMemberLeftListener()
		-- Disconnect old connection if it exists
		if memberLeftConnection then
			memberLeftConnection:Disconnect()
			--print("[OtherPlayerInteractHandler.client] 🔌 Disconnected old member left connection")
		end
		
		-- Create fresh connection with new parameters
		memberLeftConnection = partyMemberLeftEvent.OnClientEvent:Connect(function(updatedMemberNames)
			--print("[OtherPlayerInteractHandler.client] 👋 Party member left event received. Updated members: " .. table.concat(updatedMemberNames, ", "))
			
			if #updatedMemberNames == 0 then
				--print("[OtherPlayerInteractHandler.client] ❌ No members left in party, hiding party list")
				partyList.Visible = false
                Title.Visible = false
				-- Clear all member templates since party is disbanded
				for memberName, template in pairs(memberTemplates) do
					template:Destroy()
					if memberClickConnections[memberName] then
						memberClickConnections[memberName]:Disconnect()
					end
				end
				memberTemplates = {}
				memberClickConnections = {}
				--print("[OtherPlayerInteractHandler.client] 🧹 Cleared all party templates")
			else
				-- Refresh entire party list with fresh member data - completely repopulate with accurate names
				partyList.Visible = true
                Title.Visible = true
				populatePartyList(updatedMemberNames, currentPartyLeader)
				--print("[OtherPlayerInteractHandler.client] 🔄 Party list completely refreshed with " .. #updatedMemberNames .. " members")
			end
		end)
		
		--print("[OtherPlayerInteractHandler.client] 🔌 Fresh member left connection established")
	end
	
	-- Listen for player leaving (fallback - server notification is primary)
	Players.PlayerRemoving:Connect(function(leftPlayer)
		--print("[OtherPlayerInteractHandler.client] 👋 Local player leaving detected: " .. leftPlayer.Name)
		-- Server will handle party list updates via PartyMemberLeftEvent
	end)
	
	-- Listen for party creation notification from server
	partyCreatedEvent.OnClientEvent:Connect(function(memberNames, leaderName)
		--print("[OtherPlayerInteractHandler.client] 🎉 Party created event received with members: " .. table.concat(memberNames, ", "))
		--print("[OtherPlayerInteractHandler.client] 👑 Party leader: " .. leaderName)
		
		-- Hide invitation UI if visible (shared InvitationUI under GameGui)
		local invitationUI = gameGui:FindFirstChild("InvitationUI")
		if invitationUI then
			invitationUI.Visible = false
		end
		
		-- Show party list and populate it
		partyList.Visible = true
        Title.Visible = true
		if memberNames and #memberNames > 0 then
			populatePartyList(memberNames, leaderName)
			-- Setup fresh member left listener each time party updates
			setupMemberLeftListener()
		end
		
		--print("[OtherPlayerInteractHandler.client] 📋 Party list displayed for all players")
	end)
	
	-- Handle Leave button click
	leaveButton.MouseButton1Click:Connect(function()
		if selectedMemberForAction then
			if currentPlayerRole == "leader" then
				--print("[OtherPlayerInteractHandler.client] 👑 Leader leaving - disbanding entire party")
				partyActionEvent:FireServer("disband", nil)
				partyList.Visible = false
				leaveButton.Visible = false
				kickButton.Visible = false
                Title.Visible = false
			else
				--print("[OtherPlayerInteractHandler.client] 👤 Member leaving party")
				partyActionEvent:FireServer("leave", nil)
				partyList.Visible = false
				leaveButton.Visible = false
				kickButton.Visible = false
                Title.Visible = false
			end
			selectedMemberForAction = nil
		else
			--print("[OtherPlayerInteractHandler.client] ⚠️ No member selected for leave action")
		end
	end)
	
	-- Handle Kick button click
	kickButton.MouseButton1Click:Connect(function()
		if selectedMemberForAction and currentPlayerRole == "leader" then
			--print("[OtherPlayerInteractHandler.client] 👑 Leader kicking member: " .. selectedMemberForAction)
			partyActionEvent:FireServer("kick", selectedMemberForAction)
			kickButton.Visible = false
			selectedMemberForAction = nil
		else
			--print("[OtherPlayerInteractHandler.client] ❌ Cannot kick - only leaders can kick members")
		end
	end)
	
	--print("[OtherPlayerInteractHandler.client] 🎪 Party creation listener ready")
end

-- Shared invitation UI connection tracking
local currentInvitationAcceptConnection = nil
local currentInvitationDeclineConnection = nil

-- Setup party invitation listener
local function setupPartyInvitationListener()
	print("[OtherPlayerInteractHandler.client] 🔧 Setting up party invitation listener...")
	
	local partyInvitationEvent = ReplicatedStorage:WaitForChild("PartyInvitationEvent")
	print("[OtherPlayerInteractHandler.client] ✅ PartyInvitationEvent found")
	
	local partyResponseFunction = getPartyResponseFunction()
	print("[OtherPlayerInteractHandler.client] ✅ PartyResponseFunction found")
	
	-- Get party invitation UI elements (using shared InvitationUI under GameGui)
	local invitationFrame = gameGui:FindFirstChild("InvitationUI")
	if not invitationFrame then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: InvitationUI not found under GameGui!")
		return
	else
		print("[OtherPlayerInteractHandler.client] ✅ InvitationUI found")
	end
	
	local invitationLabel = invitationFrame:FindFirstChild("TextLabel")
	if not invitationLabel then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: TextLabel not found in InvitationUI!")
		return
	else
		print("[OtherPlayerInteractHandler.client] ✅ TextLabel found")
	end
	
	local acceptButton = invitationFrame:FindFirstChild("Accept")
	if not acceptButton then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: Accept button not found in InvitationUI!")
		return
	else
		print("[OtherPlayerInteractHandler.client] ✅ Accept button found")
	end
	
	local declineButton = invitationFrame:FindFirstChild("Decline")
	if not declineButton then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: Decline button not found in InvitationUI!")
		return
	else
		print("[OtherPlayerInteractHandler.client] ✅ Decline button found")
	end
	
	-- Get party UI elements for template
	local partyUI = gameGui:WaitForChild("PartyUI")
	local partyList = partyUI:WaitForChild("PartyList")
	local playerTemplate = partyList:WaitForChild("PlayerTemplate")
	
	-- Hide the default template
	playerTemplate.Visible = false
	print("[OtherPlayerInteractHandler.client] ✅ Party invitation UI setup complete")
	
	-- Listen for party invitations
	partyInvitationEvent.OnClientEvent:Connect(function(inviterPlayer, errorType)
		print("[OtherPlayerInteractHandler.client] 🔔 PARTY INVITATION RECEIVED!")
		print("[OtherPlayerInteractHandler.client] Inviter:", inviterPlayer and inviterPlayer.Name or "NIL")
		print("[OtherPlayerInteractHandler.client] ErrorType:", errorType or "NIL")
		
		if errorType == "AlreadyInParty" then
			print("[OtherPlayerInteractHandler.client] ⚠️ Player already in party")
			showCenterScreenMessage(inviterPlayer.DisplayName .. " is already in a party.")
			return
		end
        
		-- Disconnect any existing invitation connections
		if currentInvitationAcceptConnection then
			print("[OtherPlayerInteractHandler.client] Disconnecting old accept connection")
			currentInvitationAcceptConnection:Disconnect()
			currentInvitationAcceptConnection = nil
		end
		if currentInvitationDeclineConnection then
			print("[OtherPlayerInteractHandler.client] Disconnecting old decline connection")
			currentInvitationDeclineConnection:Disconnect()
			currentInvitationDeclineConnection = nil
		end
		
		-- Update invitation label text
		local inviteText = inviterPlayer.Name .. " invited you to join a party"
		print("[OtherPlayerInteractHandler.client] Setting invitation text:", inviteText)
		invitationLabel.Text = inviteText
        
		-- Show invitation UI
		print("[OtherPlayerInteractHandler.client] Setting InvitationUI.Visible = true")
		invitationFrame.Visible = true
		print("[OtherPlayerInteractHandler.client] ✅ Party Invitation UI should now be visible!")
        
		-- Handle accept button click
		currentInvitationAcceptConnection = acceptButton.MouseButton1Click:Connect(function()
			if currentInvitationAcceptConnection then
				currentInvitationAcceptConnection:Disconnect()
				currentInvitationAcceptConnection = nil
			end
			if currentInvitationDeclineConnection then
				currentInvitationDeclineConnection:Disconnect()
				currentInvitationDeclineConnection = nil
			end
			--print("[OtherPlayerInteractHandler.client] ✅ Party invitation accepted from " .. inviterPlayer.Name)
            
			-- Send response to server
			local response = partyResponseFunction:InvokeServer(inviterPlayer, "Accept")
            
			if response then
				--print("[OtherPlayerInteractHandler.client] 🎉 Successfully sent acceptance to server")
				-- Party list will be shown via PartyCreatedEvent
			else
				--print("[OtherPlayerInteractHandler.client] ❌ Failed to accept party invitation")
			end
		end)
        
		-- Handle decline button click
		currentInvitationDeclineConnection = declineButton.MouseButton1Click:Connect(function()
			if currentInvitationAcceptConnection then
				currentInvitationAcceptConnection:Disconnect()
				currentInvitationAcceptConnection = nil
			end
			if currentInvitationDeclineConnection then
				currentInvitationDeclineConnection:Disconnect()
				currentInvitationDeclineConnection = nil
			end
			--print("[OtherPlayerInteractHandler.client] ❌ Party invitation declined from " .. inviterPlayer.Name)
            
			-- Send response to server
			partyResponseFunction:InvokeServer(inviterPlayer, "Decline")
            
			-- Hide invitation UI
			invitationFrame.Visible = false
			--print("[OtherPlayerInteractHandler.client] 🚫 Invitation UI hidden")
		end)
	end)
	
	--print("[OtherPlayerInteractHandler.client] 📨 Party invitation listener ready")
end

-- Setup duel invitation listener
local function setupDuelInvitationListener()
	print("[OtherPlayerInteractHandler.client] 🔧 Setting up duel invitation listener...")
	
	local duelInvitationEvent = getDuelInvitationEvent()
	print("[OtherPlayerInteractHandler.client] ✅ DuelInvitationEvent found")
	
	local duelResponseFunction = getDuelResponseFunction()
	print("[OtherPlayerInteractHandler.client] ✅ DuelResponseFunction found")
	
	-- Get duel invitation UI elements (under GameGui directly)
	local duelInvitationFrame = gameGui:FindFirstChild("InvitationUI")
	if not duelInvitationFrame then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: InvitationUI not found under GameGui for duel!")
		return
	else
		print("[OtherPlayerInteractHandler.client] ✅ InvitationUI found for duel")
	end
	
	local invitationLabel = duelInvitationFrame:FindFirstChild("TextLabel")
	if not invitationLabel then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: TextLabel not found in InvitationUI for duel!")
		return
	end
	
	local acceptButton = duelInvitationFrame:FindFirstChild("Accept")
	if not acceptButton then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: Accept button not found in InvitationUI for duel!")
		return
	end
	
	local declineButton = duelInvitationFrame:FindFirstChild("Decline")
	if not declineButton then
		print("[OtherPlayerInteractHandler.client] ❌ ERROR: Decline button not found in InvitationUI for duel!")
		return
	end
	
	print("[OtherPlayerInteractHandler.client] ✅ Duel invitation UI setup complete")
	
	-- Listen for duel invitations
	duelInvitationEvent.OnClientEvent:Connect(function(inviterPlayer, errorType)
		print("[OtherPlayerInteractHandler.client] ⚔️ DUEL INVITATION RECEIVED!")
		print("[OtherPlayerInteractHandler.client] Inviter:", inviterPlayer and inviterPlayer.Name or "NIL")
		print("[OtherPlayerInteractHandler.client] ErrorType:", errorType or "NIL")
		
		if errorType == "AlreadyInDuel" then
			print("[OtherPlayerInteractHandler.client] ⚠️ Player already in duel")
			showCenterScreenMessage(inviterPlayer.DisplayName .. " is already in a duel.")
			return
		elseif errorType == "HasPendingInvite" then
			print("[OtherPlayerInteractHandler.client] ⚠️ Player has pending invite")
			showCenterScreenMessage(inviterPlayer.DisplayName .. " already has a pending invitation.")
			return
		end
		
		-- Disconnect any existing invitation connections
		if currentInvitationAcceptConnection then
			print("[OtherPlayerInteractHandler.client] Disconnecting old accept connection")
			currentInvitationAcceptConnection:Disconnect()
			currentInvitationAcceptConnection = nil
		end
		if currentInvitationDeclineConnection then
			print("[OtherPlayerInteractHandler.client] Disconnecting old decline connection")
			currentInvitationDeclineConnection:Disconnect()
			currentInvitationDeclineConnection = nil
		end
		
		-- Update invitation label text
		local duelText = inviterPlayer.Name .. " challenged you to a duel!"
		print("[OtherPlayerInteractHandler.client] Setting invitation text:", duelText)
		invitationLabel.Text = duelText
		
		-- Show invitation UI
		print("[OtherPlayerInteractHandler.client] Setting InvitationUI.Visible = true")
		duelInvitationFrame.Visible = true
		print("[OtherPlayerInteractHandler.client] ✅ Duel Invitation UI should now be visible!")
		
		-- Handle accept button click
		currentInvitationAcceptConnection = acceptButton.MouseButton1Click:Connect(function()
			if currentInvitationAcceptConnection then
				currentInvitationAcceptConnection:Disconnect()
				currentInvitationAcceptConnection = nil
			end
			if currentInvitationDeclineConnection then
				currentInvitationDeclineConnection:Disconnect()
				currentInvitationDeclineConnection = nil
			end
			--print("[OtherPlayerInteractHandler.client] ✅ Duel invitation accepted from " .. inviterPlayer.Name)
			
			-- Send response to server
			local response = duelResponseFunction:InvokeServer(inviterPlayer, "Accept")
			
			if response then
				--print("[OtherPlayerInteractHandler.client] ⚔️ Successfully sent acceptance to server")
				showCenterScreenMessage("Duel starting with " .. inviterPlayer.Name .. "!")
			else
				--print("[OtherPlayerInteractHandler.client] ❌ Failed to accept duel invitation")
			end
			
			-- Hide invitation UI
			duelInvitationFrame.Visible = false
		end)
		
		-- Handle decline button click
		currentInvitationDeclineConnection = declineButton.MouseButton1Click:Connect(function()
			if currentInvitationAcceptConnection then
				currentInvitationAcceptConnection:Disconnect()
				currentInvitationAcceptConnection = nil
			end
			if currentInvitationDeclineConnection then
				currentInvitationDeclineConnection:Disconnect()
				currentInvitationDeclineConnection = nil
			end
			--print("[OtherPlayerInteractHandler.client] ❌ Duel invitation declined from " .. inviterPlayer.Name)
			
			-- Send response to server
			duelResponseFunction:InvokeServer(inviterPlayer, "Decline")
			
			-- Hide invitation UI
			duelInvitationFrame.Visible = false
			--print("[OtherPlayerInteractHandler.client] 🚫 Duel Invitation UI hidden")
		end)
	end)
	
	--print("[OtherPlayerInteractHandler.client] ⚔️ Duel invitation listener ready")
end

-- Setup duel end listener
local function setupDuelEndListener()
	local duelEndedEvent = getDuelEndedEvent()
	
	duelEndedEvent.OnClientEvent:Connect(function(winnerId, reason)
		if winnerId then
			local winner = game.Players:GetPlayerByUserId(winnerId)
			if winner then
				if winner == player then
					if reason == "death" then
						showCenterScreenMessage("Victory! Your opponent was defeated!", 3)
					elseif reason == "left_game" then
						showCenterScreenMessage("Victory! Your opponent left the game!", 3)
					else
						showCenterScreenMessage("Victory! You won the duel!", 3)
					end
				else
					if reason == "death" then
						showCenterScreenMessage("Defeat! You were defeated by " .. winner.Name .. "!", 3)
					elseif reason == "left_game" then
						showCenterScreenMessage("Defeat! You left the duel!", 3)
					else
						showCenterScreenMessage("Defeat! " .. winner.Name .. " won the duel!", 3)
					end
				end
			end
		else
			-- Draw - show reason-specific message
			if reason == "different_maps" then
				showCenterScreenMessage("Draw! Duel cancelled - players in different maps", 3)
			elseif reason == "safe_zone" then
				showCenterScreenMessage("Draw! Duel cancelled - players in safe zone", 3)
			else
				showCenterScreenMessage("Draw! Duel ended", 3)
			end
		end
	end)
	
	--print("[OtherPlayerInteractHandler.client] ⚔️ Duel end listener ready")
end

-- Initialize
local function Initialize()
	print("[OtherPlayerInteractHandler.client] 🎯 Initializing player click detection...")
	print("[OtherPlayerInteractHandler.client] GameGui:", gameGui)
	print("[OtherPlayerInteractHandler.client] Checking for InvitationUI...")
	local invitationUI = gameGui:FindFirstChild("InvitationUI")
	if invitationUI then
		print("[OtherPlayerInteractHandler.client] ✅ InvitationUI exists in GameGui")
		print("[OtherPlayerInteractHandler.client] InvitationUI.Visible:", invitationUI.Visible)
		print("[OtherPlayerInteractHandler.client] InvitationUI children:")
		for _, child in ipairs(invitationUI:GetChildren()) do
			print("  -", child.Name, "(", child.ClassName, ")")
		end
	else
		print("[OtherPlayerInteractHandler.client] ❌ InvitationUI NOT FOUND in GameGui!")
		print("[OtherPlayerInteractHandler.client] GameGui children:")
		for _, child in ipairs(gameGui:GetChildren()) do
			print("  -", child.Name)
		end
	end
	
	setupMouseTargetDetection()
	setupPartyCreationListener()
	setupPartyInvitationListener()
	setupDuelInvitationListener()
	setupDuelEndListener()
	print("[OtherPlayerInteractHandler.client] ✅ Player click detection ready!")
end

-- Start immediately
Initialize()

return OtherPlayerInteractHandler
