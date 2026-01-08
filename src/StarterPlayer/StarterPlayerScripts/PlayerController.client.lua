-- PlayerController.client.lua
-- Combined script for movement controls and weapon handling

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- BindableEvent for weapon change (for GUI update)
local weaponChangedEvent = ReplicatedStorage:FindFirstChild("WeaponChangedEvent")
if not weaponChangedEvent then
	weaponChangedEvent = Instance.new("BindableEvent")
	weaponChangedEvent.Name = "WeaponChangedEvent"
	weaponChangedEvent.Parent = ReplicatedStorage
end

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

-- ========== MOVEMENT SETTINGS ==========
local MOVE_SPEED = 12
local SPRINT_SPEED = 25
local isSprinting = false

-- ========== ANIMATION TRACKING ==========
local animator = humanoid:FindFirstChildOfClass("Animator")
local currentAnimationTrack = nil
local isWalking = false
local lastAnimationType = nil

-- ========== INPUT TRACKING ==========
local keysPressed = {
	D = false,
	A = false,
	W = false
}

-- ========== WEAPON SETTINGS ==========
local lastAttackTimes = {}
local currentTool = nil
local isSpaceHeld = false
local attackLoopConnection = nil
local attackAnimationConnection = nil
local isAttacking = false
local isAnimationInProgress = false
local heldAttackOverride = false -- If true, weapon speed is forced to 2
local attackPressStartTime = 0
local ATTACK_HOLD_THRESHOLD = 0.2 -- seconds to consider as 'held'

-- ========== THUMBSTICK SETUP ==========
local thumbstickInput = Vector3.new(0, 0, 0)
local isOnMobile = UserInputService.TouchEnabled
local THUMBSTICK_DEADZONE = 0.05
local thumbstickActive = false
local currentTouchId = nil
local thumbstickY = 0

local function createThumbstick()
	local playerGui = player:WaitForChild("PlayerGui")
	
	local container = playerGui:WaitForChild("ThumbstickGui")
	local thumbstickArea = container:WaitForChild("Frame"):WaitForChild("ThumbStickArea")
	local background = thumbstickArea:WaitForChild("ThumbstickBackground")
	local thumb = thumbstickArea:WaitForChild("ThumbstickThumb")
	
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	return {
		container = container,
		background = background,
		thumb = thumb,
		thumbstickArea = thumbstickArea
	}
end

local thumbstick = nil
if isOnMobile then
	thumbstick = createThumbstick()
end

local playerGui = player:WaitForChild("PlayerGui")
local thumbstickGui = playerGui:FindFirstChild("ThumbstickGui")
if thumbstickGui then
	thumbstickGui.Enabled = isOnMobile
end

if isOnMobile and thumbstick then
	thumbstick.thumbstickArea.Visible = false
end

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
		
		local jumpButton = frame:FindFirstChild("JumpButton")
		if jumpButton then
			jumpButton.Visible = isOnMobile
		end
	end
end

-- ========== EVENT CONNECTIONS ==========
local childAddedConnection
local childRemovedConnection
local attackButtonConnection
local hideThumbstickDebounce

-- ========== CHARACTER SETUP ==========
local function setupCharacter(newCharacter)
	-- Disconnect old connections
	if childAddedConnection then childAddedConnection:Disconnect() end
	if childRemovedConnection then childRemovedConnection:Disconnect() end
	
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	animator = humanoid:FindFirstChildOfClass("Animator")
	currentTool = nil
	lastAttackTimes = {}
	isWalking = false
	currentAnimationTrack = nil
	lastAnimationType = nil
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
	
	-- Reconnect to new character

	childAddedConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentTool = child
			-- Fire event for GUI update
			local weaponChangedEvent = ReplicatedStorage:FindFirstChild("WeaponChangedEvent")
			if weaponChangedEvent and weaponChangedEvent:IsA("BindableEvent") then
				weaponChangedEvent:Fire()
			end
			-- Play Idle animation on loop when weapon is equipped
			local idleAnimation = child:FindFirstChild("Idle")
			if idleAnimation and idleAnimation:IsA("Animation") then
				if animator then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						track:Stop()
					end
					local track = animator:LoadAnimation(idleAnimation)
					track.Looped = true
					track:Play()
				end
			end
		end
	end)


	childRemovedConnection = character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and currentTool == child then
			currentTool = nil
			-- Fire event for GUI update
			local weaponChangedEvent = ReplicatedStorage:FindFirstChild("WeaponChangedEvent")
			if weaponChangedEvent and weaponChangedEvent:IsA("BindableEvent") then
				weaponChangedEvent:Fire()
			end
		end
	end)
