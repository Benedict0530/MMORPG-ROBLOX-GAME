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

-- Consume Shift key input to prevent Roblox ShiftLock and handle sprinting
ContextActionService:BindActionAtPriority("DisableShiftLock", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if inputState == Enum.UserInputState.Begin then
			-- Check if player has enough mana to sprint
			if currentMana and currentMana.Value > 0 then
				isSprinting = true
				print("[Controls] Sprint started - Mana: " .. currentMana.Value)
			else
				print("[Controls] Cannot sprint - Insufficient mana!")
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
	-- Notify server of respawn (reset running state)
	runningEvent:FireServer(false)
	isSprinting = false
	
	-- Refresh mana references
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
	
	-- W key for jumping
	if keyCode == Enum.KeyCode.W then
		humanoid.Jump = true
	end
	
	-- D key for moving right
	if keyCode == Enum.KeyCode.D then
		keysPressed.D = true
	end
	
	-- A key for moving left
	if keyCode == Enum.KeyCode.A then
		keysPressed.A = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local keyCode = input.KeyCode
	
	if keyCode == Enum.KeyCode.D then
		keysPressed.D = false
	end
	
	if keyCode == Enum.KeyCode.A then
		keysPressed.A = false
	end
end)

-- Handle movement each frame
RunService.RenderStepped:Connect(function()
	if not character or not humanoidRootPart or not humanoid then return end
	
	local moveDirection = Vector3.new(0, 0, 0)
	
	if keysPressed.D then
		moveDirection = moveDirection + Vector3.new(0, 0, -1)
	end
	if keysPressed.A then
		moveDirection = moveDirection + Vector3.new(0, 0, 1)
	end
	
	-- Stop sprinting if mana runs out
	if isSprinting and currentMana and currentMana.Value <= 0 then
		isSprinting = false
		print("[Controls] Sprint stopped - Out of mana!")
	end
	
	-- Apply sprint speed if Shift is held and moving
	if isSprinting and moveDirection.Magnitude > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
	else
		humanoid.WalkSpeed = MOVE_SPEED
		if moveDirection.Magnitude > 0 then
		end
	end
	
	-- Notify server if player is running (moving and sprinting)
	local isRunning = isSprinting and moveDirection.Magnitude > 0
	runningEvent:FireServer(isRunning)
	
	-- Rotate character to face movement direction
	if moveDirection.Magnitude > 0 then
		local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + moveDirection)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.2)
	end
	
	-- Apply movement using humanoid:Move()
	humanoid:Move(moveDirection, false)
end)


