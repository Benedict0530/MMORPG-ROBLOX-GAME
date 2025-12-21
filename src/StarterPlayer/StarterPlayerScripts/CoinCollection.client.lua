-- CoinCollection.client.lua
-- Handles E key input for nearby coin collection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Get or wait for RemoteEvent
local function getCoinCollectRemote()
	return ReplicatedStorage:WaitForChild("CoinCollect", 5)
end

local COLLECT_DISTANCE = 5
local collectDebounce = false
local COLLECT_COOLDOWN = 0.3

-- Handle E key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		-- Prevent multiple collections in quick succession
		if collectDebounce then return end
		collectDebounce = true
		task.delay(COLLECT_COOLDOWN, function() collectDebounce = false end)
		
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return
		end
		
		local playerRoot = character.HumanoidRootPart
		
		-- Find the closest coin
		local closestCoin = nil
		local closestDistance = COLLECT_DISTANCE
		
		for _, item in ipairs(workspace:GetChildren()) do
			if item:FindFirstChild("CoinType") then
				local coinRoot = item:FindFirstChild("HumanoidRootPart") or item:FindFirstChild("PrimaryPart") or item
				if coinRoot then
					local distance = (coinRoot.Position - playerRoot.Position).Magnitude
					if distance <= closestDistance then
						closestDistance = distance
						closestCoin = item
					end
				end
			end
		end
		
		-- Collect only the closest coin
		if closestCoin then
			local remote = getCoinCollectRemote()
			if remote then
				remote:FireServer(closestCoin)
			end
		end
	end
end)

-- Update character reference on respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)
