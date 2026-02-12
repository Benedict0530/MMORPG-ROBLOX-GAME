-- DungeonUI Client Module
-- Table to store EntryItemButton click connections by button instance
local entryItemButtonConnections = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")

-- UI element references (loaded asynchronously)
local dungeonUI, dungeonTimer, background
local timerLabel, leaveButton, confirmation, yesBtn, noBtn
local closeButton, entryItemButton, robuxEntryButton
local titleLabel, descLabel, reqLabel, dropsFrame, dropsLabel

-- Function to safely get UI elements (non-blocking, instant check)
local function getUIElements()
	if not dungeonUI then
		dungeonUI = gameGui:FindFirstChild("DungeonUI")
	end
	if not dungeonTimer then
		dungeonTimer = gameGui:FindFirstChild("DungeonTimer")
	end
	if dungeonUI and not background then
		background = dungeonUI:FindFirstChild("Background")
	end
	if dungeonTimer then
		if not timerLabel then timerLabel = dungeonTimer:FindFirstChild("TextLabel") end
		if not leaveButton then leaveButton = dungeonTimer:FindFirstChild("LeaveButton") end
		if not confirmation then confirmation = dungeonTimer:FindFirstChild("Confirmation") end
		if confirmation then
			if not yesBtn then yesBtn = confirmation:FindFirstChild("Yes") end
			if not noBtn then noBtn = confirmation:FindFirstChild("No") end
		end
	end
	if background then
		if not closeButton then closeButton = background:FindFirstChild("CloseButton") end
		if not entryItemButton then entryItemButton = background:FindFirstChild("EntryItemButton") end
		if not robuxEntryButton then robuxEntryButton = background:FindFirstChild("RobuxEntryButton") end
		if not titleLabel then titleLabel = background:FindFirstChild("Title") end
		if not descLabel then descLabel = background:FindFirstChild("Description") end
		if not reqLabel then reqLabel = background:FindFirstChild("Requirement") end
		if not dropsFrame then dropsFrame = background:FindFirstChild("Drops") end
		if dropsFrame and not dropsLabel then dropsLabel = dropsFrame:FindFirstChild("TextLabel") end
	end
end

-- Function to wait for UI elements asynchronously with retries
local function waitForUIAsync(callback)
	task.spawn(function()
		local maxRetries = 50
		local retries = 0
		while retries < maxRetries do
			getUIElements()
			if dungeonUI and dungeonTimer and background and timerLabel then
				--print("[DungeonUI] All UI elements loaded successfully")
				if callback then callback() end
				return
			end
			retries = retries + 1
			task.wait(0.1)
		end
		warn("[DungeonUI] Failed to load all UI elements after", maxRetries, "retries")
	end)
end

-- Start loading UI asynchronously
waitForUIAsync()

-- Always use WaitForChild for RemoteEvents created by the server (with timeout)
local DungeonLeaveEvent = ReplicatedStorage:WaitForChild("DungeonLeaveEvent", 30)
local DungeonUIEvent = ReplicatedStorage:WaitForChild("DungeonUIEvent", 30)
local DungeonEntryEvent = ReplicatedStorage:WaitForChild("DungeonEntryEvent", 30)

-- Get DungeonTimers folder with retry logic
local DungeonTimersFolder = ReplicatedStorage:WaitForChild("DungeonTimers", 30)

if not DungeonLeaveEvent or not DungeonUIEvent or not DungeonEntryEvent then
	warn("[DungeonUI] Failed to load one or more RemoteEvents! Script may not work properly.")
end

if not DungeonTimersFolder then
	warn("[DungeonUI] DungeonTimers folder not found, retrying...")
	-- Retry with longer timeout
	DungeonTimersFolder = ReplicatedStorage:WaitForChild("DungeonTimers", 60)
	if not DungeonTimersFolder then
		error("[DungeonUI] CRITICAL: Failed to load DungeonTimers folder after extended wait. Timer functionality will not work.")
		return
	end
end

--print("[DungeonUI] DungeonTimers folder loaded successfully")

local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules", 10):WaitForChild("DungeonsData", 10))

