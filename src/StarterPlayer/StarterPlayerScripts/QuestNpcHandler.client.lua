-- QuestNpcHandler.client.lua
-- Client-side handler for quest NPC interactions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = players.LocalPlayer

-- Wait for RemoteEvent to be created
local QuestNpcInteractionEvent = ReplicatedStorage:WaitForChild("QuestNpcInteraction")
local QuestAcceptanceEvent = ReplicatedStorage:WaitForChild("QuestAcceptance")
local CameraFocusModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraFocusModule"))
local ButtonAnimateModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ButtonAnimateModule"))
local NpcQuestData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NpcQuestData"))

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")
local questGui = gameGui:WaitForChild("NpcQuestButtons")
local QuestButton = questGui:WaitForChild("Button1")
local WhoAreYouButton = questGui:WaitForChild("Button2")
local GoodByeButton = questGui:WaitForChild("Button3")

local questProgressGui = gameGui:WaitForChild("QuestProgressGui")

-- Hide quest progress GUI by default
questProgressGui.Visible = false

-- Function to check if player has any active quests
local function hasActiveQuest()
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then return false end
	
	for _, questValue in ipairs(questFolder:GetChildren()) do
		if questValue:IsA("Folder") and string.match(questValue.Name, "Quest_") then
			local statusValue = questValue:FindFirstChild("status")
			if statusValue and (statusValue.Value == "accepted" or statusValue.Value == "active") then
				return true
			end
		end
	end
	return false
end

-- Function to create quest indicator billboard on NPC
local function createQuestIndicatorBillboard(npc, mapName)
	local head = npc:FindFirstChild("Head")
	if not head then return end
	
	-- Remove old indicator if it exists
	local oldIndicator = head:FindFirstChild("QuestIndicator")
	if oldIndicator then
		oldIndicator:Destroy()
	end
	
	-- Get next available quest
	local quest = NpcQuestData.GetNextAvailableQuestByMapName(mapName, player)
	
	-- If no available quests, don't create billboard
	if not quest then
		return
	end
	
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "QuestIndicator"
	billboardGui.Size = UDim2.new(1.5, 0, 1.5, 0)
	billboardGui.MaxDistance = 100
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = head
	billboardGui.AlwaysOnTop = true
	
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Text = "!"
	textLabel.TextSize = 32
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = billboardGui
	
	-- Check if quest is already accepted by this player
	local questIsAccepted = false
	local questFolder = player:FindFirstChild("Quests")
	if questFolder then
		local questValue = questFolder:FindFirstChild("Quest_" .. quest.questId)
		if questValue then
			local statusValue = questValue:FindFirstChild("status")
			questIsAccepted = statusValue and (statusValue.Value == "accepted" or statusValue.Value == "active")
		end
	end
	
	-- Set color based on quest status
	if questIsAccepted then
		textLabel.TextColor3 = Color3.fromRGB(128, 128, 128) -- Gray - already accepted
	else
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow - available
	end
	
	-- Add UIStroke for visibility
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(0, 0, 0)
	uiStroke.Thickness = 2
	uiStroke.Parent = textLabel
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = textLabel
	
	print("[QuestNpcHandler] ✅ Quest indicator created for", npc.Name)
end