end

setupCharacter(character)

player.CharacterAdded:Connect(function(newCharacter)
	setupCharacter(newCharacter)
end)

-- ========== ATTACK FUNCTION ==========
local function stopAttackAndRestoreIdle()
	if attackAnimationConnection then
		attackAnimationConnection:Disconnect()
		attackAnimationConnection = nil
	end
	isAttacking = false
	
	-- Stop all animations and restore idle
	if animator and currentTool then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			t:Stop()
		end
		
		local idleAnimation = currentTool:FindFirstChild("Idle")
		if idleAnimation and idleAnimation:IsA("Animation") then
			local idleTrack = animator:LoadAnimation(idleAnimation)
			idleTrack.Looped = true
			idleTrack:Play()
		end
	end
end

local function performAttack(tool)
	if not tool or not tool.Name then return end
	if isAnimationInProgress then return end
	isAnimationInProgress = true

	-- Wait for hold threshold if holding
	if heldAttackOverride then
		local holdTime = tick() - attackPressStartTime
		if holdTime < ATTACK_HOLD_THRESHOLD then
			task.wait(ATTACK_HOLD_THRESHOLD - holdTime)
		end
	end

	local attackAnimName = "Attack1"
	local attackAnimation = tool:FindFirstChild(attackAnimName)
	if attackAnimation and attackAnimation:IsA("Animation") then
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
			local track = animator:LoadAnimation(attackAnimation)
			-- Get weapon speed for animation duration (client-side only for animation pacing)
			local weaponStats = WeaponData.GetWeaponStats(tool.Name)
			local weaponSpeed = weaponStats and weaponStats.speed or 1
			if heldAttackOverride then
				weaponSpeed = 2
			else
				weaponSpeed = 1.4
			end
			local animationLength = track.Length
			local actualDuration = animationLength - (animationLength / weaponSpeed)
			print("Playing attack animation with duration: " .. tostring(actualDuration))
			if attackAnimationConnection then
				attackAnimationConnection:Disconnect()
			end
			isAttacking = true

			-- Listen for the "Hit" marker in the animation
			local swingEvent = tool:FindFirstChild("SwingEvent")
			local markerConn
			if swingEvent and track then
				markerConn = track:GetMarkerReachedSignal("Hit"):Connect(function()
					swingEvent:FireServer()
					-- Play attack sound at hit frame
					-- SoundModule.playSoundByName("AttackAudio", "SFX", false, 1)
					-- If attack input is still held, play sound again for next attack
					if isSpaceHeld or heldAttackOverride then
						-- (Optional: could trigger next attack here, but sound is played again on next attack anyway)
					end
				end)
			end

			track:Play()
			-- Initial attack sound is now played at hit frame, not here
			task.wait(actualDuration)
			if markerConn then markerConn:Disconnect() end
			if track and track.Parent then
				track:Stop()
			end
			if animator and tool then
				local idleAnimation = tool:FindFirstChild("Idle")
				if idleAnimation and idleAnimation:IsA("Animation") then
					for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
						t:Stop()
					end
					local idleTrack = animator:LoadAnimation(idleAnimation)
					idleTrack.Looped = true
					idleTrack:Play()
				end
			end
			isAttacking = false
			isAnimationInProgress = false
		else
			isAnimationInProgress = false
		end
	else
		isAnimationInProgress = false
	end
end

