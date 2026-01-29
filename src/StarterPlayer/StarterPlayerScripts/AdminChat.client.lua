-- -- AdminChat.client.lua
-- -- Custom admin chat panel for commands

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")
-- local UserInputService = game:GetService("UserInputService")

-- local player = Players.LocalPlayer

-- -- Load AdminId
-- local AdminId = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AdminId"))

-- -- Check if player is admin
-- if not AdminId.IsAdmin(player.UserId) then
-- 	return -- Exit if not admin
-- end

-- -- Get admin event
-- local adminEvent = ReplicatedStorage:WaitForChild("AdminCommandEvent")

-- -- Create admin toggle button (top-middle)
-- local function createToggleButton(callback)
-- 	local playerGui = player:WaitForChild("PlayerGui")
	
-- 	local screenGui = Instance.new("ScreenGui")
-- 	screenGui.Name = "AdminToggleButton"
-- 	screenGui.ResetOnSpawn = false
-- 	screenGui.Parent = playerGui
-- 	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	
-- 	local toggleBtn = Instance.new("TextButton")
-- 	toggleBtn.Name = "ToggleBtn"
-- 	toggleBtn.Size = UDim2.new(0, 60, 0, 50)
-- 	toggleBtn.Position = UDim2.new(0.5, -30, 0, 10)
-- 	toggleBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
-- 	toggleBtn.BackgroundTransparency = 0.9
-- 	toggleBtn.BorderSizePixel = 0
-- 	toggleBtn.Text = "⚙️"
-- 	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
-- 	toggleBtn.TextSize = 24
-- 	toggleBtn.Font = Enum.Font.GothamBold
-- 	toggleBtn.Parent = screenGui
-- 	toggleBtn.ZIndex = 999
	
-- 	local corner = Instance.new("UICorner")
-- 	corner.CornerRadius = UDim.new(0, 8)
-- 	corner.Parent = toggleBtn
	
-- 	toggleBtn.MouseButton1Click:Connect(function()
-- 		callback()
-- 	end)
	
-- 	return toggleBtn
-- end

-- -- Create custom chat UI
-- local function createAdminChat()
-- 	local playerGui = player:WaitForChild("PlayerGui")
	
-- 	-- Main screen GUI
-- 	local screenGui = Instance.new("ScreenGui")
-- 	screenGui.Name = "AdminChat"
-- 	screenGui.ResetOnSpawn = false
-- 	screenGui.Parent = playerGui
--     screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	
-- 	-- Main panel
-- 	local mainPanel = Instance.new("Frame")
-- 	mainPanel.Name = "MainPanel"
-- 	mainPanel.Size = UDim2.new(0, 300, 0, 200)
-- 	mainPanel.Position = UDim2.new(0.5, -225, 0, 20)
-- 	mainPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
-- 	mainPanel.BorderSizePixel = 0
-- 	mainPanel.Parent = screenGui
--     mainPanel.ZIndex = 1000
	
-- 	-- Add corner radius
-- 	local corner = Instance.new("UICorner")
-- 	corner.CornerRadius = UDim.new(0, 10)
-- 	corner.Parent = mainPanel
	
-- 	-- Title bar
-- 	local titleBar = Instance.new("TextLabel")
-- 	titleBar.Name = "TitleBar"
-- 	titleBar.Size = UDim2.new(1, 0, 0, 40)
-- 	titleBar.BackgroundColor3 = Color3.fromRGB(65, 120, 200)
-- 	titleBar.BorderSizePixel = 0
-- 	titleBar.Text = "⚙️ ADMIN COMMANDS"
-- 	titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
-- 	titleBar.TextSize = 15
-- 	titleBar.Font = Enum.Font.GothamBold
-- 	titleBar.Parent = mainPanel
--     titleBar.ZIndex = 1001
	
-- 	local titleCorner = Instance.new("UICorner")
-- 	titleCorner.CornerRadius = UDim.new(0, 10)
-- 	titleCorner.Parent = titleBar
	
-- 	-- Drag functionality for panel movement
-- 	local dragging = false
-- 	local dragOffset = Vector2.new(0, 0)
-- 	local mouse = Players.LocalPlayer:GetMouse()
	
-- 	titleBar.InputBegan:Connect(function(input, gameProcessed)
-- 		if gameProcessed then return end
-- 		if input.UserInputType == Enum.UserInputType.MouseButton1 then
-- 			dragging = true
-- 			dragOffset = Vector2.new(mouse.X, mouse.Y) - mainPanel.AbsolutePosition
-- 		end
-- 	end)
	
