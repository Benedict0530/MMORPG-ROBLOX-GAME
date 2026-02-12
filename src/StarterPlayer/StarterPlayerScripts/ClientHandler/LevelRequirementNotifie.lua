-- LevelRequirementNotifier.client.lua
-- Displays UI feedback when player doesn't meet level requirement for items
local LevelRequirementNotifier = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for feedback event from server
local itemFeedbackEvent = ReplicatedStorage:WaitForChild("ItemFeedbackEvent")

-- Debounce to prevent multiple triggers
local warningVisible = false

-- Function to display level requirement notification
local function showLevelRequirementNotification(data)
	-- Avoid multiple triggers
	if warningVisible then
		return
	end
	warningVisible = true
	
	-- Find the existing Warning UI
	local gameGui = playerGui:WaitForChild("GameGui")
	local warning = gameGui:WaitForChild("Warning")
	local textLabel = warning:WaitForChild("TextLabel")
	
	-- Set the warning text
	textLabel.Text = "⚠ " .. data.itemName .. " requires Level " .. tostring(data.requiredLevel)
	
	-- Make warning visible
	warning.Visible = true
	
	-- Auto-hide after 4 seconds
	task.delay(4, function()
		warning.Visible = false
		warningVisible = false
	end)
end

-- Listen for feedback from server
itemFeedbackEvent.OnClientEvent:Connect(function(feedbackType, data)
	--print("[LevelRequirementNotifier] Received feedback:", feedbackType, data)
	if feedbackType == "LevelRequirementNotMet" then
		--print("[LevelRequirementNotifier] Displaying level requirement notification for:", data.itemName)
		showLevelRequirementNotification(data)
	end
end)

--print("[LevelRequirementNotifier] Client script loaded and listening for level requirement feedback")

return LevelRequirementNotifier
