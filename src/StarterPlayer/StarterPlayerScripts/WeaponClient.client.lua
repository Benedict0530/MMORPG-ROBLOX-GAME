-- WeaponClient.client.lua
-- Handles weapon equipping, animations, and attack events on the client

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Attack cooldown tracking (matches server's cooldown logic)
local lastAttackTimes = {} -- keys are tool instances
local currentTool = nil
local isSpaceHeld = false
local attackLoopConnection = nil
local attackCounter = 0 -- Track which attack animation to play

-- Track event connections for cleanup
local childAddedConnection
local childRemovedConnection
local attackButtonConnection

local function setupCharacter(newCharacter)
	-- Disconnect old connections
	if childAddedConnection then childAddedConnection:Disconnect() end
	if childRemovedConnection then childRemovedConnection:Disconnect() end
	
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	currentTool = nil
	lastAttackTimes = {}
	
	-- Reconnect to new character
	childAddedConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentTool = child
			
			-- Play Idle animation on loop when weapon is equipped
			local idleAnimation = child:FindFirstChild("Idle")
			if idleAnimation and idleAnimation:IsA("Animation") then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					-- Stop all current animations first
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						track:Stop()
					end
					
					local track = animator:LoadAnimation(idleAnimation)
					track.Looped = true
					track:Play()
				end
			end
		end
	end)

	childRemovedConnection = character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and currentTool == child then
			currentTool = nil
		end
	end)
end

-- Initial character setup
setupCharacter(character)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	setupCharacter(newCharacter)
end)

-- Function to perform attack
local function performAttack(tool)
	if not tool or not tool.Name then return end
		
	-- Fire the SwingEvent to server
	local swingEvent = tool:FindFirstChild("SwingEvent")
	if swingEvent then
		swingEvent:FireServer()
	else
		warn("[WeaponClient] Weapon " .. tool.Name .. " has no SwingEvent")
		return
	end
	
	-- Alternate between Attack1 and Attack2 animations
	attackCounter = attackCounter + 1
	local attackAnimName = (attackCounter % 2 == 1) and "Attack1" or "Attack2"
	local attackAnimation = tool:FindFirstChild(attackAnimName)
	
	if attackAnimation and attackAnimation:IsA("Animation") then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			-- Stop all currently playing animations
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
			
			local track = animator:LoadAnimation(attackAnimation)
			track:Play()
		end
	end
end

-- Handle spacebar input for attack
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Space then
		if not currentTool then
			return
		end
		
		isSpaceHeld = true
		
		-- Disconnect previous attack loop if any
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		
		-- Start attack loop while space is held
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if not isSpaceHeld or not currentTool then
				return
			end
			
			-- Check if player is alive
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			
			-- Check attack cooldown (matches server's cooldown logic: 1 / speed)
			local weaponName = currentTool.Name
			local now = tick()
			local lastAttack = lastAttackTimes[weaponName] or 0
			local weaponStats = WeaponData.GetWeaponStats(weaponName)
			local speed = weaponStats and weaponStats.speed or 1 -- Default speed if weapon not found
			
			if (now - lastAttack) >= speed then
				lastAttackTimes[weaponName] = now
				performAttack(currentTool)
			end
		end)
	end
end)

-- Handle spacebar release to stop attacking
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space then
		isSpaceHeld = false
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
	end
end)

-- Setup attack button for mobile
local function setupAttackButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local attackButton = frame:FindFirstChild("AttackButton")
	if not attackButton then return end
	
	-- Show button only if touch is enabled
	attackButton.Visible = UserInputService.TouchEnabled
	
	-- Disconnect old connection if any
	if attackButtonConnection then
		attackButtonConnection:Disconnect()
	end
	
	-- Handle attack button down (start attacking)
	attackButton.MouseButton1Down:Connect(function()
		if not currentTool then return end
		
		isSpaceHeld = true
		
		-- Disconnect previous attack loop if any
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
		end
		
		-- Start attack loop while button is held
		attackLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if not isSpaceHeld or not currentTool then
				return
			end
			
			-- Check if player is alive
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			
			-- Check attack cooldown (matches server's cooldown logic: 1 / speed)
			local weaponName = currentTool.Name
			local now = tick()
			local lastAttack = lastAttackTimes[weaponName] or 0
			local weaponStats = WeaponData.GetWeaponStats(weaponName)
			local speed = weaponStats and weaponStats.speed or 1 -- Default speed if weapon not found
			
			if (now - lastAttack) >= speed then
				lastAttackTimes[weaponName] = now
				performAttack(currentTool)
			end
		end)
	end)
	
	-- Handle attack button up (stop attacking)
	attackButton.MouseButton1Up:Connect(function()
		isSpaceHeld = false
		if attackLoopConnection then
			attackLoopConnection:Disconnect()
			attackLoopConnection = nil
		end
	end)
end

-- Setup attack button after player GUI is loaded
task.wait(0.5)
setupAttackButton()