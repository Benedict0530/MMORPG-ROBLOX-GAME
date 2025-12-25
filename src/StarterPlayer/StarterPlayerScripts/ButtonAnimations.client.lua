-- ButtonAnimations.client.lua
-- Handles scaling animations for mobile buttons using UIScale

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Animation settings
local SCALE_UP = 1.15
local SCALE_DOWN = 1.0
local ANIMATION_DURATION = 0.1

local tweenInfo = TweenInfo.new(
	ANIMATION_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

-- Function to create scale animation
local function animateButtonPress(button)
	if not button then return end
	
	-- Create or get UIScale
	local uiScale = button:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end
	
	-- Scale up on press
	local scaleUpTween = TweenService:Create(uiScale, tweenInfo, {Scale = SCALE_UP})
	scaleUpTween:Play()
end

-- Function to scale button back to normal
local function animateButtonRelease(button)
	if not button then return end
	
	-- Get UIScale
	local uiScale = button:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end
	
	-- Scale down on release
	local scaleDownTween = TweenService:Create(uiScale, tweenInfo, {Scale = SCALE_DOWN})
	scaleDownTween:Play()
end

-- Setup button animations
local function setupButtonAnimations()
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	-- Setup attack button animation
	local attackButton = frame:FindFirstChild("AttackButton")
	if attackButton then
		attackButton.MouseButton1Down:Connect(function()
			animateButtonPress(attackButton)
		end)
		
		attackButton.MouseButton1Up:Connect(function()
			animateButtonRelease(attackButton)
		end)
		
		-- Also handle when mouse leaves while pressed
		attackButton.MouseLeave:Connect(function()
			animateButtonRelease(attackButton)
		end)
	end
	
	-- Setup pickup button animation
	local pickupButton = frame:FindFirstChild("PickupButton")
	if pickupButton then
		pickupButton.MouseButton1Down:Connect(function()
			animateButtonPress(pickupButton)
		end)
		
		pickupButton.MouseButton1Up:Connect(function()
			animateButtonRelease(pickupButton)
		end)
		
		-- Also handle when mouse leaves while pressed
		pickupButton.MouseLeave:Connect(function()
			animateButtonRelease(pickupButton)
		end)
	end
end

-- Setup animations after GUI is loaded
task.wait(0.5)
setupButtonAnimations()

-- Setup button animations
local function setupButtonAnimations()
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	-- Setup attack button animation
	local attackButton = frame:FindFirstChild("AttackButton")
	if attackButton then
		attackButton.MouseButton1Down:Connect(function()
			animateButtonPress(attackButton)
		end)
		
		attackButton.MouseButton1Up:Connect(function()
			animateButtonRelease(attackButton)
		end)
		
		-- Also handle when mouse leaves while pressed
		attackButton.MouseLeave:Connect(function()
			animateButtonRelease(attackButton)
		end)
	end
	
	-- Setup pickup button animation
	local pickupButton = frame:FindFirstChild("PickupButton")
	if pickupButton then
		pickupButton.MouseButton1Down:Connect(function()
			animateButtonPress(pickupButton)
		end)
		
		pickupButton.MouseButton1Up:Connect(function()
			animateButtonRelease(pickupButton)
		end)
		
		-- Also handle when mouse leaves while pressed
		pickupButton.MouseLeave:Connect(function()
			animateButtonRelease(pickupButton)
		end)
	end
end

-- Setup animations after GUI is loaded
task.wait(0.5)
setupButtonAnimations()
