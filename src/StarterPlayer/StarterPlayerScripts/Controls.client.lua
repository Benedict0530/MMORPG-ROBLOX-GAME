local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Get player stats
local stats = player:WaitForChild("Stats", 5)
local currentMana = stats and stats:WaitForChild("CurrentMana", 5)
local maxMana = stats and stats:WaitForChild("MaxMana", 5)

-- Disable default Roblox controls
local Controls = require(player.PlayerScripts.PlayerModule):GetControls()
Controls:Disable()

-- Disable default ShiftLock permanently
local playerModule = player.PlayerScripts.PlayerModule
local cameraModule = require(playerModule:WaitForChild("CameraModule"))
pcall(function() cameraModule:SetShiftLockMode(false) end)

-- Create RemoteEvent for sending running state to server
local runningEvent = ReplicatedStorage:FindFirstChild("PlayerRunning")
if not runningEvent then
	runningEvent = Instance.new("RemoteEvent")
	runningEvent.Name = "PlayerRunning"
	runningEvent.Parent = ReplicatedStorage
end

-- Movement settings
local MOVE_SPEED = 16
local SPRINT_SPEED = 25
local isSprinting = false

-- ========== VIRTUAL THUMBSTICK SETUP ==========
local thumbstickInput = Vector3.new(0, 0, 0)
local isOnMobile = UserInputService.TouchEnabled
local THUMBSTICK_DEADZONE = 0.05
local thumbstickActive = false
local currentTouchId = nil
local thumbstickY = 0
local thumbstickRadius = 0  -- Will be set from UI

-- Create thumbstick UI - uses existing UI structure
local function createThumbstick()
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Find existing thumbstick GUI elements
	local container = playerGui:WaitForChild("ThumbstickGui")
	local thumbstickArea = container:WaitForChild("Frame"):WaitForChild("ThumbStickArea")
	local background = thumbstickArea:WaitForChild("ThumbstickBackground")
	local thumb = thumbstickArea:WaitForChild("ThumbstickThumb")
	
	-- Set thumb anchor point to center for proper positioning
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Reset thumb to center of background
	thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	local thumbstickUI = {
		container = container,
		background = background,
		thumb = thumb,
		thumbstickArea = thumbstickArea
	}
	
	return thumbstickUI
end

local thumbstick = nil
if isOnMobile then
	thumbstick = createThumbstick()
end

-- Disable thumbstick GUI if touch is not enabled
local playerGui = player:WaitForChild("PlayerGui")
local thumbstickGui = playerGui:FindFirstChild("ThumbstickGui")
if thumbstickGui then
	thumbstickGui.Enabled = isOnMobile
end

-- Hide thumbstick area by default, show on touch
if isOnMobile and thumbstick then
	thumbstick.thumbstickArea.Visible = false
end

-- Setup attack button and pickup button visibility for mobile
local gameGui = playerGui:FindFirstChild("GameGui")
if gameGui then
	local frame = gameGui:FindFirstChild("Frame")
	if frame then
		local attackButton = frame:FindFirstChild("AttackButton")
		if attackButton then
			attackButton.Visible = isOnMobile
		end
		
		local pickupButton = frame:FindFirstChild("PickupButton")
		if pickupButton then
			pickupButton.Visible = isOnMobile
		end
	end
end

local hideThumbstickDebounce = nil
local function hideThumbstickArea()
	-- Only hide if no active touch
	if thumbstick and not currentTouchId then
		thumbstick.thumbstickArea.Visible = false
	end
end

-- Handle thumbstick input
local function handleThumbstickInput(input, gameProcessed)
	if not thumbstick then return end
	
	local touchPosition = input.Position
	local backgroundSize = thumbstick.background.AbsoluteSize
	local backgroundPos = thumbstick.background.AbsolutePosition
	
	-- Calculate relative position to thumbstick center
	local relativeX = touchPosition.X - (backgroundPos.X + backgroundSize.X / 2)
	local relativeY = touchPosition.Y - (backgroundPos.Y + backgroundSize.Y / 2)
	
	-- Calculate distance and angle
	local distance = math.sqrt(relativeX ^ 2 + relativeY ^ 2)
	-- Maximum distance is half the smaller dimension of the background (radius)
	local maxDistance = math.min(backgroundSize.X, backgroundSize.Y) / 2
	
	-- Clamp to radius
	if distance > maxDistance then
		relativeX = (relativeX / distance) * maxDistance
		relativeY = (relativeY / distance) * maxDistance
	end
	
	-- Update thumb position
	thumbstick.thumb.Position = UDim2.new(
		0.32,
		relativeX,
		0.45,
		relativeY
	)
	
	-- Calculate normalized input (-1 to 1)
	-- X axis is used (left = negative Z, right = positive Z)
	local inputX = relativeX / maxDistance
	local inputY = -relativeY / maxDistance
	
	-- Apply deadzone for X movement
	local magnitudeX = math.abs(inputX)
	if magnitudeX < THUMBSTICK_DEADZONE then
		inputX = 0
	else
		-- Scale outside deadzone
		local scale = (magnitudeX - THUMBSTICK_DEADZONE) / (1 - THUMBSTICK_DEADZONE)
		inputX = (inputX / magnitudeX) * scale
	end
	
	thumbstickInput = Vector3.new(-inputX, 0, 0)
	thumbstickActive = true
	thumbstickY = inputY
