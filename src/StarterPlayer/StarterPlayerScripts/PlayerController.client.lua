-- PlayerController.client.lua
-- Combined script for movement controls and weapon handling
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Get ParalysisState from ReplicatedStorage to check if player is paralyzed
local isParalyzedValue = ReplicatedStorage:FindFirstChild("IsParalyzed")
if not isParalyzedValue then
	isParalyzedValue = Instance.new("BoolValue")
	isParalyzedValue.Name = "IsParalyzed"
	isParalyzedValue.Value = false
	isParalyzedValue.Parent = ReplicatedStorage
end

-- Get ResumeAnimationEvent to listen for when animations should resume
local resumeAnimationEvent = ReplicatedStorage:WaitForChild("ResumeAnimationEvent", 10)

-- BindableEvent for weapon change (for GUI update)
local weaponChangedEvent = ReplicatedStorage:FindFirstChild("WeaponChangedEvent")
if not weaponChangedEvent then
	weaponChangedEvent = Instance.new("BindableEvent")
	weaponChangedEvent.Name = "WeaponChangedEvent"
	weaponChangedEvent.Parent = ReplicatedStorage
end

-- Get TeleportGuiEvent for portal touch notifications
local TeleportGuiEvent = ReplicatedStorage:WaitForChild("TeleportGuiEvent", 10)

-- Get player stats
local stats = player:WaitForChild("Stats", 5)
local currentMana = stats and stats:WaitForChild("CurrentMana", 5)
local maxMana = stats and stats:WaitForChild("MaxMana", 5)

-- Use Roblox default controls
-- Default controls enabled - WASD for movement, Space for jump, Shift for sprint

-- Get PlayerRunning event created by server
local runningEvent = ReplicatedStorage:WaitForChild("PlayerRunning")

-- ========== ANIMATION TRACKING ==========
local animator = humanoid:FindFirstChildOfClass("Animator")
local currentAnimationTrack = nil
local lastAnimationType = nil
local lastAnimationChangeTime = 0
local ANIMATION_CHANGE_COOLDOWN = 0
local MOVEMENT_START_THRESHOLD = 5 -- Velocity needed to START walking from idle
local MOVEMENT_STOP_THRESHOLD = 3 -- Velocity needed to STOP walking back to idle (hysteresis)

-- ========== WEAPON SETTINGS ==========
local lastAttackTimes = {}
local currentTool = nil
local isMousePressed = false
local isDuelActive = false -- Track if player is in a duel
local isSprinting = false
local wasSprintingBeforeDash = false
local attackLoopConnection = nil
local attackAnimationConnection = nil
local isAttacking = false
local isAnimationInProgress = false
local heldAttackOverride = false -- If true, weapon speed is forced to 2
local attackPressStartTime = 0
local ATTACK_HOLD_THRESHOLD = 0.2 -- seconds to consider as 'held'

-- ========== SPRINT SETTINGS ==========
local DEFAULT_WALK_SPEED = 16
local SPRINT_WALK_SPEED = 40

-- ========== DASH SETTINGS ==========
local DASH_SPEED = 150
local DASH_DURATION = 0.3
local DASH_COOLDOWN = 1
local lastDashTime = 0
local isDashing = false

-- ========== MOBILE SETUP ==========
local isOnMobile = UserInputService.TouchEnabled
local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:FindFirstChild("GameGui")

-- Show mobile buttons on touch devices
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
	currentAnimationTrack = nil
	lastAnimationType = nil

    -- Reference to Animate script
    local animateScript = character:FindFirstChild("Animate")
	
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

            -- Disable Animate script when tool is equipped
            local animateScript = character:FindFirstChild("Animate")
            if animateScript then
                animateScript.Disabled = true
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
					currentAnimationTrack = track
					lastAnimationType = "Idle"
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

            -- Re-enable Animate script when tool is unequipped
            local animateScript = character:FindFirstChild("Animate")
            if animateScript then
                animateScript.Disabled = false
            end
		end
	end)
end

setupCharacter(character)

player.CharacterAdded:Connect(function(newCharacter)
	setupCharacter(newCharacter)
end)

