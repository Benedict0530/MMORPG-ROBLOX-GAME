-- InGameChat.client.lua
-- Handles player chat input and sends to server for billboard display
local InGameChat = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Chat = game:GetService("Chat")
local StarterGui = game:GetService("StarterGui")

-- Function to safely call SetCore
local function safeSetCore(name, value)
	local success = false
	repeat
		success = pcall(function()
			StarterGui:SetCore(name, value)
		end)
		task.wait()
	until success
end

-- Safely disable Roblox default chat GUI
local function disableChatGUI()
	local success = false
	repeat
		success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		task.wait()
	until success
	--print("[InGameChat] ✓ Roblox default chat disabled safely")
end

disableChatGUI()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StarterGui = game:GetService("StarterGui")



-- Wait for or create RemoteEvent for chat
local chatEvent = ReplicatedStorage:WaitForChild("InGameChatEvent", 10)
if not chatEvent then
	warn("[InGameChat] InGameChatEvent not found in ReplicatedStorage - waiting for server to create it")
	chatEvent = ReplicatedStorage:WaitForChild("InGameChatEvent", 30)
	if not chatEvent then
		error("[InGameChat] Failed to find InGameChatEvent - server handler may not be loaded")
		return
	else
		--print("[InGameChat] ✓ InGameChatEvent successfully found after waiting!")
	end
else
	--print("[InGameChat] ✓ InGameChatEvent found immediately!")
end

--print("[InGameChat] Found InGameChatEvent: " .. tostring(chatEvent))

-- Wait for broadcast event
local broadcastEvent = ReplicatedStorage:WaitForChild("ChatBroadcastEvent", 10)
if not broadcastEvent then
	warn("[InGameChat] ❌ ChatBroadcastEvent not found after 10 seconds")
	broadcastEvent = ReplicatedStorage:WaitForChild("ChatBroadcastEvent", 30)
	if not broadcastEvent then
		error("[InGameChat] Failed to find ChatBroadcastEvent - server handler may not be loaded")
		return
	end
end
--print("[InGameChat] ✓ ChatBroadcastEvent found")

