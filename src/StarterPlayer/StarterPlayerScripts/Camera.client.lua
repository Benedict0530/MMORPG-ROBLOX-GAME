-- local Players = game:GetService("Players")
-- local RunService = game:GetService("RunService")
-- local UserInputService = game:GetService("UserInputService")

-- local player = Players.LocalPlayer
-- local character = player.Character or player.CharacterAdded:Wait()
-- local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
-- local camera = workspace.CurrentCamera

-- -- Disable camera dragging
-- camera.CameraType = Enum.CameraType.Scriptable

-- -- Camera settings
-- local CAMERA_DISTANCE = 15 -- Distance from the player (side view)
-- local CAMERA_HEIGHT = 5 -- Height offset from the player
-- local CAMERA_SMOOTHING = 1 -- Smoothing factor for camera movement (0-1, higher = faster)

-- -- Function to update camera position
-- local function updateCamera()
-- 	if not character or not humanoidRootPart then
-- 		return
-- 	end
	
-- 	-- Get player position
-- 	local playerPosition = humanoidRootPart.Position
	
-- 	-- Calculate desired camera position (side view - looking from the right/left)
-- 	local desiredCameraPosition = playerPosition + Vector3.new(CAMERA_DISTANCE, CAMERA_HEIGHT, 0)
	
-- 	-- Smoothly move camera to desired position
-- 	local currentCameraPosition = camera.CFrame.Position
-- 	local newCameraPosition = currentCameraPosition:Lerp(desiredCameraPosition, CAMERA_SMOOTHING)
	
-- 	-- Point camera at player's head/chest area
-- 	local targetPosition = playerPosition + Vector3.new(0, 2, 0)
-- 	camera.CFrame = CFrame.new(newCameraPosition, targetPosition)
-- end

-- -- Handle character respawn
-- player.CharacterAdded:Connect(function(newCharacter)
-- 	character = newCharacter
-- 	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
-- end)

-- -- Update camera every frame
-- RunService.RenderStepped:Connect(updateCamera)