-- ========== DASH FUNCTION ==========
local function performDash()
	-- Check cooldown
	local currentTime = tick()
	if currentTime - lastDashTime < DASH_COOLDOWN then
		return
	end

	-- Check if already dashing or paralyzed
	if isDashing or isParalyzedValue.Value then
		return
	end

	-- Check mana (dash costs 2 mana)
	if not currentMana or currentMana.Value < 2 then
		--print("[PlayerController] Not enough mana to dash (need 2, have " .. (currentMana and currentMana.Value or 0) .. ")")
		return
	end

	lastDashTime = currentTime
	isDashing = true
	-- Store sprint state before dash
	wasSprintingBeforeDash = isSprinting
	--print("[PlayerController] Dash executed")

	-- Get or create remote event to tell server to consume mana and play dash sound
	local performDashEvent = ReplicatedStorage:FindFirstChild("PerformDash")
	if not performDashEvent then
		performDashEvent = Instance.new("RemoteEvent")
		performDashEvent.Name = "PerformDash"
		performDashEvent.Parent = ReplicatedStorage
	end

	-- Tell server to consume mana and play dash sound
	performDashEvent:FireServer(humanoidRootPart.Position)

	-- Get camera direction to determine dash direction
	local camera = workspace.CurrentCamera
	local dashDirection = camera.CFrame.LookVector

	-- Create BodyVelocity for dash
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = dashDirection * DASH_SPEED
	bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge) -- Only affect horizontal movement
	bodyVelocity.Parent = humanoidRootPart

	-- Play dash animation
	if animator then
		local dashAnimation = Instance.new("Animation")
		dashAnimation.AnimationId = "rbxassetid://119265598803684"
		local dashTrack = animator:LoadAnimation(dashAnimation)
		dashTrack:Play()
		dashTrack:AdjustSpeed(1.5) -- Speed up animation by 1.5x
		--print("[PlayerController] Dash animation playing")
	end

	-- Raycast during dash to detect obstacles in front cone only
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	-- Exclude all player characters (not just self) from dash obstacle detection
	local filterInstances = {character}
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			table.insert(filterInstances, otherPlayer.Character)
		end
	end
	
	-- Exclude all enemies (both alive and dead) from dash obstacle detection
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- Use CollisionGroup property to filter both alive and dead enemies
			if descendant.CollisionGroup == "Enemies" or descendant.CollisionGroup == "DeadEnemies" then
				-- Find the top-level model/enemy parent
				local parent = descendant.Parent
				while parent and parent ~= workspace do
					if parent:IsA("Model") then
						-- Add the enemy model to filter if not already added
						if not table.find(filterInstances, parent) then
							table.insert(filterInstances, parent)
						end
						break
					end
					parent = parent.Parent
				end
			end
		end
	end
	
	raycastParams.FilterDescendantsInstances = filterInstances

	local dashStartTime = tick()
	local dashStoppedEarly = false
	local DETECTION_CONE_ANGLE = 45 -- Only detect obstacles within 45 degrees of dash direction
	local RAYCAST_HEIGHT = 3 -- Only detect obstacles at chest height and above, ignore ground

	-- Check for obstacles every frame during dash
	while tick() - dashStartTime < DASH_DURATION and not dashStoppedEarly do
		local rayOrigin = humanoidRootPart.Position + Vector3.new(0, RAYCAST_HEIGHT / 2, 0) -- Raise origin to chest height
		local rayDistance = DASH_SPEED * 0.05 -- Lookahead distance (reduced for closer detection)
		-- Make rayDirection purely horizontal (no vertical component)
		local horizontalDirection = Vector3.new(dashDirection.X, 0, dashDirection.Z).Unit
		local rayDirection = horizontalDirection * rayDistance

		-- Cast ray in dash direction (horizontal only)
		local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		-- If ray hits something (not player), check if it's in front cone
		if rayResult then
			local hitPart = rayResult.Instance
			-- Check if hit part belongs to player
			if not hitPart:IsDescendantOf(character) then
				-- Check if obstacle is in front cone
				local hitPosition = rayResult.Position
				local directionToHit = (hitPosition - rayOrigin).Unit
				local dotProduct = horizontalDirection:Dot(directionToHit)
				local angleFromDash = math.acos(math.clamp(dotProduct, -1, 1))
				local angleInDegrees = math.deg(angleFromDash)

				-- Only stop if obstacle is within front cone AND at reasonable height
				if angleInDegrees <= DETECTION_CONE_ANGLE then
					--print("[PlayerController] Obstacle detected in front cone (" .. angleInDegrees .. "°) - stopping dash")
					bodyVelocity.Velocity = Vector3.new(0, 0, 0) -- Stop momentum
					dashStoppedEarly = true
					break
				end
			end
		end

		task.wait(0.01) -- Check every 0.01 seconds
	end

	-- Remove dash velocity
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end

	isDashing = false
	--print("[PlayerController] Dash ended")

end

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

local AttackBridge = require(script.Parent:FindFirstChild("AttackBridge"))

local function performAttack(tool, ignoreDuelBlock)
	if isDuelActive and not ignoreDuelBlock then return end -- Block all attacks during duel unless override
	if not tool or not tool.Name then return end
	if isAnimationInProgress then return end
	if isParalyzedValue.Value then return end -- Don't attack if paralyzed
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
			--print("Playing attack animation with duration: " .. tostring(actualDuration))
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
					currentAnimationTrack = idleTrack
					lastAnimationType = "Idle"
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

