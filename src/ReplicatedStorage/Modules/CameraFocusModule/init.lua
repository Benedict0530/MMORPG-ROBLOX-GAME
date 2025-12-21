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

    local newCFrame = targetPart.CFrame
    local tweenInfo = TweenInfo.new(duration or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    activeTween = TweenService:Create(camera, tweenInfo, {CFrame = newCFrame})
    activeTween:Play()

    activeTween.Completed:Connect(function()
        activeTween = nil -- Clear when finished
    end)
end

function CameraFocusModule.RestoreDefault()
    local camera = workspace.CurrentCamera
    if not camera then
        warn("Camera not found!")
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

    -- Set to isometric follow view
    local player = Players.LocalPlayer
    local character = player and player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        camera.CameraType = Enum.CameraType.Scriptable
        local defaultOffset = Vector3.new(25, 28, -30)
        camera.FieldOfView = 35

        local function updateCamera()
            if rootPart and rootPart.Parent then
                camera.CFrame = CFrame.new(rootPart.Position + defaultOffset, rootPart.Position)
            end
        end

        -- Initial update
        updateCamera()
        -- Continuously update the camera to follow the player
        followConnection = RunService.RenderStepped:Connect(updateCamera)
    else
        warn("Character or HumanoidRootPart not found, cannot set isometric view.")
    end

    -- Re-enable movement
    enableMovement()
end

return CameraFocusModule