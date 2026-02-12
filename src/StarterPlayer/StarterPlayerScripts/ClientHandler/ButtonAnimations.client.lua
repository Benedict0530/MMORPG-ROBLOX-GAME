-- ButtonAnimations.client.lua
-- Handles scaling animations for mobile buttons using UIScale
local ButtonAnimations = {}
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

-- Function to setup animation for a single button
local function setupButtonAnimation(button)
	button.MouseButton1Down:Connect(function()
		animateButtonPress(button)
	end)
	
	button.MouseButton1Up:Connect(function()
		animateButtonRelease(button)
	end)
	
	-- Also handle when mouse leaves while pressed
	button.MouseLeave:Connect(function()
		animateButtonRelease(button)
	end)
end

-- Setup button animations by scanning all GUI elements
local function setupButtonAnimations()
	-- Scan all descendants of PlayerGui
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		-- Check if it's a TextButton or ImageButton
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
			setupButtonAnimation(descendant)
			--print("[ButtonAnimations] Applied animation to:", descendant.Name)
		end
	end
	
	-- Also listen for new buttons being added
	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
			setupButtonAnimation(descendant)
			--print("[ButtonAnimations] Applied animation to new button:", descendant.Name)
		end
	end)
end

-- Setup animations after GUI is loaded
task.wait(0.5)

setupButtonAnimations()

return ButtonAnimations
