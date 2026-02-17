-- DuelHandler.client.lua
-- Handles displaying the duel countdown (3, 2, 1, Start) to the player


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local DuelMinigameBar = require(script.Parent:WaitForChild("DuelMinigameBar"))

local duelStartedEvent = ReplicatedStorage:WaitForChild("DuelStartedEvent")
local duelEndedEvent = ReplicatedStorage:WaitForChild("DuelEndedEvent")
local duelFinishingEvent = ReplicatedStorage:FindFirstChild("DuelFinishingEvent")


-- RemoteEvent for cross-client sync
local DuelFinishingSyncEvent = ReplicatedStorage:WaitForChild("DuelFinishingSyncEvent")
print("[DuelMinigame][DEBUG] DuelFinishingSyncEvent reference obtained:", DuelFinishingSyncEvent)

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
	local autoAttackActive = false
	local DEFAULT_ATTACK_INTERVAL = 0.1 -- seconds between auto attacks
	local attackInterval = DEFAULT_ATTACK_INTERVAL
	local AttackBridge = require(script.Parent:FindFirstChild("AttackBridge"))

	local function performAttack()
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and AttackBridge then
			AttackBridge.triggerAttack(tool)
		end
	end

	local function startAutoAttack()
		if autoAttackActive then return end
		autoAttackActive = true
		task.spawn(function()
			while autoAttackActive and minigameActive do
				performAttack()
				task.wait(attackInterval)
			end
		end)
	end

	local function stopAutoAttack()
		autoAttackActive = false
	end

	local roundNum = 1
	local function showBar()
		if not minigameActive then return end
		if minigameBarGui then minigameBarGui:Destroy() end
		minigameBarGui = DuelMinigameBar.CreateBar(player.PlayerGui, function(result, markerCenter, safeLeft, safeRight)
			table.insert(minigameResults, {result = result, pos = markerCenter, safeLeft = safeLeft, safeRight = safeRight, timestamp = tick(), round = roundNum})
			if result == "Safe" then
				startAutoAttack()
				roundNum = roundNum + 1
				showBar()
			else -- Miss
				stopAutoAttack()
				attackInterval = DEFAULT_ATTACK_INTERVAL -- Reset combo speed on fail
				roundNum = 1 -- Reset bar speed on fail
				showBar()
			end
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

	-- Start with the first bar
	minigameLoop = task.spawn(function()
		showBar()
		while minigameActive do
			tryAutoUltimate()
			task.wait(0.5)
		end
	end)
end

local function stopDuelMinigame()
	minigameActive = false
	if minigameBarGui then minigameBarGui:Destroy() minigameBarGui = nil end
	if minigameLoop then minigameLoop = nil end
	print("[DuelMinigame] All results:", minigameResults)
	-- Also stop auto attack if running
	autoAttackActive = false
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

if duelFinishingEvent then
	duelFinishingEvent.OnClientEvent:Connect(function(isWinner, opponentUserId)
		-- Forcefully destroy minigame bar and stop any minigame logic immediately
		minigameActive = false
		if minigameBarGui then minigameBarGui:Destroy() minigameBarGui = nil end
		if minigameLoop then minigameLoop = nil end
		print("[DuelMinigame] DuelFinishingEvent received, stopping minigame for finishing animation")

		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animateScript = character:FindFirstChild("Animate")
		if animateScript then
			animateScript.Disabled = true
		end
		if animator then
			-- Stop all current animations before playing the finishing animation
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
			if isWinner then
				-- Winner: play animation and trigger losing animation on keyframe event
				local winnerAnim = Instance.new("Animation")
				winnerAnim.AnimationId = "rbxassetid://115126229605826" -- Winner animation
				print("[DuelMinigame] Playing finishing animation for winner!")
				local winnerTrack = animator:LoadAnimation(winnerAnim)
				winnerTrack.Priority = Enum.AnimationPriority.Action
				winnerTrack:Play()
				-- Listen for animation marker event to trigger losing animation
				local markerConn = winnerTrack:GetMarkerReachedSignal("AnimationHit"):Connect(function()
					print("[DuelMinigame][DEBUG] Winner animation marker 'AnimationHit' reached, firing DuelFinishingSyncEvent to server! opponentUserId:", opponentUserId)
					DuelFinishingSyncEvent:FireServer(opponentUserId)
				end)
				winnerTrack.Stopped:Connect(function()
					if animateScript then
						animateScript.Disabled = false
					end
					if markerConn then markerConn:Disconnect() end
				end)
			else
				-- Loser: wait for a signal to play animation (will be triggered by winner's keyframe event)
				print("[DuelMinigame] Loser waiting for AnimationHit event from winner...")
				DuelFinishingSyncEvent.OnClientEvent:Wait()
				print("[DuelMinigame][DEBUG] DuelFinishingSyncEvent received from server!")
				print("[DuelMinigame] AnimationHit event received! Playing finishing animation for loser!")
				local loserAnim = Instance.new("Animation")
				loserAnim.AnimationId = "rbxassetid://117796996046302" -- Loser animation
				local loserTrack = animator:LoadAnimation(loserAnim)
				loserTrack.Priority = Enum.AnimationPriority.Action
				loserTrack:Play()
				loserTrack.Stopped:Connect(function()
					if animateScript then
						animateScript.Disabled = false
					end
				end)
			end
		end
	end)
end
