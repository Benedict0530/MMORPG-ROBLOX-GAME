-- DuelHandler.client.lua
-- Handles displaying the duel countdown (3, 2, 1, Start) to the player


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local DuelMinigameBar = require(script.Parent:WaitForChild("DuelMinigameBar"))
local duelStartedEvent = ReplicatedStorage:WaitForChild("DuelStartedEvent")
local duelEndedEvent = ReplicatedStorage:WaitForChild("DuelEndedEvent")

-- Minigame state
local minigameActive = false
local minigameResults = {}
local minigameBarGui = nil
local minigameLoop = nil

-- Create a simple screen GUI for the countdown
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DuelCountdownGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "CountdownLabel"
countdownLabel.Size = UDim2.new(0.4, 0, 0.2, 0)
countdownLabel.Position = UDim2.new(0.3, 0, 0.35, 0)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextScaled = true
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextColor3 = Color3.new(1, 1, 1)
countdownLabel.TextStrokeTransparency = 0.2
countdownLabel.Visible = false
countdownLabel.Parent = screenGui

local countdownEvent = ReplicatedStorage:WaitForChild("DuelCountdownEvent")

-- Minigame logic
local function startDuelMinigame()
	       minigameActive = true
	       minigameResults = {}
	       local roundNum = 1
	       local function showBar()
		       if not minigameActive then return end
		       if minigameBarGui then minigameBarGui:Destroy() end
		       local AttackBridge = require(script.Parent:FindFirstChild("AttackBridge"))
		       minigameBarGui = DuelMinigameBar.CreateBar(player.PlayerGui, function(result, markerCenter, safeLeft, safeRight)
			       table.insert(minigameResults, {result = result, pos = markerCenter, safeLeft = safeLeft, safeRight = safeRight, timestamp = tick(), round = roundNum})
			       if result == "Safe" then
				       -- Only perform attack if in safezone
				       local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
				       if tool and AttackBridge then
					       AttackBridge.triggerAttack(tool)
				       end
			       end
			       -- Do nothing for Miss
		       end, roundNum)
	       end

	       -- Auto-perform ultimate if full during duel
	       local stats = player:FindFirstChild("Stats")
	       local ultimateSkillRemote = game:GetService("ReplicatedStorage"):FindFirstChild("UltimateSkill")
	       local function tryAutoUltimate()
		       if not stats or not ultimateSkillRemote then return end
		       local ultimateStat = stats:FindFirstChild("UltimateCharge")
		       if ultimateStat and ultimateStat.Value >= 100 then
			       ultimateSkillRemote:FireServer()
		       end
	       end

	       -- Show bar every 2 seconds, check ultimate each loop
	       minigameLoop = task.spawn(function()
		       while minigameActive do
			       showBar()
			       tryAutoUltimate()
			       roundNum = roundNum + 1
			       task.wait(2)
		       end
	       end)
end

local function stopDuelMinigame()
	minigameActive = false
	if minigameBarGui then minigameBarGui:Destroy() minigameBarGui = nil end
	if minigameLoop then minigameLoop = nil end
	print("[DuelMinigame] All results:", minigameResults)
end


local minigameShouldStart = false
local function showCountdown(text)
	countdownLabel.Text = tostring(text)
	countdownLabel.Visible = true
	if text == "Start" then
		countdownLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red for 'Start'
		minigameShouldStart = true
	else
		countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	-- Fade out after 0.7s for numbers, 1.2s for "Start"
	local fadeTime = (text == "Start") and 1.2 or 0.7
	task.spawn(function()
		wait(fadeTime)
		countdownLabel.Visible = false
		if minigameShouldStart then
			minigameShouldStart = false
			startDuelMinigame()
		end
	end)
end

countdownEvent.OnClientEvent:Connect(showCountdown)

-- Listen for duel start/end
-- Don't start minigame on duel start, only after 'Start' UI
if duelEndedEvent then
	duelEndedEvent.OnClientEvent:Connect(function()
		stopDuelMinigame()
	end)
end