-- 	titleBar.InputEnded:Connect(function(input)
-- 		if input.UserInputType == Enum.UserInputType.MouseButton1 then
-- 			dragging = false
-- 		end
-- 	end)
	
-- 	mouse.Move:Connect(function()
-- 		if dragging then
-- 			local newPos = Vector2.new(mouse.X, mouse.Y) - dragOffset
-- 			mainPanel.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
-- 		end
-- 	end)
	
-- 	-- Close button
-- 	local closeBtn = Instance.new("TextButton")
-- 	closeBtn.Name = "CloseBtn"
-- 	closeBtn.Size = UDim2.new(0, 35, 0, 35)
-- 	closeBtn.Position = UDim2.new(1, -40, 0, 2)
-- 	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
-- 	closeBtn.BorderSizePixel = 0
-- 	closeBtn.Text = "X"
-- 	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
-- 	closeBtn.TextSize = 20
-- 	closeBtn.Font = Enum.Font.GothamBold
-- 	closeBtn.Parent = mainPanel
--     closeBtn.ZIndex = 1002
	
-- 	local closeBtnCorner = Instance.new("UICorner")
-- 	closeBtnCorner.CornerRadius = UDim.new(0, 5)
-- 	closeBtnCorner.Parent = closeBtn
	
-- 	-- Output/Chat display
-- 	local outputFrame = Instance.new("ScrollingFrame")
-- 	outputFrame.Name = "OutputFrame"
-- 	outputFrame.Size = UDim2.new(1, -10, 1, -100)
-- 	outputFrame.Position = UDim2.new(0, 5, 0, 45)
-- 	outputFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
-- 	outputFrame.BorderSizePixel = 0
-- 	outputFrame.ScrollBarThickness = 5
-- 	outputFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
-- 	outputFrame.Parent = mainPanel
--     outputFrame.ZIndex = 1003
	
-- 	local outputCorner = Instance.new("UICorner")
-- 	outputCorner.CornerRadius = UDim.new(0, 6)
-- 	outputCorner.Parent = outputFrame
	
-- 	-- Output layout
-- 	local outputLayout = Instance.new("UIListLayout")
-- 	outputLayout.Padding = UDim.new(0, 3)
-- 	outputLayout.Parent = outputFrame

-- 	-- Dynamically update CanvasSize for scrolling
-- 	outputLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
-- 		outputFrame.CanvasSize = UDim2.new(0, 0, 0, outputLayout.AbsoluteContentSize.Y)
-- 	end)
	
-- 	local inputBox = Instance.new("TextBox")
-- 	inputBox.Name = "InputBox"
-- 	inputBox.Size = UDim2.new(1, -10, 0, 35)
-- 	inputBox.Position = UDim2.new(0, 5, 1, -40)
-- 	inputBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
-- 	inputBox.BorderSizePixel = 0
-- 	inputBox.Text = ""
-- 	inputBox.PlaceholderText = "Type /command..."
-- 	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
-- 	inputBox.TextColor3 = Color3.fromRGB(230, 230, 240)
-- 	inputBox.TextSize = 13
-- 	inputBox.Font = Enum.Font.Gotham
-- 	inputBox.Parent = mainPanel
--     inputBox.ZIndex = 1005
-- 	local inputCorner = Instance.new("UICorner")
-- 	inputCorner.CornerRadius = UDim.new(0, 5)
-- 	inputCorner.Parent = inputBox
-- 	-- Input padding
-- 	local inputPadding = Instance.new("UIPadding")
-- 	inputPadding.PaddingLeft = UDim.new(0, 10)
-- 	inputPadding.PaddingRight = UDim.new(0, 10)
-- 	inputPadding.Parent = inputBox
-- 	-- Suggestion text label (above inputBox)
-- 	local suggestionLabel = Instance.new("TextLabel")
-- 	suggestionLabel.Name = "SuggestionLabel"
-- 	suggestionLabel.Size = UDim2.new(1, -10, 0, 22)
-- 	suggestionLabel.Position = UDim2.new(0, 5, 1, -62) -- 22px above inputBox
-- 	suggestionLabel.BackgroundTransparency = 1
-- 	suggestionLabel.Text = ""
-- 	suggestionLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
-- 	suggestionLabel.TextSize = 12
-- 	suggestionLabel.Font = Enum.Font.Gotham
-- 	suggestionLabel.TextXAlignment = Enum.TextXAlignment.Left
-- 	suggestionLabel.Parent = mainPanel
--     suggestionLabel.ZIndex = 1006