-- Function to update quest progress GUI
local function updateQuestProgressGui(questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then return end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then return end
	
	local progressValue = questValue:FindFirstChild("progress")
	if not progressValue then return end
	
	-- Get quest data
	local quest = NpcQuestData.GetQuest(questId)
	if not quest then return end
	
	-- Get current progress and target from objectives
	local currentProgress = progressValue.Value
	local targetProgress = 0
	local enemyType = "Enemy"
	
	-- Access first objective (most quests have one main objective)
	if quest.objectives and quest.objectives[1] then
		targetProgress = quest.objectives[1].target or 0
		enemyType = quest.objectives[1].enemyType or "Enemy"
	end
	
	-- Ensure all values are valid
	if not enemyType or targetProgress == 0 then
		print("[QuestNpcHandler] ⚠️ Quest data incomplete for quest", questId, "| Enemy:", enemyType, "| Target:", targetProgress)
		return
	end
	
	-- Update GUI text
	local missionLabel = questProgressGui:FindFirstChild("Background")
	if missionLabel then
		local missionText = missionLabel:FindFirstChild("Mission")
		if missionText then
			missionText.Text = string.format("Kill %s %d / %d", tostring(enemyType), currentProgress, targetProgress)
			print("[QuestNpcHandler] ✅ Updated progress GUI:", missionText.Text)
		end
	end
end


-- Function to scan all maps and create quest indicators on NPCs
local function scanAndCreateQuestIndicators()
	print("[QuestNpcHandler] Scanning for quest NPCs to create indicators...")
	local workspace = game:GetService("Workspace")
	local mapsFolder = workspace:FindFirstChild("Maps")
	
	if not mapsFolder then
		print("[QuestNpcHandler] ⚠️ No 'Maps' folder found in Workspace")
		return
	end
	
	local count = 0
	for _, map in ipairs(mapsFolder:GetChildren()) do
		if map:IsA("Folder") or map:IsA("Model") then
			local questNpc = map:FindFirstChild("QuestNpc")
			if questNpc and questNpc:IsA("Model") then
				-- Get map name
				local mapName = map.Name
				createQuestIndicatorBillboard(questNpc, mapName)
				count = count + 1
			end
		end
	end
	
	print("[QuestNpcHandler] ✅ Created quest indicators for", count, "NPCs")
end

-- Function to show quest progress GUI for active quest
local function showQuestProgress(questId)
	questProgressGui.Visible = true
	updateQuestProgressGui(questId)
	
	-- Monitor for progress changes
	local questFolder = player:FindFirstChild("Quests")
	if questFolder then
		local questValue = questFolder:FindFirstChild("Quest_" .. questId)
		if questValue then
			local progressValue = questValue:FindFirstChild("progress")
			if progressValue then
				-- Connect to progress changes
				local connection
				connection = progressValue.Changed:Connect(function()
					updateQuestProgressGui(questId)
					
					-- Check if quest is completed
					local statusValue = questValue:FindFirstChild("status")
					if statusValue and statusValue.Value == "completed" then
						questProgressGui.Visible = false
						connection:Disconnect()
						print("[QuestNpcHandler] ✅ Quest completed - hiding progress GUI")
						
						-- Refresh quest indicators for next quest
						task.wait(0.2)
						scanAndCreateQuestIndicators()
						print("[QuestNpcHandler] 🔄 Quest indicators refreshed after completion")
					end
				end)
			end
		end
	end
end

-- Check for active quests on startup
task.delay(1, function()
	local questFolder = player:FindFirstChild("Quests")
	if questFolder then
		for _, questValue in ipairs(questFolder:GetChildren()) do
			if questValue:IsA("Folder") and string.match(questValue.Name, "Quest_") then
				local statusValue = questValue:FindFirstChild("status")
				if statusValue and (statusValue.Value == "accepted" or statusValue.Value == "active") then
					local questId = tonumber(string.sub(questValue.Name, 7))
					showQuestProgress(questId)
					print("[QuestNpcHandler] 📊 Showing existing active quest progress GUI for quest", questId)
					break -- Only show first active quest
				end
			end
		end
	end
end)


-- Function to refresh all quest indicators when quests change
local function setupQuestMonitoring()
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then return end
	
	-- Monitor for any child changes in the Quests folder (new quests added)
	questFolder.ChildAdded:Connect(function()
		task.wait(0.2)
		scanAndCreateQuestIndicators()
		print("[QuestNpcHandler] 🔄 Quest indicators refreshed (new quest added)")
	end)
	
	-- Monitor each quest's status value for changes
	for _, questValue in ipairs(questFolder:GetChildren()) do
		if questValue:IsA("Folder") and string.match(questValue.Name, "Quest_") then
			local statusValue = questValue:FindFirstChild("status")
			if statusValue then
				statusValue.Changed:Connect(function()
					task.wait(0.1) -- Small delay to ensure value is propagated
					scanAndCreateQuestIndicators()
					print("[QuestNpcHandler] 🔄 Quest indicators refreshed (status changed)")
				end)
			end
		end
	end
end

-- Setup monitoring after a delay to ensure quests folder exists
task.delay(0.3, function()
	setupQuestMonitoring()
end)

-- Scan for quest indicators on startup
task.delay(0.5, function()
	scanAndCreateQuestIndicators()
end)

-- Function to animate text with typing effect
local function typeText(textLabel, fullText, speed)
	speed = speed or 0.05
	textLabel.Text = ""
	
	for i = 1, #fullText do
		textLabel.Text = string.sub(fullText, 1, i)
		task.wait(speed)
	end
    questGui.Visible = true
end

-- Function to create greeting billboard GUI
local function createGreetingBillboard(npc, mapName)
	local head = npc:FindFirstChild("Head")
	if not head or head:FindFirstChild("GreetingGui") then
		return
	end
	
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "GreetingGui"
	billboardGui.Size = UDim2.new(8, 0, 2, 0)
	billboardGui.MaxDistance = 50
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.Parent = head
	billboardGui.AlwaysOnTop = true
	
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 24
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = billboardGui
	
	-- Add UIStroke for text outline
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(0, 0, 0)
	uiStroke.Thickness = 2
	uiStroke.Parent = textLabel
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel
	
	-- Animate text with typing effect
	local greetingText = "Hello traveler\nwelcome to " .. mapName
	typeText(textLabel, greetingText, 0.05)
	
	print("[QuestNpcHandler] ✅ BillboardGui created with typing animation")
end

-- Function to check if quest is completed
local function isQuestCompleted(questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return false
	end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return false
	end
	
	local statusValue = questValue:FindFirstChild("status")
	return statusValue and statusValue.Value == "completed"
end

-- Function to check if quest is accepted
local function isQuestAccepted(questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return false
	end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return false
	end
	
	local statusValue = questValue:FindFirstChild("status")
	return statusValue and statusValue.Value == "accepted"
end

-- Listen for server events
QuestNpcInteractionEvent.OnClientEvent:Connect(function(data)
	print("[QuestNpcHandler] 🎯 Received quest NPC interaction!")
	print("[QuestNpcHandler] NPC Name:", data.npcName)
	print("[QuestNpcHandler] Map Name:", data.mapName)
	print("[QuestNpcHandler] Position:", data.position)
	print("[QuestNpcHandler] ✅ Player interacted with", data.npcName, "in", data.mapName)
	
	-- Track current dialogue index
	local currentDialogueIndex = 1
	local dialoguesShown = false
	local isFirstClick = true
	
	-- Focus camera on NPC
	if data.npc then
		CameraFocusModule.FocusOn(data.npc, 1.5)
	end
	
	-- Disable proximity prompt on client
	local promptPart = data.npc:FindFirstChild(data.promptPartName)
	if promptPart then
		local proximityPrompt = promptPart:FindFirstChild("ProximityPrompt")
		if proximityPrompt then
			proximityPrompt.Enabled = false
			print("[QuestNpcHandler] ✅ ProximityPrompt disabled")
		end
	end
	
	-- Create billboard with greeting text
	createGreetingBillboard(data.npc, data.mapName)
	
	-- Create quest indicator billboard if not already present
	createQuestIndicatorBillboard(data.npc, data.mapName)
	
	-- Get the next available quest in the chain (first incomplete one)
	local quest = NpcQuestData.GetNextAvailableQuestByMapName(data.mapName, player)
	
	-- Check if all quests are completed
	local allQuestsCompleted = quest == nil
	local questIsAccepted = quest and isQuestAccepted(quest.questId) or false
	local questIsCompleted = quest and isQuestCompleted(quest.questId) or false
	
	print("[QuestNpcHandler] Quest Chain Status:")
	print("  - All quests completed:", allQuestsCompleted)
	print("  - Current quest ID:", quest and quest.questId or "NONE")
	print("  - Current quest accepted:", questIsAccepted)
	print("  - Current quest completed:", questIsCompleted)
	
	-- If quest is already accepted or completed, show special message
	local head = data.npc:FindFirstChild("Head")
	if head then
		local greetingGui = head:FindFirstChild("GreetingGui")
		if greetingGui then
			local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
			if dialogueLabel then
				if allQuestsCompleted then
					dialogueLabel.Text = "You have completed all the quests!\nThank you for your help, brave adventurer!"
				elseif questIsCompleted then
					dialogueLabel.Text = "Well done! But there's more work to be done.\nLet's talk."
				elseif questIsAccepted then
					dialogueLabel.Text = "Quest already accepted!\nGood luck out there!"
				end
			end
		end
	end
	
	-- Setup button animations (only on desktop, not touch devices)
	if not UserInputService.TouchEnabled then
		ButtonAnimateModule.SetupButtons({
			QuestButton = QuestButton,
			WhoAreYouButton = WhoAreYouButton,
			GoodByeButton = GoodByeButton
		})
		print("[QuestNpcHandler] 🖱️ Button hover animations enabled")
	else
		print("[QuestNpcHandler] 📱 Touch device detected - button animations disabled")
	end
	
	-- Set default button states
	QuestButton.Text = "Quest"
	QuestButton.Active = true
	QuestButton.Visible = true
	WhoAreYouButton.Text = "Who are you?"
	WhoAreYouButton.Active = true
	WhoAreYouButton.Visible = true
	GoodByeButton.Text = "Goodbye"
	GoodByeButton.Active = true
	GoodByeButton.Visible = true
	print("[QuestNpcHandler] ✅ Default button states set")
	
	-- If all quests completed, hide Quest button and "Who are you?" button
	if allQuestsCompleted then
		QuestButton.Visible = false
		WhoAreYouButton.Visible = false
		print("[QuestNpcHandler] ⚠️ All quests completed - hiding Quest and response buttons")
	-- If current quest is already accepted, hide Quest button and "Who are you?" button
	elseif questIsAccepted then
		QuestButton.Visible = false
		WhoAreYouButton.Visible = false
		print("[QuestNpcHandler] ⚠️ Quest already accepted - hiding Quest and response buttons")
	end
	
	-- Track button states
	local questStarted = false
	local isProcessing = false -- Debounce flag to prevent button spam
	
	-- Store connections to disconnect them later
	local questButtonConnection
	local whoAreYouButtonConnection
	local goodByeButtonConnection
	
	-- Disconnect any existing connections first
	if questButtonConnection then questButtonConnection:Disconnect() end
	if whoAreYouButtonConnection then whoAreYouButtonConnection:Disconnect() end
	if goodByeButtonConnection then goodByeButtonConnection:Disconnect() end
	
	-- Setup button click logic
	questButtonConnection = QuestButton.MouseButton1Click:Connect(function()
		if isProcessing then return end -- Prevent button spam
		isProcessing = true
		
		print("[QuestNpcHandler] ✅ Clicked: QuestButton")
		
		-- Get quest data - get NEXT available quest in chain
		local quest = NpcQuestData.GetNextAvailableQuestByMapName(data.mapName, player)
		print("[QuestNpcHandler] Quest found:", quest ~= nil, "for map:", data.mapName)
		
		if quest then
			if not questStarted then
				-- First click - show first dialogue
				questStarted = true
				
				-- Clear all button texts and deactivate
				QuestButton.Text = ""
				QuestButton.Active = false
				WhoAreYouButton.Text = ""
				WhoAreYouButton.Active = false
				GoodByeButton.Text = ""
				GoodByeButton.Active = false
				print("[QuestNpcHandler] All buttons cleared and deactivated")
				
				-- Find dialogue label in the billboard GUI
				local head = data.npc:FindFirstChild("Head")
				if head then
					local greetingGui = head:FindFirstChild("GreetingGui")
					if greetingGui then
						local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
						print("[QuestNpcHandler] Dialogue label found:", dialogueLabel ~= nil)
						
						if dialogueLabel then
							-- Show first dialogue
							dialogueLabel.Text = ""
							task.wait(0.1)
							
							local firstDialogue = quest.dialogue[1]
							local dialogueText = firstDialogue.npc .. ":\n" .. firstDialogue.text
							
							print("[QuestNpcHandler] Displaying dialogue 1 of", #quest.dialogue)
							typeText(dialogueLabel, dialogueText, 0.02)
							
							-- Show 2 buttons: NEXT and Never mind
							task.wait(1.5)
							QuestButton.Text = "NEXT"
							QuestButton.Active = true
							QuestButton.Visible = true
							WhoAreYouButton.Visible = false
							GoodByeButton.Text = "Never mind"
							GoodByeButton.Active = true
							GoodByeButton.Visible = true
							print("[QuestNpcHandler] ✅ Showing NEXT and Never mind buttons")
						end
					end
				end
			else
				-- NEXT button clicked - show second dialogue
				print("[QuestNpcHandler] ✅ Clicked: NEXT button")
				
				-- Clear and deactivate buttons
				QuestButton.Text = ""
				QuestButton.Active = false
				WhoAreYouButton.Text = ""
				WhoAreYouButton.Active = false
				GoodByeButton.Text = ""
				GoodByeButton.Active = false
				print("[QuestNpcHandler] All buttons cleared and deactivated")
				
				-- Get quest data
				local head = data.npc:FindFirstChild("Head")
				if head then
					local greetingGui = head:FindFirstChild("GreetingGui")
					if greetingGui then
						local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
						if dialogueLabel then
							-- Show second dialogue
							dialogueLabel.Text = ""
							task.wait(0.1)
							
							local secondDialogue = quest.dialogue[2]
							local dialogueText = secondDialogue.npc .. ":\n" .. secondDialogue.text
							
							print("[QuestNpcHandler] Displaying dialogue 2 of", #quest.dialogue)
							typeText(dialogueLabel, dialogueText, 0.02)
							
							-- Show 2 response buttons
							task.wait(1.5)
							if quest.responses then
								WhoAreYouButton.Text = quest.responses[1].text
								WhoAreYouButton.Active = true
								WhoAreYouButton.Visible = true
								
								GoodByeButton.Text = "Never mind"
								GoodByeButton.Active = true
								GoodByeButton.Visible = true
								
								QuestButton.Visible = false
								print("[QuestNpcHandler] ✅ Showing response options")
							end
						end
					end
				end
			end
		else
			print("[QuestNpcHandler] ⚠️ No quest found for map:", data.mapName)
		end
		
		isProcessing = false -- Allow next click
	end)
	
	whoAreYouButtonConnection = WhoAreYouButton.MouseButton1Click:Connect(function()
		if isProcessing then return end -- Prevent button spam
		isProcessing = true
		
		print("[QuestNpcHandler] ✅ Clicked: I'll take care of them")
		
		-- Check if player already has an active quest
		if hasActiveQuest() then
			print("[QuestNpcHandler] ⚠️ Player already has an active quest!")
			local head = data.npc:FindFirstChild("Head")
			if head then
				local greetingGui = head:FindFirstChild("GreetingGui")
				if greetingGui then
					local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
					if dialogueLabel then
						dialogueLabel.Text = "You already have an active quest!\nComplete it first."
					end
				end
			end
			task.wait(2)
			questGui.Visible = false
			CameraFocusModule.RestoreDefault()
			isProcessing = false
			return
		end
		
		-- Get NEXT available quest in chain
		local quest = NpcQuestData.GetNextAvailableQuestByMapName(data.mapName, player)
		if not quest then
			print("[QuestNpcHandler] ⚠️ No quest found for map:", data.mapName)
			isProcessing = false
			return
		end
		
		-- Check if quest is already completed
		if isQuestCompleted(quest.questId) then
			print("[QuestNpcHandler] ⚠️ Quest", quest.questId, "already completed!")
			local head = data.npc:FindFirstChild("Head")
			if head then
				local greetingGui = head:FindFirstChild("GreetingGui")
				if greetingGui then
					local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
					if dialogueLabel then
						dialogueLabel.Text = "Thank you for your help, brave adventurer!"
					end
				end
			end
			task.wait(2)
			questGui.Visible = false
			CameraFocusModule.RestoreDefault()
			isProcessing = false
			return
		end
		
		-- Fire server event to accept quest
		QuestAcceptanceEvent:FireServer(quest.questId)
		print("[QuestNpcHandler] 📤 Sent quest acceptance to server for quest", quest.questId)
		
		-- Show quest progress GUI
		task.delay(0.5, function()
			showQuestProgress(quest.questId)
			print("[QuestNpcHandler] 📊 Showing quest progress GUI for quest", quest.questId)
		end)
		
		-- Deactivate and clear all buttons immediately
		QuestButton.Active = false
		WhoAreYouButton.Active = false
		GoodByeButton.Active = false
		QuestButton.Text = ""
		WhoAreYouButton.Text = ""
		GoodByeButton.Text = ""
		print("[QuestNpcHandler] Buttons deactivated and cleared")
		
		if quest and quest.responses and quest.responses[1] then
			-- Show NPC's response to accepting the quest
			local head = data.npc:FindFirstChild("Head")
			if head then
				local greetingGui = head:FindFirstChild("GreetingGui")
				if greetingGui then
					local dialogueLabel = greetingGui:FindFirstChildOfClass("TextLabel")
					if dialogueLabel then
						dialogueLabel.Text = ""
						task.wait(0.1)
						
						local nextDialogue = quest.responses[1].nextDialogue
						local responseText = nextDialogue.npc .. ":\n" .. nextDialogue.text
						
						typeText(dialogueLabel, responseText, 0.02)
						print("[QuestNpcHandler] Showing quest acceptance dialogue")
						
						-- Wait for dialogue to finish and then reset everything
						task.wait(3)
						
						-- Destroy billboard GUI
						if greetingGui then
							greetingGui:Destroy()
							print("[QuestNpcHandler] 🗑️ Billboard destroyed after quest acceptance")
						end
						
						-- Hide quest GUI
						questGui.Visible = false
						print("[QuestNpcHandler] 👁️ QuestGui hidden")
						
						-- Reset button texts and visibility
						QuestButton.Text = "Quest"
						QuestButton.Active = true
						QuestButton.Visible = true
						WhoAreYouButton.Text = "Who are you?"
						WhoAreYouButton.Active = true
						WhoAreYouButton.Visible = false
						GoodByeButton.Text = "Goodbye"
						GoodByeButton.Active = true
						GoodByeButton.Visible = true
						print("[QuestNpcHandler] 🔄 Buttons reset to default")
						
						-- Re-enable proximity prompt
						local promptPart = data.npc:FindFirstChild(data.promptPartName)
						if promptPart then
							local proximityPrompt = promptPart:FindFirstChild("ProximityPrompt")
							if proximityPrompt then
								proximityPrompt.Enabled = true
								print("[QuestNpcHandler] ✅ ProximityPrompt re-enabled")
							end
						end
						
						-- Restore camera to default (third-person view)
						print("[QuestNpcHandler] 📷 Restoring camera to default view")
						CameraFocusModule.RestoreDefault()
						task.wait(0.2)
						print("[QuestNpcHandler] ✅ Quest accepted - camera reset, conversation ended")
					end
				end
			end
		end
		
		isProcessing = false -- Allow next click
	end)
	
	goodByeButtonConnection = GoodByeButton.MouseButton1Click:Connect(function()
		if isProcessing then return end -- Prevent button spam
		isProcessing = true
		
		print("[QuestNpcHandler] ✅ Clicked: GoodByeButton - Ending conversation")
		
		-- Disconnect all button connections
		if questButtonConnection then questButtonConnection:Disconnect() end
		if whoAreYouButtonConnection then whoAreYouButtonConnection:Disconnect() end
		if goodByeButtonConnection then goodByeButtonConnection:Disconnect() end
		print("[QuestNpcHandler] All button connections disconnected")
		
		-- Destroy billboard GUI
		local head = data.npc:FindFirstChild("Head")
		if head then
			local greetingGui = head:FindFirstChild("GreetingGui")
			if greetingGui then
				greetingGui:Destroy()
				print("[QuestNpcHandler] 🗑️ Billboard destroyed")
			end
		end
		
		-- Hide quest GUI
		questGui.Visible = false
		print("[QuestNpcHandler] 👁️ QuestGui hidden")
		
		-- Reset all button states to default
		QuestButton.Text = "Quest"
		QuestButton.Active = true
		QuestButton.Visible = true
		WhoAreYouButton.Text = "Who are you?"
		WhoAreYouButton.Active = true
		WhoAreYouButton.Visible = true
		GoodByeButton.Text = "Goodbye"
		GoodByeButton.Active = true
		GoodByeButton.Visible = true
		print("[QuestNpcHandler] 🔄 All buttons reset to default state")
		
		-- Re-enable proximity prompt
		local promptPart = data.npc:FindFirstChild(data.promptPartName)
		if promptPart then
			local proximityPrompt = promptPart:FindFirstChild("ProximityPrompt")
			if proximityPrompt then
				proximityPrompt.Enabled = true
				print("[QuestNpcHandler] ✅ ProximityPrompt re-enabled")
			end
		end
		
		-- Restore camera to default (third-person view)
		print("[QuestNpcHandler] 📷 Restoring camera to default view")
		CameraFocusModule.RestoreDefault()
		task.wait(0.2)
		print("[QuestNpcHandler] ✅ Conversation ended - camera reset, state fully restored")
		
		isProcessing = false -- Allow next click (though conversation is over)
	end)
	
	-- Add your quest UI logic here
	-- For example: show quest dialog, open quest panel, etc.
end)

print("[QuestNpcHandler] Client script loaded - listening for quest NPC interactions")