-- ========== THUMBSTICK FUNCTIONS ==========
local function handleThumbstickInput(input, gameProcessed)
	if not thumbstick then return end
	
	local touchPosition = input.Position
	local backgroundSize = thumbstick.background.AbsoluteSize
	local backgroundPos = thumbstick.background.AbsolutePosition
	
	local relativeX = touchPosition.X - (backgroundPos.X + backgroundSize.X / 2)
	local relativeY = touchPosition.Y - (backgroundPos.Y + backgroundSize.Y / 2)
	
	local distance = math.sqrt(relativeX ^ 2 + relativeY ^ 2)
	local maxDistance = math.min(backgroundSize.X, backgroundSize.Y) / 2
	
	if distance > maxDistance then
		relativeX = (relativeX / distance) * maxDistance
		relativeY = (relativeY / distance) * maxDistance
	end
	
	thumbstick.thumb.Position = UDim2.new(0.32, relativeX, 0.45, relativeY)
	
	local inputX = relativeX / maxDistance
	local inputY = -relativeY / maxDistance
	
	local magnitudeX = math.abs(inputX)
	if magnitudeX < THUMBSTICK_DEADZONE then
		inputX = 0
	else
		local scale = (magnitudeX - THUMBSTICK_DEADZONE) / (1 - THUMBSTICK_DEADZONE)
		inputX = (inputX / magnitudeX) * scale
	end
	
	thumbstickInput = Vector3.new(-inputX, 0, 0)
	thumbstickActive = true
	thumbstickY = inputY
end

local function handleThumbstickRelease(input, gameProcessed)
	if not thumbstick then return end
	
	thumbstick.thumb.Position = UDim2.new(0.32, 0, 0.45, 0)
	thumbstickInput = Vector3.new(0, 0, 0)
	thumbstickY = 0
	thumbstickActive = false
end

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

local function hideThumbstickArea()
	if thumbstick and not currentTouchId then
		thumbstick.thumbstickArea.Visible = false
	end
end

-- ========== ATTACK BUTTON SETUP ==========
local function setupAttackButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local attackButton = frame:FindFirstChild("AttackButton")
	if not attackButton then return end
	
	attackButton.Visible = UserInputService.TouchEnabled
	
	if attackButtonConnection then
		attackButtonConnection:Disconnect()
	end
	
	attackButton.MouseButton1Down:Connect(function()
		if not currentTool then return end
		isSpaceHeld = true
		heldAttackOverride = true
		attackPressStartTime = tick()
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if not isSpaceHeld or not currentTool then
				return
			end
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			-- Only perform attack if animation is not currently in progress
			if not isAnimationInProgress then
				performAttack(currentTool)
			end
		end)
	end)
    
	attackButton.MouseButton1Up:Connect(function()
		isSpaceHeld = false
		heldAttackOverride = false
		attackPressStartTime = 0
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
		-- Allow current animation to finish naturally
	end)
end

-- ========== RUN BUTTON SETUP ==========
local function setupRunButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local runButton = frame:FindFirstChild("RunButton")
	if not runButton then return end
	
	runButton.Visible = UserInputService.TouchEnabled
	
	runButton.MouseButton1Down:Connect(function()
		if currentMana and currentMana.Value > 0 then
			isSprinting = true
		else
			isSprinting = false
		end
	end)
	
	runButton.MouseButton1Up:Connect(function()
		isSprinting = false
		if humanoid then
			humanoid.WalkSpeed = MOVE_SPEED
		end
	end)
end

-- ========== JUMP BUTTON SETUP ==========
local function setupJumpButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local jumpButton = frame:FindFirstChild("JumpButton")
	if not jumpButton then return end
	
	jumpButton.Visible = UserInputService.TouchEnabled
	
	jumpButton.MouseButton1Up:Connect(function()
		if humanoid then
			humanoid.Jump = true
		end
		
		-- Play weapon Jump animation if available
		local tool = nil
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				tool = child
				break
			end
		end
		if tool and animator then
			local jumpAnim = tool:FindFirstChild("Jump")
			if jumpAnim and jumpAnim:IsA("Animation") then
				-- Stop all current animations before playing jump
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				currentAnimationTrack = animator:LoadAnimation(jumpAnim)
				currentAnimationTrack.Looped = false
				currentAnimationTrack:Play()
				lastAnimationType = "Jump"
				print("Playing jump animation")
				-- After any non-looping animation finishes, restore idle if not attacking or moving
				currentAnimationTrack.Stopped:Connect(function()
					if not isAttacking and animator and tool then
						local moveDirection = Vector3.new(0, 0, 0)
						if keysPressed.D then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
						if keysPressed.A then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
						if thumbstickActive and thumbstickInput.Magnitude > 0 then
							moveDirection = moveDirection + Vector3.new(0, 0, thumbstickInput.X)
						end
						if moveDirection.Magnitude == 0 then
							local idleAnimation = tool:FindFirstChild("Idle")
							if idleAnimation and idleAnimation:IsA("Animation") then
								for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
									t:Stop()
								end
								local idleTrack = animator:LoadAnimation(idleAnimation)
								idleTrack.Looped = true
								idleTrack:Play()
								currentAnimationTrack = idleTrack
								lastAnimationType = "Idle"
							end
						end
					end
				end)
			end
		end
	end)