-- Setup LeaveButton, Confirmation, and CloseButton logic
task.spawn(function()
	-- Wait for UI to load before setting up buttons
	local maxWait = 100
	local waited = 0
	while waited < maxWait do
		getUIElements()
		if leaveButton and confirmation and yesBtn and noBtn and closeButton then
			break
		end
		waited = waited + 1
		task.wait(0.05)
	end
	
	if leaveButton and (leaveButton:IsA("ImageButton") or leaveButton:IsA("TextButton")) then
		leaveButton.MouseButton1Click:Connect(function()
			--print("[DungeonUI] LeaveButton pressed")
			if confirmation then
				confirmation.Visible = true
			end
		end)
		--print("[DungeonUI] LeaveButton connected")
	end

	if yesBtn and (yesBtn:IsA("ImageButton") or yesBtn:IsA("TextButton")) then
		yesBtn.MouseButton1Click:Connect(function()
			--print("[DungeonUI] Confirmation YES pressed")
			if confirmation then
				confirmation.Visible = false
			end
			DungeonLeaveEvent:FireServer()
		end)
		--print("[DungeonUI] YesBtn connected")
	end

	if noBtn and (noBtn:IsA("ImageButton") or noBtn:IsA("TextButton")) then
		noBtn.MouseButton1Click:Connect(function()
			--print("[DungeonUI] Confirmation NO pressed")
			if confirmation then
				confirmation.Visible = false
			end
		end)
		--print("[DungeonUI] NoBtn connected")
	end

	if closeButton and (closeButton:IsA("ImageButton") or closeButton:IsA("TextButton")) then
		closeButton.MouseButton1Click:Connect(function()
			--print("[DungeonUI] CloseButton pressed, hiding DungeonUI")
			if dungeonUI then
				dungeonUI.Visible = false
			end
		end)
		--print("[DungeonUI] CloseButton connected")
	end
end)
-- DungeonTimer UI logic using IntValue tracking
local timerConn = nil
local timerValueConn = nil
local currentTimerValue = nil

-- Function to start/update timer UI based on IntValue
local function updateTimerUI(endTime)
	-- Try to get UI elements (instant check, non-blocking)
	getUIElements()
	
	-- Validate endTime is in the future
	local currentTime = tick()
	if not endTime or endTime <= currentTime then
		--print("[DungeonUI] Timer endTime invalid or expired, hiding timer. endTime:", endTime, "currentTime:", currentTime, "diff:", endTime and (endTime - currentTime) or "nil")
		if dungeonTimer then
			dungeonTimer.Visible = false
		end
		if timerConn then timerConn:Disconnect() timerConn = nil end
		return
	end
	
	-- Retry logic to ensure UI is loaded
	local retries = 0
	local maxRetries = 30
	while (not dungeonTimer or not timerLabel) and retries < maxRetries do
		task.wait(0.1)
		getUIElements()
		retries = retries + 1
	end
	
	if not dungeonTimer or not timerLabel then
		warn("[DungeonUI] DungeonTimer UI still not found after", maxRetries, "retries!")
		return
	end
	
	--print("[DungeonUI] Showing DungeonTimer with", endTime - tick(), "seconds remaining")
	dungeonTimer.Visible = true
	if dungeonUI and dungeonUI.Visible then
		dungeonUI.Visible = false
	end
	
	-- Disconnect old timer if exists
	if timerConn then timerConn:Disconnect() end
	
	-- Create new timer connection
	timerConn = RunService.RenderStepped:Connect(function()
		local remaining = math.max(0, math.floor(endTime - tick()))
		local min = math.floor(remaining / 60)
		local sec = remaining % 60
		if timerLabel then
			timerLabel.Text = string.format("%02d:%02d", min, sec)
		end
		if remaining <= 0 then
			if dungeonTimer then
				dungeonTimer.Visible = false
			end
			if timerConn then timerConn:Disconnect() timerConn = nil end
		end
	end)
	--print("[DungeonUI] DungeonTimer shown and timer started.")
end