-- 	-- Input field
-- 	local inputBox = Instance.new("TextBox")
-- 	inputBox.Name = "InputBox"
-- 	inputBox.Size = UDim2.new(1, -10, 0, 35)
-- 	inputBox.Position = UDim2.new(0, 5, 1, -40)
-- 	inputBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
-- 	inputBox.BorderSizePixel = 0
-- 	inputBox.Text = ""
-- 	inputBox.PlaceholderText = "Type /command..."
-- 	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
-- 	inputBox.TextColor3 = Color3.fromRGB(230, 230, 240)
-- 	inputBox.TextSize = 13
-- 	inputBox.Font = Enum.Font.Gotham
-- 	inputBox.ZIndex = 2
-- 	inputBox.Parent = mainPanel
--     inputBox.ZIndex = 1007

-- 	local inputCorner = Instance.new("UICorner")
-- 	inputCorner.CornerRadius = UDim.new(0, 5)
-- 	inputCorner.Parent = inputBox

-- 	-- Input padding
-- 	local inputPadding = Instance.new("UIPadding")
-- 	inputPadding.PaddingLeft = UDim.new(0, 10)
-- 	inputPadding.PaddingRight = UDim.new(0, 10)
-- 	inputPadding.Parent = inputBox
	
-- 	-- Chat visibility state
-- 	local chatVisible = true
	
-- 	-- Available commands list
-- 	local commands = {
-- 		{name = "walkspeed", desc = "Set walk speed (0-200)"},
-- 		{name = "heal", desc = "Restore full health"},
-- 		{name = "teleport", desc = "Teleport to map [spawn]"},
-- 		{name = "tp", desc = "Short for teleport"},
-- 		{name = "maplist", desc = "Show all maps"},
-- 		{name = "maps", desc = "Short for maplist"},
-- 		{name = "spawns", desc = "Show map spawns"},
-- 		{name = "stats", desc = "Set all combat stats"},
-- 		{name = "resetstats", desc = "Reset stats, level, points (not inventory) [player]"},
-- 		{name = "clear", desc = "Clear chat"},
-- 		{name = "help", desc = "Show this message"},
-- 		{name = "commands", desc = "Short for help"},
-- 	}
	
-- 	-- Function to update suggestions
-- 	local function updateSuggestions(text)
-- 		-- Show suggestions as plain text above inputBox
-- 		if not text:match("^/") then
-- 			suggestionLabel.Text = ""
-- 			return
-- 		end

-- 		local cmdText = text:sub(2):lower()
-- 		if cmdText == "" then
-- 			suggestionLabel.Text = ""
-- 			return
-- 		end

-- 		local matches = {}
-- 		for _, cmd in ipairs(commands) do
-- 			if cmd.name:sub(1, #cmdText) == cmdText then
-- 				table.insert(matches, "/" .. cmd.name .. " - " .. cmd.desc)
-- 			end
-- 		end

-- 		if #matches > 0 then
-- 			suggestionLabel.Text = "Suggestions: " .. table.concat(matches, "   |   ")
-- 		else
-- 			suggestionLabel.Text = ""
-- 		end
-- 	end
	
-- 	-- Update suggestions on text change
-- 	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
-- 		updateSuggestions(inputBox.Text)
-- 	end)
	
-- 	-- Function to add message to output
-- 	local function addMessage(text, color)
-- 		color = color or Color3.fromRGB(210, 210, 220)
		
-- 		local messageLabel = Instance.new("TextLabel")
-- 		messageLabel.Size = UDim2.new(1, -10, 0, 20)
-- 		messageLabel.BackgroundTransparency = 1
-- 		messageLabel.Text = text
-- 		messageLabel.TextColor3 = color
-- 		messageLabel.TextSize = 12
-- 		messageLabel.Font = Enum.Font.Gotham
-- 		messageLabel.TextXAlignment = Enum.TextXAlignment.Left
-- 		messageLabel.TextWrapped = true
-- 		messageLabel.Parent = outputFrame
--         messageLabel.ZIndex = 1008
		
-- 		-- Auto scroll to bottom
-- 		outputFrame.CanvasPosition = Vector2.new(0, outputLayout.AbsoluteContentSize.Y)
-- 	end
	
-- 	-- Initial message
-- 	addMessage("✨ Admin Chat Ready! Type /help for commands", Color3.fromRGB(150, 200, 150))
	
