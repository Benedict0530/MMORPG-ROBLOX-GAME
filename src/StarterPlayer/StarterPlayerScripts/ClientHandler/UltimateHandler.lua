
local UltimateHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ultimateSkillRemote = ReplicatedStorage:WaitForChild("UltimateSkill")

-- Variables to track spinning animation
local spinTween = nil
local defaultImageTransparency = nil

-- Wait for GameGui and UltimateButton
local function getUltimateButton()
	local gameGui = playerGui:WaitForChild("GameGui", 10)
	if not gameGui then return nil end
	local ultimateFrame = gameGui:FindFirstChild("Ultimate")
	if not ultimateFrame then return nil end
	local ultimateButton = ultimateFrame:FindFirstChild("UltimateButton")
	return ultimateButton
end

-- Create circular progress bar using two rotating halves
local function createCircularProgress(parent)
	local container = Instance.new("Frame")
	container.Name = "UltimateCircularProgress"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.ZIndex = 10
	container.Parent = parent
	
	-- Background ring (unfilled)
	local bgRing = Instance.new("Frame")
	bgRing.Name = "BackgroundRing"
	bgRing.Size = UDim2.new(.5, 0, .5, 0)
	bgRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	bgRing.AnchorPoint = Vector2.new(0.5, 0.5)
	bgRing.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	bgRing.BackgroundTransparency = 0.7
	bgRing.ZIndex = 11
	bgRing.Parent = container
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = bgRing
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Thickness = 5
	bgStroke.Color = Color3.fromRGB(50, 50, 50)
	bgStroke.Transparency = 0.7
	bgStroke.Parent = bgRing
	
	-- Inner mask to create ring effect
	local innerMask = Instance.new("Frame")
	innerMask.Name = "InnerMask"
	innerMask.Size = UDim2.new(0.5, 0, 0.5, 0)
	innerMask.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerMask.AnchorPoint = Vector2.new(0.5, 0.5)
	innerMask.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	innerMask.BackgroundTransparency = 1
	innerMask.ZIndex = 12
	innerMask.Parent = bgRing
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = innerMask
	
	-- Progress ring (filled)
	local progressRing = Instance.new("Frame")
	progressRing.Name = "ProgressRing"
	progressRing.Size = UDim2.new(0.8, 0, 0.8, 0)
	progressRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	progressRing.AnchorPoint = Vector2.new(0.5, 0.5)
	progressRing.BackgroundTransparency = 1
	progressRing.ZIndex = 13
	progressRing.Parent = container
	
	local progressStroke = Instance.new("UIStroke")
	progressStroke.Thickness = 5
	progressStroke.Color = Color3.fromRGB(255, 215, 0)
	progressStroke.Transparency = 0.6
	progressStroke.Parent = progressRing
	
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(1, 0)
	progressCorner.Parent = progressRing
	
	return container, progressStroke
end

-- Update the circular progress effect (0-100) using UIStroke gradient
local function updateCircularProgress(progressStroke, percent)
	percent = math.clamp(percent, 0, 100)
	
	-- Create gradient based on percentage
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = -90 -- Start from top
	
	if percent == 0 then
		progressStroke.Transparency = 1
	elseif percent == 100 then
		progressStroke.Transparency = 0
		if progressStroke:FindFirstChild("UIGradient") then
			progressStroke.UIGradient:Destroy()
		end
	else
		progressStroke.Transparency = 0
		-- Use gradient to simulate partial fill
		local fillPoint = percent / 100
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(fillPoint - 0.01, 0),
			NumberSequenceKeypoint.new(fillPoint, 1),
			NumberSequenceKeypoint.new(1, 1)
		})
		
		if progressStroke:FindFirstChild("UIGradient") then
			progressStroke.UIGradient:Destroy()
		end
		gradient.Parent = progressStroke
	end
end