-- Watch for player's IntValue in DungeonTimers folder
task.spawn(function()
	-- Ensure DungeonTimersFolder exists before proceeding
	if not DungeonTimersFolder then
		warn("[DungeonUI] Cannot setup timer tracking - DungeonTimers folder is nil")
		return
	end
	
	local userId = tostring(player.UserId)
	--print("[DungeonUI] Setting up timer tracking for userId:", userId)
	
	-- Function to setup timer value listener
	-- NOTE: IntValue contains REMAINING SECONDS, not absolute endTime
	local function setupTimerValue(timerValue)
		if currentTimerValue == timerValue then return end
		
		-- Disconnect old connection
		if timerValueConn then
			timerValueConn:Disconnect()
			timerValueConn = nil
		end
		
		currentTimerValue = timerValue
		
		-- Initial update - wait a moment for server to set the value if it's still 0
		if timerValue.Value > 0 then
			-- Convert remaining seconds to local endTime
			local localEndTime = tick() + timerValue.Value
			--print("[DungeonUI] Timer loaded with", timerValue.Value, "seconds remaining, localEndTime:", localEndTime)
			updateTimerUI(localEndTime)
		else
			-- Value not set yet, wait for it with timeout
			--print("[DungeonUI] Timer IntValue is 0, waiting for server to set value...")
			task.spawn(function()
				local waited = 0
				while timerValue.Value <= 0 and waited < 30 do
					task.wait(0.1)
					waited = waited + 1
				end
				if timerValue.Value > 0 then
					local localEndTime = tick() + timerValue.Value
					--print("[DungeonUI] Timer IntValue set to:", timerValue.Value, "seconds, localEndTime:", localEndTime)
					updateTimerUI(localEndTime)
				else
					warn("[DungeonUI] Timer IntValue never set by server after 3 seconds")
				end
			end)
		end
		
		-- Listen for changes (new remaining seconds from server)
		timerValueConn = timerValue.Changed:Connect(function(newRemainingSeconds)
			if newRemainingSeconds > 0 then
				local localEndTime = tick() + newRemainingSeconds
				--print("[DungeonUI] Timer IntValue changed to:", newRemainingSeconds, "seconds, localEndTime:", localEndTime)
				updateTimerUI(localEndTime)
			else
				--print("[DungeonUI] Timer expired (0 seconds remaining)")
				updateTimerUI(0)
			end
		end)
		
		--print("[DungeonUI] Setup timer tracking for userId:", userId)
	end
	
	-- Check if IntValue already exists
	local existingTimer = DungeonTimersFolder:FindFirstChild(userId)
	if existingTimer then
		setupTimerValue(existingTimer)
	end
	
	-- Listen for IntValue creation
	DungeonTimersFolder.ChildAdded:Connect(function(child)
		if child.Name == userId and child:IsA("IntValue") then
			--print("[DungeonUI] Timer IntValue created for player")
			setupTimerValue(child)
		end
	end)
	
	-- Listen for IntValue removal
	DungeonTimersFolder.ChildRemoved:Connect(function(child)
		if child.Name == userId then
			--print("[DungeonUI] Timer IntValue removed, hiding timer")
			if dungeonTimer then
				dungeonTimer.Visible = false
			end
			if timerConn then
				timerConn:Disconnect()
				timerConn = nil
			end
			if timerValueConn then
				timerValueConn:Disconnect()
				timerValueConn = nil
			end
			currentTimerValue = nil
		end
	end)
end)

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

-- Utility to get the current dungeon name (from PlayerMap stat)
local function getCurrentDungeonName()
	local stats = player:FindFirstChild("Stats")
	if stats then
		local playerMap = stats:FindFirstChild("PlayerMap")
		if playerMap then
			return playerMap.Value
		end
	end
	return nil
end