-- 	-- Handle input
-- 	inputBox.FocusLost:Connect(function(enterPressed)
-- 		if enterPressed then
-- 			local command = inputBox.Text:match("^%s*(.-)%s*$") -- Trim whitespace
			
-- 			if command ~= "" then
-- 				-- Display command in chat
-- 				addMessage("> " .. command, Color3.fromRGB(100, 150, 255))
				
-- 				-- Parse and execute command
-- 				if command:sub(1, 1) == "/" then
-- 					parseCommand(command, addMessage)
-- 				else
-- 					addMessage("❌ Commands must start with /", Color3.fromRGB(255, 100, 100))
-- 				end
-- 			end
			
-- 			-- Clear input
-- 			inputBox.Text = ""
-- 		end
-- 	end)
	
-- 	-- Toggle visibility with F6
-- 	UserInputService.InputBegan:Connect(function(input, gameProcessed)
-- 		if gameProcessed then return end
		
-- 		if input.KeyCode == Enum.KeyCode.F6 then
-- 			chatVisible = not chatVisible
-- 			mainPanel.Visible = chatVisible
-- 		end
-- 	end)
	
	
-- 	-- Close button
-- 	closeBtn.MouseButton1Click:Connect(function()
-- 		chatVisible = false
-- 		mainPanel.Visible = false
-- 	end)
	
	
-- 	-- Hover effects
-- 	closeBtn.MouseEnter:Connect(function()
-- 		closeBtn.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
-- 	end)
-- 	closeBtn.MouseLeave:Connect(function()
-- 		closeBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
-- 	end)
	
	
-- 	return {
-- 		panel = mainPanel,
-- 		addMessage = addMessage,
-- 		inputBox = inputBox,
-- 	}
-- end

-- -- Create admin chat UI
-- local adminChat = nil

-- -- Hide admin chat by default
-- local function hideAdminChat()
-- 	if adminChat then
-- 		adminChat.panel.Visible = false
-- 	end
-- end

-- -- Show admin chat
-- local function showAdminChat()
-- 	if not adminChat then
-- 		adminChat = createAdminChat()
-- 	end
-- 	adminChat.panel.Visible = true
-- 	if adminChat.inputBox then
-- 		adminChat.inputBox:CaptureFocus()
-- 	end
-- end

-- hideAdminChat()

-- -- Listen for /admincommands in real chat
-- local function onPlayerChatted(msg)
-- 	if msg:lower() == "/admincommands" then
-- 		if adminChat and adminChat.panel.Visible then
-- 			hideAdminChat()
-- 		else
-- 			showAdminChat()
-- 		end
-- 	end
-- end

-- player.Chatted:Connect(onPlayerChatted)

-- print("[AdminChat] Ready! Type /admincommands in chat to open admin panel.")

-- -- Command parsing function
-- function parseCommand(message, outputFunc)
-- 	-- Remove leading/trailing whitespace
-- 	message = message:match("^%s*(.-)%s*$")

-- 	-- Check if message starts with /
-- 	if not message or message == "" then
-- 		return
-- 	end

-- 	if message:sub(1, 1) ~= "/" then
-- 		outputFunc("❌ Commands must start with /", Color3.fromRGB(255, 100, 100))
-- 		return
-- 	end

-- 	-- Split command and args
-- 	local command = message:sub(2)
-- 	local args = {}
-- 	for arg in command:gmatch("%S+") do
-- 		table.insert(args, arg)
-- 	end
-- 	if #args == 0 then return end
-- 	local cmd = args[1]:lower()