end

task.wait(0.5)
setupAttackButton()
setupRunButton()
setupJumpButton()

-- ========== INPUT HANDLING ==========

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
    
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.W then
		humanoid.Jump = true
		-- Play weapon Jump animation if available
		local tool = nil
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				tool = child
				break
			end
		end
		if tool and animator then
			local jumpAnim = tool:FindFirstChild("Jump")
			if jumpAnim and jumpAnim:IsA("Animation") then
				-- Stop all current animations before playing jump
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				currentAnimationTrack = animator:LoadAnimation(jumpAnim)
				currentAnimationTrack.Looped = false
				currentAnimationTrack:Play()
				lastAnimationType = "Jump"
				print("Playing jump animation")
				-- After any non-looping animation finishes, restore idle if not attacking or moving
				currentAnimationTrack.Stopped:Connect(function()
					if not isAttacking and animator and tool then
						local moveDirection = Vector3.new(0, 0, 0)
						if keysPressed.D then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
						if keysPressed.A then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
						if thumbstickActive and thumbstickInput.Magnitude > 0 then
							moveDirection = moveDirection + Vector3.new(0, 0, thumbstickInput.X)
						end
						if moveDirection.Magnitude == 0 then
							local idleAnimation = tool:FindFirstChild("Idle")
							if idleAnimation and idleAnimation:IsA("Animation") then
								for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
									t:Stop()
								end
								local idleTrack = animator:LoadAnimation(idleAnimation)
								idleTrack.Looped = true
								idleTrack:Play()
								currentAnimationTrack = idleTrack
								lastAnimationType = "Idle"
							end
						end
					end
				end)
			end
		end
	elseif keyCode == Enum.KeyCode.D then
		keysPressed.D = true
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = true
	elseif keyCode == Enum.KeyCode.Space then
		if not currentTool then
			return
		end
		isSpaceHeld = true
		heldAttackOverride = true
		attackPressStartTime = tick()
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if not isSpaceHeld or not currentTool then
				return
			end
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			-- Only perform attack if animation is not currently in progress
			if not isAnimationInProgress then
				performAttack(currentTool)
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.D then
		keysPressed.D = false
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = false
	elseif keyCode == Enum.KeyCode.Space then
		isSpaceHeld = false
		heldAttackOverride = false
		attackPressStartTime = 0
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
		-- Allow current animation to finish naturally
	end
end)

-- ========== MOBILE THUMBSTICK INPUT ==========
if isOnMobile then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			if isTouchOnThumbstick(input.Position) and not currentTouchId then
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
			
			if hideThumbstickDebounce then
				task.cancel(hideThumbstickDebounce)
			end
			hideThumbstickDebounce = task.delay(1.5, hideThumbstickArea)
		end
	end)
end

-- ========== SPRINT HANDLING ==========
ContextActionService:BindActionAtPriority("DisableShiftLock", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if inputState == Enum.UserInputState.Begin then
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

-- ========== TELEPORT GUI FADE ========== 
local function showTeleportFade()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local teleportGui = playerGui:FindFirstChild("TeleportGui")
    if not teleportGui then return end
    local frame = teleportGui:FindFirstChild("Frame")
    if not frame then return end
    teleportGui.Enabled = true
    frame.BackgroundTransparency = 0
    frame.Visible = true
    -- Tween fade out
    local tweenService = game:GetService("TweenService")
    local tween = tweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 1})
    tween:Play()
    tween.Completed:Wait()
    teleportGui.Enabled = false
    frame.BackgroundTransparency = 0 -- reset for next use