-- When DungeonUIEvent is fired, show DungeonUI and set all info
DungeonUIEvent.OnClientEvent:Connect(function(toMap)
	-- Try to get UI elements (instant check)
	getUIElements()
	
	-- Retry logic for UI loading
	local retries = 0
	local maxRetries = 30
	while (not dungeonUI or not background) and retries < maxRetries do
		task.wait(0.1)
		getUIElements()
		retries = retries + 1
	end
	
	if not dungeonUI or not background then
		warn("[DungeonUI] DungeonUI not found after", maxRetries, "retries!")
		return
	end
	
	--print("[DungeonUI] Showing DungeonUI for map:", toMap)
	dungeonUI.Visible = true

	-- Center the background in the screen
	if playerGui then
		local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local bgSize = background.Size
		if typeof(bgSize) == "UDim2" then
			-- If using scale, just center with anchor point
			background.AnchorPoint = Vector2.new(0.5, 0.5)
			background.Position = UDim2.new(0.5, 0, 0.5, 0)
		else
			-- Fallback: set to center using offset
			background.Position = UDim2.new(0, (viewportSize.X - bgSize.X.Offset) / 2, 0, (viewportSize.Y - bgSize.Y.Offset) / 2)
		end
	end

	local data = DungeonsData[toMap]

	-- Entry Item Button logic
	if entryItemButton and (entryItemButton:IsA("TextButton") or entryItemButton:IsA("ImageButton")) then
		--print("[DungeonUI] EntryItemButton found, setting up click handler.")
		-- Remove previous connection for this button if it exists
		if entryItemButtonConnections[entryItemButton] then
			entryItemButtonConnections[entryItemButton]:Disconnect()
			entryItemButtonConnections[entryItemButton] = nil
		end
		local newConn = entryItemButton.MouseButton1Click:Connect(function()
			--print("[DungeonUI] EntryItemButton clicked for map:", toMap)
			-- Hide the DungeonUI
			dungeonUI.Visible = false
			if DungeonEntryEvent then
				--print("[DungeonUI] Firing DungeonEntryEvent to server for map:", toMap)
				DungeonEntryEvent:FireServer(toMap)
			else
				warn("[DungeonUI] DungeonEntryEvent RemoteEvent not found in ReplicatedStorage!")
			end
		end)
		entryItemButtonConnections[entryItemButton] = newConn
	else
		--print("[DungeonUI] EntryItemButton not found or not a Button.")
	end

	-- Robux Entry Button logic
	if robuxEntryButton and (robuxEntryButton:IsA("TextButton") or robuxEntryButton:IsA("ImageButton")) then
		--print("[DungeonUI] RobuxEntryButton found, setting up click handler.")
		if entryItemButtonConnections[robuxEntryButton] then
			entryItemButtonConnections[robuxEntryButton]:Disconnect()
			entryItemButtonConnections[robuxEntryButton] = nil
		end
		local newConn = robuxEntryButton.MouseButton1Click:Connect(function()
			--print("[DungeonUI] RobuxEntryButton clicked for map:", toMap)
			dungeonUI.Visible = false
			-- Fire to server to register pending Robux dungeon entry
			if DungeonEntryEvent then
				DungeonEntryEvent:FireServer(toMap, true)
			end
			-- Prompt player to purchase developer product (10 Robux)
			local DEV_PRODUCT_ID = 3525149275 -- REPLACE with your actual Developer Product ID for 10 Robux
			if DEV_PRODUCT_ID == 0 then
				warn("[DungeonUI] Please set the correct Developer Product ID for Robux entry!")
				showCenterScreenMessage("Robux entry not configured.", 2.5)
				return
			end
			MarketplaceService:PromptProductPurchase(player, DEV_PRODUCT_ID)
		end)
		entryItemButtonConnections[robuxEntryButton] = newConn
	end

	-- Set Title
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = tostring(toMap)
	end

	-- Set Drops
	if dropsLabel and dropsLabel:IsA("TextLabel") then
		if data and data.DropsText then
			dropsLabel.Text = data.DropsText
		else
			dropsLabel.Text = ""
		end
	end

	-- Set Description
	if descLabel and descLabel:IsA("TextLabel") then
		if data and data.Story then
			descLabel.Text = data.Story
		else
			descLabel.Text = ""
		end
	end

	-- Set Requirement
	if reqLabel and reqLabel:IsA("TextLabel") then
		if data then
			local reqs = {}
			if data.EntryLevelRequirement then
				table.insert(reqs, "Level: " .. tostring(data.EntryLevelRequirement))
			end
			if data.EntryItemRequirement then
				table.insert(reqs, "Dungeon Entry: " .. tostring(data.EntryItemRequirement))
			end
			if data.TimeLimitMinutes then
				table.insert(reqs, "Time Limit: " .. tostring(data.TimeLimitMinutes) .. " min")
			end
			reqLabel.Text = #reqs > 0 and table.concat(reqs, "\n") or ""
		else
			reqLabel.Text = ""
		end
	end

end)

-- Listen for DungeonEntryEvent fired back from server for failure
DungeonEntryEvent.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.success == false and data.reason then
		showCenterScreenMessage(data.reason, 2.5)
	end
end)
-- (Removed duplicate label-setting code from DungeonEntryEvent.OnClientEvent)
