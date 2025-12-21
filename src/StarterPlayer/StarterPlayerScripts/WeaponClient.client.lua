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

-- Track event connections for cleanup
local childAddedConnection
local childRemovedConnection

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
	
	-- Play Attack animation if it exists
	local attackAnimation = tool:FindFirstChild("Attack")
	if attackAnimation and attackAnimation:IsA("Animation") then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
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
		
		-- Check attack cooldown (matches server's cooldown logic: 1 / speed)
		local weaponName = currentTool.Name
		local now = tick()
		local lastAttack = lastAttackTimes[weaponName] or 0
		local weaponStats = WeaponData.GetWeaponStats(weaponName)
		local speed = weaponStats and weaponStats.speed or 1 -- Default speed if weapon not found
		
		if (now - lastAttack) < (speed) then
			print("[WeaponClient] Attack cooldown active for " .. weaponName)
			return
		end
		
		lastAttackTimes[weaponName] = now
		performAttack(currentTool)
	end
end)