-- Register performAttack for external use (e.g., minigame)
if AttackBridge then
	AttackBridge.setPerformAttack(performAttack)
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
			if humanoid then humanoid.WalkSpeed = SPRINT_WALK_SPEED end
			runningEvent:FireServer(true)
		else
			isSprinting = false
			if humanoid then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
			runningEvent:FireServer(false)
		end
	end)
	
	runButton.MouseButton1Up:Connect(function()
		isSprinting = false
		if humanoid then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
		runningEvent:FireServer(false)
	end)
end
-- ========== ATTACK BUTTON SETUP ==========
local function setAttackButtonEnabled(enabled)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	local attackButton = frame:FindFirstChild("AttackButton")
	if not attackButton then return end
	attackButton.AutoButtonColor = enabled
	attackButton.Active = enabled
	attackButton.Visible = UserInputService.TouchEnabled and enabled
end

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
		if isDuelActive then
			if attackLoopConnection then attackLoopConnection:Disconnect() attackLoopConnection = nil end
			isMousePressed = false
			return
		end
		if not currentTool then return end
		if isMousePressed then return end -- Prevent multiple loops
		isMousePressed = true
		heldAttackOverride = true
		attackPressStartTime = tick()
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if isDuelActive then return end
			if not isMousePressed or not currentTool then
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
		if isDuelActive then
			if attackLoopConnection then attackLoopConnection:Disconnect() attackLoopConnection = nil end
			isMousePressed = false
			return
		end
		if not isMousePressed then return end
		isMousePressed = false
		heldAttackOverride = false
		attackPressStartTime = 0
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
		-- Allow current animation to finish naturally
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
	end)
end

-- ========== DASH BUTTON SETUP ==========
local function setupDashButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local dashButton = frame:FindFirstChild("DashButton")
	if not dashButton then return end
	
	dashButton.Visible = UserInputService.TouchEnabled
	
	dashButton.MouseButton1Down:Connect(function()
		performDash()
	end)
end

task.wait(0.5)
setupAttackButton()
setupRunButton()
setupJumpButton()
setupDashButton()

-- ========== INPUT HANDLING ==========

-- Only enable M1 attack on non-touch devices
if not isOnMobile then
	local mouse = player:GetMouse()
	mouse.Button1Down:Connect(function()
		if isDuelActive then
			if attackLoopConnection then attackLoopConnection:Disconnect() attackLoopConnection = nil end
			isMousePressed = false
			return
		end
		if not currentTool then return end
		isMousePressed = true
		heldAttackOverride = true
		attackPressStartTime = tick()
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if isDuelActive then return end
			if not isMousePressed or not currentTool then
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

	mouse.Button1Up:Connect(function()
		if isDuelActive then
			if attackLoopConnection then attackLoopConnection:Disconnect() attackLoopConnection = nil end
			isMousePressed = false
			return
		end
		isMousePressed = false
		heldAttackOverride = false
		attackPressStartTime = 0
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
		-- Allow current animation to finish naturally
	end)
end
-- ========== DUEL EVENT HANDLING ========== 
local function setupDuelEventListeners()
	local duelStartedEvent = ReplicatedStorage:FindFirstChild("DuelStartedEvent")
	local duelEndedEvent = ReplicatedStorage:FindFirstChild("DuelEndedEvent")
	if duelStartedEvent then
		duelStartedEvent.OnClientEvent:Connect(function()
			isDuelActive = true
			setAttackButtonEnabled(false)
		end)
	end
	if duelEndedEvent then
		duelEndedEvent.OnClientEvent:Connect(function()
			isDuelActive = false
			setAttackButtonEnabled(true)
		end)
	end
end

setupDuelEventListeners()

-- ========== SPRINT HANDLING ==========
local lastSprintState = false
ContextActionService:BindActionAtPriority("SprintAction", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if inputState == Enum.UserInputState.Begin then
			if currentMana and currentMana.Value > 0 then
				isSprinting = true
                if humanoid then humanoid.WalkSpeed = SPRINT_WALK_SPEED end
			else
				isSprinting = false
                if humanoid then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
			end
		elseif inputState == Enum.UserInputState.End then
			isSprinting = false
            if humanoid then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
		end
		
		-- Fire running event when sprint state changes
		if lastSprintState ~= isSprinting then
			runningEvent:FireServer(isSprinting)
			lastSprintState = isSprinting
		end
		
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift)

-- ========== DASH HANDLING (Q KEY) ==========
ContextActionService:BindActionAtPriority("DashAction", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.Q then
		if inputState == Enum.UserInputState.Begin then
			performDash()
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q)

-- Monitor mana while sprinting - stop sprint if mana runs out
if currentMana then
	currentMana:GetPropertyChangedSignal("Value"):Connect(function()
		if isSprinting and currentMana.Value <= 0 then
			isSprinting = false
			if humanoid then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
			runningEvent:FireServer(false)
			lastSprintState = false
		end
	end)
end

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
    task.wait(1)
    -- Fade out
    local tweenService = game:GetService("TweenService")
    local tween = tweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 1})
    tween:Play()
    tween.Completed:Wait()
    teleportGui.Enabled = false
    frame.BackgroundTransparency = 0 -- reset for next use
    textLabel.Text = ""
