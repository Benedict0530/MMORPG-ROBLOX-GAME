-- LevelUpDisplay.client.lua
-- Client-side script to show level-up animation when player levels up
local LevelUpDisplay = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GameGui = PlayerGui:WaitForChild("GameGui")
local LevelUpFrame = GameGui:WaitForChild("LevelUp")
local TextLabel = LevelUpFrame:WaitForChild("TextLabel")

-- Configuration
local ANIMATION_DURATION = 0.5 -- Duration for fade in
local DISPLAY_DURATION = 2 -- How long to show the level up message
local FADE_OUT_DURATION = 0.5 -- Duration for fade out

-- Track previous level to detect level-up
local previousLevel = nil

-- Animation queue system for sequential animations
local animationQueue = {}
local isAnimating = false

print("[LevelUpDisplay.client] Script started")

-- Setup level monitoring
local function setupLevelMonitoring()

	local stats = LocalPlayer:FindFirstChild("Stats")
	if not stats then
		-- Wait indefinitely for Stats to appear
		while true do
			stats = LocalPlayer:FindFirstChild("Stats")
			if stats then break end
			LocalPlayer.ChildAdded:Wait()
		end
	end
	if not stats then
		warn("[LevelUpDisplay.client] Stats folder not found after waiting!")
		return
	end
	local level = stats:WaitForChild("Level")
	local experience = stats:WaitForChild("Experience")
	local neededExperience = stats:WaitForChild("NeededExperience")
	
	-- Set initial level
	previousLevel = level.Value
	
	-- Connect to level changes
	level.Changed:Connect(function(newLevel)
		if newLevel > previousLevel then
			print("[LevelUpDisplay.client] Level up! New level:", newLevel)
			showLevelUpAnimation(newLevel, experience.Value, neededExperience.Value)
			previousLevel = newLevel
		end
	end)
end

-- Show level-up animation
function showLevelUpAnimation(level, currentExp, neededExp)
	-- Queue animation if one is already running
	if isAnimating then
		table.insert(animationQueue, {
			func = showLevelUpAnimation,
			args = {level, currentExp, neededExp}
		})
		print("[LevelUpDisplay.client] Level-up queued, will show after current animation")
		return
	end
	
	isAnimating = true
	
	-- Hide the frame first
	LevelUpFrame.Visible = false
	TextLabel.TextTransparency = 1
	
	-- Set the text with level information
	TextLabel.Text = "LEVEL UP!\nLevel " .. tostring(level)
	
	-- Make frame visible
	LevelUpFrame.Visible = true
	
	-- Animate fade in
	local startTime = tick()
	while tick() - startTime < ANIMATION_DURATION do
		local progress = (tick() - startTime) / ANIMATION_DURATION
		TextLabel.TextTransparency = 1 - progress -- Fade in from transparent to opaque
		task.wait(0.016) -- ~60fps
	end
	TextLabel.TextTransparency = 0 -- Ensure fully visible
	
	-- Wait to display
	task.wait(DISPLAY_DURATION)
	
	-- Animate fade out
	startTime = tick()
	while tick() - startTime < FADE_OUT_DURATION do
		local progress = (tick() - startTime) / FADE_OUT_DURATION
		TextLabel.TextTransparency = progress -- Fade out from opaque to transparent
		task.wait(0.016) -- ~60fps
	end
	TextLabel.TextTransparency = 1 -- Ensure fully transparent
	
	-- Hide the frame
	LevelUpFrame.Visible = false
	
	print("[LevelUpDisplay.client] Level up animation complete")
	
	isAnimating = false
	
	-- Process next animation in queue if any
	if #animationQueue > 0 then
		local nextAnimation = table.remove(animationQueue, 1)
		nextAnimation.func(unpack(nextAnimation.args))
	end
end

-- Show quest completion rewards animation
function showQuestRewardAnimation(questName, experience, gold)
	-- Queue animation if one is already running
	if isAnimating then
		-- Insert at front of queue so quest shows before level-up
		table.insert(animationQueue, 1, {
			func = showQuestRewardAnimation,
			args = {questName, experience, gold}
		})
		print("[LevelUpDisplay.client] Quest reward queued, will show after current animation")
		return
	end
	
	isAnimating = true
	
	-- Hide the frame first
	LevelUpFrame.Visible = false
	TextLabel.TextTransparency = 1
	
	-- Set the text with quest reward information
	TextLabel.Text = "QUEST COMPLETED!\n" .. questName .. "\n" .. tostring(experience) .. " XP, " .. tostring(gold) .. " Gold"
	
	-- Make frame visible
	LevelUpFrame.Visible = true
	
	-- Animate fade in
	local startTime = tick()
	while tick() - startTime < ANIMATION_DURATION do
		local progress = (tick() - startTime) / ANIMATION_DURATION
		TextLabel.TextTransparency = 1 - progress -- Fade in from transparent to opaque
		task.wait(0.016) -- ~60fps
	end
	TextLabel.TextTransparency = 0 -- Ensure fully visible
	
	-- Wait to display
	task.wait(DISPLAY_DURATION)
	
	-- Animate fade out
	startTime = tick()
	while tick() - startTime < FADE_OUT_DURATION do
		local progress = (tick() - startTime) / FADE_OUT_DURATION
		TextLabel.TextTransparency = progress -- Fade out from opaque to transparent
		task.wait(0.016) -- ~60fps
	end
	TextLabel.TextTransparency = 1 -- Ensure fully transparent
	
	-- Hide the frame
	LevelUpFrame.Visible = false
	
	print("[LevelUpDisplay.client] Quest reward animation complete")
	
	isAnimating = false
	
	-- Process next animation in queue if any
	if #animationQueue > 0 then
		local nextAnimation = table.remove(animationQueue, 1)
		nextAnimation.func(unpack(nextAnimation.args))
	end
end

-- Wait for stats and setup monitoring
task.spawn(function()
	setupLevelMonitoring()
	print("[LevelUpDisplay.client] ✓ Level monitoring setup complete")
end)

-- Listen for quest completion events from server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local questCompleteEvent = ReplicatedStorage:WaitForChild("QuestComplete")

questCompleteEvent.OnClientEvent:Connect(function(questName, experience, gold)
	print("[LevelUpDisplay.client] Quest completed! Name:", questName, "| XP:", experience, "| Gold:", gold)
	showQuestRewardAnimation(questName, experience, gold)
end)

print("[LevelUpDisplay.client] Quest completion listener setup complete")

return LevelUpDisplay