-- Create spinning animation for the image
local function createSpinAnimation(image)
	local tweenInfo = TweenInfo.new(
		2, -- Duration: 2 seconds per rotation
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1, -- Repeat infinitely
		false,
		0
	)
	
	local tween = TweenService:Create(image, tweenInfo, {Rotation = 360})
	return tween
end

-- Start spinning animation
local function startSpin(image)
	if spinTween then
		spinTween:Cancel()
	end
	image.Rotation = 0
	spinTween = createSpinAnimation(image)
	spinTween:Play()
end

-- Stop spinning animation
local function stopSpin(image)
	if spinTween then
		spinTween:Cancel()
		spinTween = nil
	end
	image.Rotation = 0
end

-- Listen for UltimateCharge stat changes
local function setupUltimateBar()
	local ultimateButton = getUltimateButton()
	if not ultimateButton then return end
	
	-- Find the Image child
	local image = ultimateButton:FindFirstChild("Image")
	if image and image:IsA("ImageLabel") then
		-- Store default transparency
		defaultImageTransparency = image.ImageTransparency
	end
	
	-- Function to activate ultimate
	local function activateUltimate()
		ultimateSkillRemote:FireServer()
		--print("[UltimateHandler] Ultimate skill activated!")
	end
	
	-- Connect button click to fire remote
	ultimateButton.MouseButton1Click:Connect(activateUltimate)
	
	-- Connect keyboard input (X key)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.X then
			-- Only activate if button is visible (orb equipped)
			if ultimateButton.Visible then
				activateUltimate()
			end
		end
	end)
	
	-- Remove old progress if exists
	local old = ultimateButton:FindFirstChild("UltimateCircularProgress")
	if old then old:Destroy() end
	local container, progressStroke = createCircularProgress(ultimateButton)

	-- Find the stat
	local stats = player:WaitForChild("Stats", 10)
	if not stats then return end
	local ultimateStat = stats:FindFirstChild("UltimateCharge")
	if not ultimateStat then return end
	
	-- Find EquippedOrb folder
	local equippedOrbFolder = stats:FindFirstChild("EquippedOrb")
	if not equippedOrbFolder then 
		warn("[UltimateHandler] EquippedOrb folder not found")
		return 
	end

	-- Function to check if orb is equipped
	local function isOrbEquipped()
		local orbId = equippedOrbFolder:FindFirstChild("id")
		local orbName = equippedOrbFolder:FindFirstChild("name")
		
		if orbId and orbId.Value ~= "" then
			return true
		end
		if orbName and orbName.Value ~= "" then
			return true
		end
		return false
	end
	
	-- Function to update button visibility based on equipped orb
	local function updateButtonVisibility()
		ultimateButton.Visible = isOrbEquipped()
		--print("[UltimateHandler] UltimateButton visibility:", ultimateButton.Visible)
	end
	
	-- Initial visibility check
	updateButtonVisibility()
	
	-- Listen for changes to EquippedOrb folder children
	equippedOrbFolder.ChildAdded:Connect(updateButtonVisibility)
	equippedOrbFolder.ChildRemoved:Connect(updateButtonVisibility)
	for _, child in ipairs(equippedOrbFolder:GetChildren()) do
		if child:IsA("StringValue") then
			child:GetPropertyChangedSignal("Value"):Connect(updateButtonVisibility)
		end
	end

	-- Function to update visual state based on charge
	local function updateUltimateState(value)
		updateCircularProgress(progressStroke, value)
		
		if image and image:IsA("ImageLabel") then
			if value >= 100 then
				-- Full charge: make visible and spin
				image.ImageTransparency = 0
				startSpin(image)
			else
				-- Not full: restore default transparency and stop spinning
				image.ImageTransparency = defaultImageTransparency
				stopSpin(image)
			end
		end
	end

	-- Initial update
	updateUltimateState(ultimateStat.Value)

	-- Listen for changes
	ultimateStat:GetPropertyChangedSignal("Value"):Connect(function()
		updateUltimateState(ultimateStat.Value)
	end)
end

-- Run setup on script load
task.spawn(setupUltimateBar)

return UltimateHandler