end

-- Listen for portal touch events from server
if TeleportGuiEvent then
	TeleportGuiEvent.OnClientEvent:Connect(function(mapName)
		--print("[PlayerController] Portal touch detected - showing teleport UI for:", mapName)
		showTeleportFadeWithMap(mapName)
	end)
end

-- Show teleport fade on respawn
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
local _prevHumanoidState = nil
RunService.RenderStepped:Connect(function()
	if not character or not humanoidRootPart or not humanoid then return end
	
	-- Detect player movement state and play animations from tool
	if animator and currentTool then
		if isAttacking and isAnimationInProgress then
			return
		end

		local humanoidState = humanoid:GetState()
		local isJumping = humanoidState == Enum.HumanoidStateType.Jumping or humanoidState == Enum.HumanoidStateType.FallingDown or humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.Flying
		local isOnGround = humanoidState == Enum.HumanoidStateType.Running or humanoidState == Enum.HumanoidStateType.Landed or humanoidState == Enum.HumanoidStateType.Climbing or isSeated

		if isJumping then
			if lastAnimationType ~= "Jump" or not (currentAnimationTrack and currentAnimationTrack.IsPlaying) then
				if currentAnimationTrack then currentAnimationTrack:Stop() currentAnimationTrack = nil end
				lastAnimationType = nil
				local jumpAnimation = currentTool:FindFirstChild("Jump")
				if jumpAnimation and jumpAnimation:IsA("Animation") and animator then
					currentAnimationTrack = animator:LoadAnimation(jumpAnimation)
					currentAnimationTrack.Looped = true
					currentAnimationTrack:Play()
					lastAnimationType = "Jump"
				end
			end
		elseif isOnGround then
			if lastAnimationType == "Jump" and currentAnimationTrack and currentAnimationTrack.IsPlaying then
				currentAnimationTrack:Stop()
				currentAnimationTrack = nil
				lastAnimationType = nil
			end
		end

		local horizontalVelocity = Vector3.new(humanoidRootPart.AssemblyLinearVelocity.X, 0, humanoidRootPart.AssemblyLinearVelocity.Z).Magnitude
		local isMoving
		if lastAnimationType == "Idle" then
			isMoving = horizontalVelocity > MOVEMENT_START_THRESHOLD
		else
			isMoving = horizontalVelocity > MOVEMENT_STOP_THRESHOLD
		end

		local animationType = nil
		if isMoving then
			animationType = isSprinting and "Run" or "Walk"
		else
			animationType = "Idle"
		end

		local currentTime = tick()
		if lastAnimationType == "Jump" then
			if currentAnimationTrack and currentAnimationTrack.IsPlaying then
				return
			end
		end
		if lastAnimationType ~= animationType and (currentTime - lastAnimationChangeTime) >= ANIMATION_CHANGE_COOLDOWN then
			local animation = currentTool:FindFirstChild(animationType)
			if animation and animation:IsA("Animation") then
				if currentAnimationTrack then currentAnimationTrack:Stop() end
				currentAnimationTrack = animator:LoadAnimation(animation)
				currentAnimationTrack.Looped = (animationType ~= "Jump")
				currentAnimationTrack:Play()
				lastAnimationType = animationType
				lastAnimationChangeTime = currentTime
			end
		end
	end
end)

-- Handle animation resume when paralysis ends
if resumeAnimationEvent then
	resumeAnimationEvent.OnClientEvent:Connect(function()
		--print("[PlayerController] Resuming animation control after paralysis")
		if currentTool and animator then
			-- Play idle animation to resume control
			local idleAnimation = currentTool:FindFirstChild("Idle")
			if idleAnimation and idleAnimation:IsA("Animation") then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				local idleTrack = animator:LoadAnimation(idleAnimation)
				idleTrack.Looped = true
				idleTrack:Play()
				currentAnimationTrack = idleTrack
				lastAnimationType = "Idle"
				isAnimationInProgress = false
				--print("[PlayerController] Idle animation resumed")
			end
		end
	end)
end