end

-- ========== TELEPORT GUI FADE WITH TYPING ========== 
local function showTeleportFadeWithMap(mapName)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local teleportGui = playerGui:FindFirstChild("TeleportGui")
    if not teleportGui then return end
    local frame = teleportGui:FindFirstChild("Frame")
    if not frame then return end
    local textLabel = frame:FindFirstChild("TextLabel")
    if not textLabel then return end
    teleportGui.Enabled = true
    frame.BackgroundTransparency = 0
    frame.Visible = true
    textLabel.Text = ""
    textLabel.Visible = true
    -- Typing animation for map name
    for i = 1, #mapName do
        textLabel.Text = string.sub(mapName, 1, i)
        task.wait(0.04)
    end
    -- Wait a moment after typing
    task.wait(0.4)
    -- Fade out
    local tweenService = game:GetService("TweenService")
    local tween = tweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 1})
    tween:Play()
    tween.Completed:Wait()
    teleportGui.Enabled = false
    frame.BackgroundTransparency = 0 -- reset for next use
    textLabel.Text = ""
end

-- ========== SPAWN POSITION LOCKING ========== 
local lockedXPosition = nil
local portalTeleportCooldown = 0 -- timestamp until which X constraint is disabled

local function getCurrentSpawnPart()
    local stats = player:FindFirstChild("Stats")
    local mapName = "Grimleaf Entrance"
    local spawnName = "SpawnLocation"
    if stats then
        local playerMapValue = stats:FindFirstChild("PlayerMap")
        if playerMapValue and playerMapValue.Value ~= "" then
            mapName = playerMapValue.Value
        end
        local lastSpawnValue = stats:FindFirstChild("LastSpawnName")
        if lastSpawnValue and lastSpawnValue.Value ~= "" then
            spawnName = lastSpawnValue.Value
        end
    end
    local mapFolder = workspace:FindFirstChild("Maps")
    if mapFolder then
        local map = mapFolder:FindFirstChild(mapName)
        if map then
            return map:FindFirstChild(spawnName)
        end
    end
    return nil
end

local function updateLockedXPosition()
    local spawnPart = getCurrentSpawnPart()
    if spawnPart then
        lockedXPosition = spawnPart.Position.X
    end
end

-- Listen for spawn changes to update lockedXPosition
local function connectSpawnListeners()
    local stats = player:FindFirstChild("Stats")
    if not stats then return end
    local function onSpawnChanged()
        updateLockedXPosition()
    end
    local lastSpawn = stats:FindFirstChild("LastSpawnName")
    if lastSpawn then
        lastSpawn:GetPropertyChangedSignal("Value"):Connect(onSpawnChanged)
    end
    local playerMap = stats:FindFirstChild("PlayerMap")
    if playerMap then
        playerMap:GetPropertyChangedSignal("Value"):Connect(onSpawnChanged)
    end
end

connectSpawnListeners()

-- Listen for IsPortalTeleporting changes to add cooldown and show teleport fade
player:GetAttributeChangedSignal("IsPortalTeleporting"):Connect(function()
	if player:GetAttribute("IsPortalTeleporting") then
		-- Get map name for typing effect
		local stats = player:FindFirstChild("Stats")
		local mapName = "Teleporting..."
		if stats then
			local playerMapValue = stats:FindFirstChild("PlayerMap")
			if playerMapValue and playerMapValue.Value ~= "" then
				mapName = playerMapValue.Value
			end
		end
		showTeleportFadeWithMap(mapName)
	elseif not player:GetAttribute("IsPortalTeleporting") then
		portalTeleportCooldown = tick() -- 10 seconds after teleport ends
		updateLockedXPosition() -- Update X lock to new map's spawn part
	end
end)