-- Create chat UI
local function createChatUI()
	-- Main IngameChat container
	--print("[InGameChat] Waiting for GameGui...")
	local gameGui = playerGui:WaitForChild("GameGui", 10)
	if not gameGui then
		warn("[InGameChat] ❌ GameGui not found after 10 seconds - chat system disabled")
		return
	end
	--print("[InGameChat] ✓ GameGui found")
	
	-- Find or create IngameChat frame
	local ingameChat = gameGui:FindFirstChild("IngameChat")
	if not ingameChat then
		ingameChat = Instance.new("Frame")
		ingameChat.Name = "IngameChat"
		ingameChat.Size = UDim2.new(0, 300, 0, 250)
		ingameChat.Position = UDim2.new(0, 20, 1, -280)
		ingameChat.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		ingameChat.BorderSizePixel = 0
		ingameChat.Parent = gameGui
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = ingameChat
		--print("[InGameChat] ✓ IngameChat frame created")
	else
		--print("[InGameChat] ✓ IngameChat frame found (already exists)")
	end
	
	-- Create or get ScrollingFrame for chat history
	local scrollingFrame = ingameChat:FindFirstChild("ScrollingFrame")
	if not scrollingFrame then
		scrollingFrame = Instance.new("ScrollingFrame")
		scrollingFrame.Name = "ScrollingFrame"
		scrollingFrame.Size = UDim2.new(1, 0, 1, -60)
		scrollingFrame.Position = UDim2.new(0, 0, 0, 0)
		scrollingFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		scrollingFrame.BorderSizePixel = 0
		scrollingFrame.ScrollBarThickness = 8
		scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
		scrollingFrame.Parent = ingameChat
		
		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 4)
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = scrollingFrame
		
		--print("[InGameChat] ✓ ScrollingFrame created")
	end
	
	-- Create template TextLabel (hidden)
	local templateLabel = scrollingFrame:FindFirstChild("ChatMessageTemplate")
	if not templateLabel then
		templateLabel = Instance.new("TextLabel")
		templateLabel.Name = "ChatMessageTemplate"
		templateLabel.Size = UDim2.new(1, -10, 0, 30)
		templateLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		templateLabel.BorderSizePixel = 0
		templateLabel.TextColor3 = Color3.fromRGB(230, 230, 245)
		templateLabel.TextSize = 12
		templateLabel.Font = Enum.Font.Gotham
		templateLabel.TextWrapped = true
		templateLabel.TextXAlignment = Enum.TextXAlignment.Left
		templateLabel.TextYAlignment = Enum.TextYAlignment.Top
		templateLabel.Visible = false
		templateLabel.Parent = scrollingFrame
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = templateLabel
		
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.Parent = templateLabel
		
		--print("[InGameChat] ✓ ChatMessageTemplate created")
	end
	
	-- Create or get TextBox
	local textBox = ingameChat:FindFirstChild("TextBox")
	if not textBox then
		textBox = Instance.new("TextBox")
		textBox.Name = "TextBox"
		textBox.Size = UDim2.new(1, -10, 0, 40)
		textBox.Position = UDim2.new(0, 5, 1, -45)
		textBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		textBox.BorderSizePixel = 0
		textBox.Text = ""
		textBox.PlaceholderText = "Type message..."
		textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
		textBox.TextColor3 = Color3.fromRGB(230, 230, 245)
		textBox.TextSize = 14
		textBox.Font = Enum.Font.Gotham
		textBox.MultiLine = false
		textBox.Parent = ingameChat
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = textBox
		
		--print("[InGameChat] ✓ TextBox created and visible")
	else
		--print("[InGameChat] ✓ TextBox found (already exists)")
	end
	
	-- Function to add message to chat history
	local function addMessageToScroll(playerName, message)
		local newMessage = templateLabel:Clone()
		newMessage.Name = "ChatMessage_" .. tick()
		newMessage.Text = playerName .. ": " .. message
		newMessage.Visible = true
		newMessage.Parent = scrollingFrame
		
		-- Wait for layout to update
		task.wait(0.01)
		
		-- Get the list layout to calculate the new message size
		local listLayout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
		if listLayout then
			-- Force update
			listLayout:ApplyLayout()
			task.wait(0.01)
		end
		
		-- Calculate ONLY the new message size plus padding
		local messageHeight = newMessage.AbsoluteSize.Y
		local padding = listLayout and listLayout.Padding.Offset or 4
		local sizeIncrease = messageHeight + padding
		
		-- Increase canvas size by only the new message's size
		local currentCanvasSize = scrollingFrame.CanvasSize.Y.Offset
		scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, currentCanvasSize + sizeIncrease)
		
		-- Auto-scroll to bottom when new message is added
		scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.CanvasSize.Y.Offset - scrollingFrame.AbsoluteSize.Y)
		
		--print("[InGameChat] ✓ Message added to scroll: " .. playerName .. ": " .. message .. " (size increase: " .. sizeIncrease .. "px)")
	end
	
	-- Function to send chat message
	local function sendMessage()
		if not chatEvent then
			warn("[InGameChat] chatEvent not initialized")
			return
		end
		
		if textBox.Text ~= "" then
			local message = textBox.Text
			--print("[InGameChat] ✓ Player submitted text: '" .. message .. "'")
			
			-- Validate message length
			if #message > 100 then
				message = message:sub(1, 100)
			end
			
			-- Send to server (server will broadcast back)
			--print("[InGameChat] Sending message: " .. message)
			chatEvent:FireServer(message)
			--print("[InGameChat] Message sent successfully")
			
			-- Clear input
			textBox.Text = ""
		else
			--print("[InGameChat] TextBox is empty, not sending")
		end
	end
	
	-- Log when textbox gets focus
	textBox.Focused:Connect(function()
		--print("[InGameChat] ✓ TextBox clicked - ready to type")
	end)
	
	-- Send message when textbox loses focus
	textBox.FocusLost:Connect(function(enterPressed)
		--print("[InGameChat] TextBox focus lost - enterPressed: " .. tostring(enterPressed))
		--print("[InGameChat] Current text in box: '" .. textBox.Text .. "'")
		sendMessage()
	end)
	
	-- Listen for broadcast messages from server (all players' chat)
	broadcastEvent.OnClientEvent:Connect(function(playerName, message)
		--print("[InGameChat] ✓ Received broadcast from " .. playerName .. ": " .. message)
		addMessageToScroll(playerName, message)
	end)
	
	-- HideShowButton toggle functionality
	local hideShowButton = ingameChat:FindFirstChild("HideShowButton")
	if hideShowButton and hideShowButton:IsA("GuiButton") then
		local isHidden = false
		local defaultPosition = ingameChat.Position
		-- Keep button visible (assuming button is ~40px, leave that much showing)
		local hiddenPosition = UDim2.new(defaultPosition.X.Scale, defaultPosition.X.Offset, 1, -20)
		
		-- Image IDs for button states
		local hiddenImage = "rbxassetid://137574542459191"
		local shownImage = "rbxassetid://70883524252925"
		
		hideShowButton.MouseButton1Click:Connect(function()
			isHidden = not isHidden
			
			if isHidden then
				-- Slide down (hide)
				ingameChat:TweenPosition(
					hiddenPosition,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.3,
					true
				)
				-- Change button image to show state (up arrow)
				hideShowButton.Image = hiddenImage
				--print("[InGameChat] ✓ Chat hidden")
			else
				-- Slide up (show)
				ingameChat:TweenPosition(
					defaultPosition,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.3,
					true
				)
				-- Change button image to hide state (down arrow)
				hideShowButton.Image = shownImage
				--print("[InGameChat] ✓ Chat shown")
			end
		end)
		
		--print("[InGameChat] ✓ HideShowButton toggle enabled")
	else
		warn("[InGameChat] HideShowButton not found in IngameChat frame")
	end
	
	return textBox
end

-- Initialize chat UI
local chatTextBox = createChatUI()

--print("[InGameChat] In-game chat system loaded. Type messages and click away to send.")

return InGameChat
