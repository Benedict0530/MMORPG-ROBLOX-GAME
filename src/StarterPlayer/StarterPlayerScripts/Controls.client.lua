local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Disable default Roblox controls
local Controls = require(player.PlayerScripts.PlayerModule):GetControls()
Controls:Disable()

-- Disable default ShiftLock permanently
local playerModule = player.PlayerScripts.PlayerModule
local cameraModule = require(playerModule:WaitForChild("CameraModule"))
pcall(function() cameraModule:SetShiftLockMode(false) end)


-- Movement settings
local MOVE_SPEED = 16
local SPRINT_SPEED = 25
local isSprinting = false

-- Consume Shift key input to prevent Roblox ShiftLock and handle sprinting
ContextActionService:BindActionAtPriority("DisableShiftLock", function(actionName, inputState, input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if inputState == Enum.UserInputState.Begin then
			isSprinting = true
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
	
	-- Apply sprint speed if Shift is held and moving
	if isSprinting and moveDirection.Magnitude > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
	else
		humanoid.WalkSpeed = MOVE_SPEED
		if moveDirection.Magnitude > 0 then
		end
	end
	
	-- Rotate character to face movement direction
	if moveDirection.Magnitude > 0 then
		local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + moveDirection)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.2)
	end
	
	-- Apply movement using humanoid:Move()
	humanoid:Move(moveDirection, false)
end)