end

-- Handle thumbstick release
local function handleThumbstickRelease(input, gameProcessed)
	if not thumbstick then return end
	
	-- Reset thumb to center of background using background's center as reference
	local backgroundSize = thumbstick.background.AbsoluteSize
	thumbstick.thumb.Position = UDim2.new(0.32, 0, 0.45, 0)
	thumbstickInput = Vector3.new(0, 0, 0)
	thumbstickY = 0
	thumbstickActive = false
end

-- Detect if touch is on thumbstick
local function isTouchOnThumbstick(touchPosition)
	if not thumbstick then return false end
	
	local backgroundPos = thumbstick.background.AbsolutePosition
	local backgroundSize = thumbstick.background.AbsoluteSize
	
	return (
		touchPosition.X >= backgroundPos.X and
		touchPosition.X <= backgroundPos.X + backgroundSize.X and
		touchPosition.Y >= backgroundPos.Y and
		touchPosition.Y <= backgroundPos.Y + backgroundSize.Y
	)
end

-- Bind thumbstick inputs
if isOnMobile then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Handle thumbstick input if touch is on it
			if isTouchOnThumbstick(input.Position) and not currentTouchId then
				-- Show thumbstick only if touch is on it
				if thumbstick then
					thumbstick.thumbstickArea.Visible = true
				end
				currentTouchId = input
				handleThumbstickInput(input, gameProcessed)
			end
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and currentTouchId == input then
			handleThumbstickInput(input, gameProcessed)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and currentTouchId == input then
			currentTouchId = nil
			handleThumbstickRelease(input, gameProcessed)
			
			-- Schedule hiding thumbstick after a longer delay, but only if no new touch starts
			if hideThumbstickDebounce then
				task.cancel(hideThumbstickDebounce)
			end
			hideThumbstickDebounce = task.delay(1.5, hideThumbstickArea)
		end
	end)
end

-- Consume Shift key input to prevent Roblox ShiftLock and handle sprinting
ContextActionService:BindActionAtPriority("DisableShiftLock", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if inputState == Enum.UserInputState.Begin then
			-- Check if player has enough mana to sprint
			if currentMana and currentMana.Value > 0 then
				isSprinting = true
			else
				isSprinting = false
			end
		elseif inputState == Enum.UserInputState.End then
			isSprinting = false
			if humanoid then
				humanoid.WalkSpeed = MOVE_SPEED
			end
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift)


-- Track key states
local keysPressed = {
	D = false,
	A = false,
	W = false
}

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	runningEvent:FireServer(false)
	isSprinting = false
	lockedXPosition = nil
	
	if not stats then
		stats = player:WaitForChild("Stats", 5)
	end
	if stats then
		currentMana = stats:FindFirstChild("CurrentMana") or currentMana
		maxMana = stats:FindFirstChild("MaxMana") or maxMana
	end
end)

-- Handle input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.W then
		humanoid.Jump = true
	elseif keyCode == Enum.KeyCode.D then
		keysPressed.D = true
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.D then
		keysPressed.D = false
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = false
	end
end)

-- Store initial X position to lock it
local lockedXPosition = nil

-- Function to get spawn location X position
local function getSpawnLocationX()
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	return spawnLocation and spawnLocation.Position.X or nil
end

-- Handle movement each frame
RunService.RenderStepped:Connect(function()
	if not character or not humanoidRootPart or not humanoid then return end
	
	-- Lock X position on first frame
	if not lockedXPosition then
		lockedXPosition = getSpawnLocationX()
	end
	
	local moveDirection = Vector3.new(0, 0, 0)
	
	-- Handle keyboard input
	if keysPressed.D then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
	if keysPressed.A then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
	
	-- Handle thumbstick input
	if thumbstickActive and thumbstickInput.Magnitude > 0 then
		moveDirection = moveDirection + Vector3.new(0, 0, thumbstickInput.X)
	end
	
	-- Stop sprinting if mana depleted
	if isSprinting and currentMana and currentMana.Value <= 0 then
		isSprinting = false
	end
	
	-- Apply appropriate speed
	if isSprinting and moveDirection.Magnitude > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
	else
		humanoid.WalkSpeed = MOVE_SPEED
	end
	
	-- Notify server of running state
	runningEvent:FireServer(isSprinting and moveDirection.Magnitude > 0)
	
	-- Rotate character to face movement direction
	if moveDirection.Magnitude > 0 then
		local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + moveDirection)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.2)
	end
	
	-- Apply movement
	humanoid:Move(moveDirection, false)
	
	-- Handle continuous jump on thumbstick
	if thumbstickActive and thumbstickY > 0.5 and humanoid then
		humanoid.Jump = true
	end
	
	-- Enforce locked X position
	if lockedXPosition then
		local currentPos = humanoidRootPart.Position
		if math.abs(currentPos.X - lockedXPosition) > 0.01 then
			humanoidRootPart.CFrame = CFrame.new(lockedXPosition, currentPos.Y, currentPos.Z) * (humanoidRootPart.CFrame - humanoidRootPart.CFrame.Position)
		end
		
		local currentVel = humanoidRootPart.AssemblyLinearVelocity
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, currentVel.Z)
	end
end)


