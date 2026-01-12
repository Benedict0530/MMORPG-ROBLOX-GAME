local CameraFocusModule = {}
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local defaultCameraType
local defaultCameraSubject
local activeTween -- NEW: Store currently playing tween
local followConnection -- Store the RenderStepped connection

-- Function to disable movement
local function disableMovement()
	ContextActionService:BindAction(
		"DisableMovement",
		function() return Enum.ContextActionResult.Sink end,
		false,
		unpack(Enum.PlayerActions:GetEnumItems())
	)
end

-- Function to enable movement
local function enableMovement()
	ContextActionService:UnbindAction("DisableMovement")
end

function CameraFocusModule.FocusOn(modelOrPart, duration)
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera

    if not player or not camera then
        warn("Camera or player not found!")
        return
    end

    -- Cancel any previous tween if still active
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end

    -- Disconnect previous follow connection if it exists
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CameraSubject = nil
    camera.FieldOfView = 70 -- Reset FOV on focus

    local targetPart = modelOrPart:IsA("Model") and modelOrPart.PrimaryPart or modelOrPart
    if not targetPart then
        warn("Model has no PrimaryPart or the provided part is invalid!")
        return
    end

    -- Disable player movement
    disableMovement()

    -- Calculate camera position in front of the model looking at it
    local cameraDistance = 8 -- Distance from the model
    local cameraOffset = Vector3.new(0, 2, 0) -- Slight height offset
    local newCFrame = CFrame.new(
        targetPart.Position + targetPart.CFrame.LookVector * cameraDistance + cameraOffset,
        targetPart.Position + cameraOffset
    )
    local tweenInfo = TweenInfo.new(duration or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    activeTween = TweenService:Create(camera, tweenInfo, {CFrame = newCFrame})
    activeTween:Play()

    activeTween.Completed:Connect(function()
        activeTween = nil -- Clear when finished
    end)
end

function CameraFocusModule.RestoreDefault()
    local camera = workspace.CurrentCamera
    local player = Players.LocalPlayer
    
    if not camera or not player then
        warn("Camera or player not found!")
        return
    end

    -- If a tween is active, cancel it first
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end

    -- Disconnect previous follow connection if it exists
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end

    -- Restore to default third-person camera
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    
    if humanoid then
        camera.CameraType = Enum.CameraType.Follow
        camera.CameraSubject = humanoid
        camera.FieldOfView = 70
    end

    -- Re-enable movement
    enableMovement()
end

return CameraFocusModule