-- 	-- /walkspeed command
-- 	if cmd == "walkspeed" then
-- 		local speed = tonumber(args[2])
-- 		if not speed then
-- 			outputFunc("❌ Usage: /walkspeed <speed> (0-200)", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
-- 		speed = math.clamp(speed, 0, 200)
-- 		adminEvent:FireServer("WalkSpeed", speed)
-- 		outputFunc("🚶 Walk speed set to " .. speed, Color3.fromRGB(100, 200, 100))
    
-- 	-- /heal command
-- 	elseif cmd == "heal" then
-- 		adminEvent:FireServer("Heal")
-- 		outputFunc("❤️ Healed!", Color3.fromRGB(255, 150, 100))
    
-- 	-- /teleport command
-- 	elseif cmd == "teleport" or cmd == "tp" then
-- 		local mapName = args[2]
-- 		local spawnName = args[3] or "SpawnLocation"
        
-- 		if not mapName then
-- 			outputFunc("❌ Usage: /teleport <map> [spawn]", Color3.fromRGB(255, 100, 100))
-- 			outputFunc("Example: /teleport Grimleaf1", Color3.fromRGB(200, 150, 100))
-- 			return
-- 		end
        
-- 		adminEvent:FireServer("TeleportToMap", mapName, spawnName)
-- 		outputFunc("🌍 Teleporting to " .. mapName .. " @ " .. spawnName, Color3.fromRGB(100, 200, 255))
    
-- 	-- /maplist command
-- 	elseif cmd == "maplist" or cmd == "maps" then
-- 		local mapsFolder = workspace:FindFirstChild("Maps")
-- 		if not mapsFolder then
-- 			outputFunc("❌ No maps folder found", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		local mapList = {}
-- 		for _, mapFolder in ipairs(mapsFolder:GetChildren()) do
-- 			table.insert(mapList, mapFolder.Name)
-- 		end
        
-- 		if #mapList == 0 then
-- 			outputFunc("❌ No maps found", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		outputFunc("📍 Available Maps:", Color3.fromRGB(100, 200, 255))
-- 		for i, mapName in ipairs(mapList) do
-- 			outputFunc("  " .. i .. ". " .. mapName, Color3.fromRGB(180, 180, 180))
-- 		end
    
-- 	-- /spawns command
-- 	elseif cmd == "spawns" then
-- 		local mapName = args[2]
-- 		if not mapName then
-- 			outputFunc("❌ Usage: /spawns <map>", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		local mapsFolder = workspace:FindFirstChild("Maps")
-- 		if not mapsFolder then
-- 			outputFunc("❌ No maps folder found", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		local map = mapsFolder:FindFirstChild(mapName)
-- 		if not map then
-- 			outputFunc("❌ Map '" .. mapName .. "' not found", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		local spawnList = {}
-- 		for _, child in ipairs(map:GetChildren()) do
-- 			if child:IsA("BasePart") or child:IsA("Model") then
-- 				table.insert(spawnList, child.Name)
-- 			end
-- 		end
        
-- 		if #spawnList == 0 then
-- 			outputFunc("❌ No spawns found in map '" .. mapName .. "'", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		outputFunc("🚩 Spawns in " .. mapName .. ":", Color3.fromRGB(100, 200, 255))
-- 		for i, spawnName in ipairs(spawnList) do
-- 			outputFunc("  " .. i .. ". " .. spawnName, Color3.fromRGB(180, 180, 180))
-- 		end
    
-- 	-- /stats command
-- 	elseif cmd == "stats" then
-- 		local statValue = tonumber(args[2]) or 100
        
-- 		if statValue < 1 then
-- 			outputFunc("❌ Stat value must be at least 1", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
		
-- 		if statValue > 999999 then
-- 			outputFunc("❌ Stat value cannot exceed 999999", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
        
-- 		adminEvent:FireServer("Stats", statValue)
-- 		outputFunc("📊 Set all combat stats to " .. statValue .. " (Dexterity capped at 300)", Color3.fromRGB(255, 200, 100))
    
-- 	-- /resetstats command
-- 	elseif cmd == "resetstats" then
-- 		local targetName = args[2]
		
-- 		-- If no target specified, reset self
-- 		if not targetName then
-- 			adminEvent:FireServer("ResetStats")
-- 			outputFunc("🔄 Reset your stats, level, and points (Inventory kept)", Color3.fromRGB(255, 200, 100))
-- 			return
-- 		end
		
-- 		-- If target specified, only verified admins can do it
-- 		local adminType = AdminId.GetAdminType(player.UserId)
-- 		if adminType ~= "verified" then
-- 			outputFunc("❌ Only verified admins can reset other players' stats.", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
		
-- 		adminEvent:FireServer("ResetStats", targetName)
-- 		outputFunc("🔄 Reset stats, level, and points for " .. tostring(targetName) .. " (Inventory kept)", Color3.fromRGB(255, 200, 100))
	
-- 	-- /orb command
-- 	elseif cmd == "orb" then
-- 		local adminType = AdminId.GetAdminType(player.UserId)
-- 		local orbName, targetName
		
-- 		if #args == 2 then
-- 			-- Single argument: /orb orbName (give to self)
-- 			orbName = args[2]
-- 			targetName = player.Name
-- 			adminEvent:FireServer("Orb", orbName)
-- 			outputFunc("✨ Gave orb '" .. orbName .. "' to yourself!", Color3.fromRGB(255, 200, 100))
-- 		elseif #args == 3 then
-- 			-- Two arguments: /orb playerName orbName (only for verified admins)
-- 			if adminType ~= "verified" then
-- 				outputFunc("❌ Only verified admins can give orbs to other players.", Color3.fromRGB(255, 100, 100))
-- 				return
-- 			end
-- 			targetName = args[2]
-- 			orbName = args[3]
-- 			adminEvent:FireServer("Orb", targetName, orbName)
-- 			outputFunc("✨ Gave orb '" .. orbName .. "' to " .. targetName .. "!", Color3.fromRGB(255, 200, 100))
-- 		else
-- 			outputFunc("❌ Usage: /orb <orbName> OR /orb <player> <orbName>", Color3.fromRGB(255, 100, 100))
-- 			outputFunc("Example: /orb Fire  OR  /orb PlayerName Water", Color3.fromRGB(200, 150, 100))
-- 			return
-- 		end
	
-- 	-- /resetdata command (verified admins only)
-- 	elseif cmd == "resetdata" then
-- 		local adminType = AdminId.GetAdminType(player.UserId)
-- 		if adminType ~= "verified" then
-- 			outputFunc("❌ Only verified admins can use /resetdata.", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
-- 		local targetName = args[2]
-- 		if not targetName then
-- 			outputFunc("❌ Usage: /resetdata <player>", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
-- 		adminEvent:FireServer("ResetData", targetName)
-- 		outputFunc("🔄 Reset all data (stats, weapons, orbs, inventory) for " .. targetName, Color3.fromRGB(255, 200, 100))
	
-- 	-- /resetalldata command (verified admins only)
-- 	elseif cmd == "resetalldata" then
-- 		local adminType = AdminId.GetAdminType(player.UserId)
-- 		if adminType ~= "verified" then
-- 			outputFunc("❌ Only verified admins can use /resetalldata.", Color3.fromRGB(255, 100, 100))
-- 			return
-- 		end
-- 		adminEvent:FireServer("ResetAllData")
-- 		outputFunc("🔄 Reset all data for ALL players in the game!", Color3.fromRGB(255, 150, 0))
    
-- 	-- /help command
-- 	elseif cmd == "help" or cmd == "commands" then
-- 		outputFunc("📋 ADMIN COMMANDS:", Color3.fromRGB(100, 200, 255))
-- 		outputFunc("  /walkspeed <speed> - Set walk speed (0-200)", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /heal - Restore full health", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /teleport <map> [spawn] - Teleport to map", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /maplist - Show all maps", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /spawns <map> - Show map spawns", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /addlevel <amount> [player] - Add levels", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /resetstats [player] - Reset stats, level, points (not inventory)", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /resetdata <player> - Reset all data (verified only)", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /resetalldata - Reset all players data (verified only)", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /orb <orbName> OR /orb <player> <orbName> - Give orb to self or other (verified only)", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /clear - Clear chat", Color3.fromRGB(180, 180, 180))
-- 		outputFunc("  /help - Show this message", Color3.fromRGB(180, 180, 180))
    
-- 	-- /clear command
-- 	elseif cmd == "clear" then
-- 		-- Clear all messages except keep last one
-- 		for _, child in ipairs(adminChat.outputFrame:FindFirstChild("OutputFrame"):GetChildren()) do
-- 			if child:IsA("TextLabel") then
-- 				child:Destroy()
-- 			end
-- 		end
-- 		adminChat.addMessage("Chat cleared!", Color3.fromRGB(100, 200, 100))
-- 	else
-- 		outputFunc("❌ Unknown command: /" .. cmd .. " (Type /help)", Color3.fromRGB(255, 100, 100))
-- 	end
-- end

-- -- Create admin chat UI
-- local adminChat = nil

-- -- Hide admin chat by default
-- local function hideAdminChat()
-- 	if adminChat then
-- 		adminChat.panel.Visible = false
-- 	end
-- end

-- -- Show admin chat
-- local function showAdminChat()
-- 	if not adminChat then
-- 		adminChat = createAdminChat()
-- 	end
-- 	adminChat.panel.Visible = true
-- 	if adminChat.inputBox then
-- 		adminChat.inputBox:CaptureFocus()
-- 	end
-- end

-- -- Create toggle button in top-middle
-- createToggleButton(function()
-- 	if adminChat and adminChat.panel.Visible then
-- 		hideAdminChat()
-- 	else
-- 		showAdminChat()
-- 	end
-- end)

-- -- Start with panel hidden
-- hideAdminChat()

-- print("[AdminChat] Ready! Click the ⚙️ button at the top to open admin panel")