-- Show teleport fade on respawn as well
player.CharacterAdded:Connect(function(newCharacter)
    setupCharacter(newCharacter)
    -- Get map name for typing effect
    local stats = player:FindFirstChild("Stats")
    local mapName = "Teleporting..."
    if stats then
        local playerMapValue = stats:FindFirstChild("PlayerMap")
        if playerMapValue and playerMapValue.Value ~= "" then
            mapName = playerMapValue.Value
        end
    end
    showTeleportFadeWithMap(mapName)
end)

-- ========== MAIN LOOP ==========
RunService.RenderStepped:Connect(function()
	if not character or not humanoidRootPart or not humanoid then return end

	if not lockedXPosition then
		updateLockedXPosition()
	end

	local moveDirection = Vector3.new(0, 0, 0)
	
	if keysPressed.D then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
	if keysPressed.A then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
	
	if thumbstickActive and thumbstickInput.Magnitude > 0 then
		moveDirection = moveDirection + Vector3.new(0, 0, thumbstickInput.X)
	end
	
	if isSprinting and currentMana and currentMana.Value <= 0 then
		isSprinting = false
	end
	
	if isSprinting and moveDirection.Magnitude > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
	else
		humanoid.WalkSpeed = MOVE_SPEED
	end
	
	runningEvent:FireServer(isSprinting and moveDirection.Magnitude > 0)
	
	if moveDirection.Magnitude > 0 then
		local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + moveDirection)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.2)
	end
	
	humanoid:Move(moveDirection, false)
	
	-- Handle walk/run animation (only if not attacking)
	if animator and not isAttacking then
		local isMoving = moveDirection.Magnitude > 0
		local animationType = (humanoid.WalkSpeed >= SPRINT_SPEED) and "Run" or "Walk"
		
		local tool = nil
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				tool = child
				break
			end
		end
		
		if isMoving and tool then
			-- Only switch animation if the type changed
			if lastAnimationType ~= animationType then
				local animation = tool:FindFirstChild(animationType)
				if animation and animation:IsA("Animation") then
					if currentAnimationTrack then
						currentAnimationTrack:Stop()
					end
					
					currentAnimationTrack = animator:LoadAnimation(animation)
					currentAnimationTrack.Looped = true
					currentAnimationTrack:Play()
					isWalking = true
					lastAnimationType = animationType
				end
			end
		elseif not isMoving then
			-- Stop animation when not moving
			if currentAnimationTrack then
				currentAnimationTrack:Stop()
				currentAnimationTrack = nil
			end
			isWalking = false
			lastAnimationType = nil
		end
	end
	

	
	local isTeleporting = player:GetAttribute("IsPortalTeleporting")
	local now = tick()
	if lockedXPosition and not isTeleporting and now > portalTeleportCooldown then
		local currentPos = humanoidRootPart.Position
		if math.abs(currentPos.X - lockedXPosition) > 0.01 then
			humanoidRootPart.CFrame = CFrame.new(lockedXPosition, currentPos.Y, currentPos.Z) * (humanoidRootPart.CFrame - humanoidRootPart.CFrame.Position)
		end
		local currentVel = humanoidRootPart.AssemblyLinearVelocity
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, currentVel.Z)
	end
end)

local function shouldEnableThumbstick()
    if not isOnMobile then return false end
    local inventoryGui = playerGui:FindFirstChild("InventoryGui")
    local characterGui = playerGui:FindFirstChild("CharacterGui")
    if (inventoryGui and inventoryGui.Enabled) or (characterGui and characterGui.Enabled) then
        return false
    end
    return true
end

local function updateThumbstickGui()
    if thumbstickGui then
        thumbstickGui.Enabled = shouldEnableThumbstick()
    end
end

-- Call once at startup
updateThumbstickGui()

-- Listen for InventoryGui and CharacterGui visibility changes
local function connectGuiVisibility(guiName)
    local gui = playerGui:FindFirstChild(guiName)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(updateThumbstickGui)
    end
end

connectGuiVisibility("InventoryGui")
connectGuiVisibility("CharacterGui")

-- If you ever create InventoryGui or CharacterGui dynamically, you may want to listen for their addition:
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "InventoryGui" or child.Name == "CharacterGui" then
        connectGuiVisibility(child.Name)
        updateThumbstickGui()
    end
end)
