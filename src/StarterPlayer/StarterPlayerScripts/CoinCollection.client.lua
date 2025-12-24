-- CoinCollection.client.lua
-- Handles E key input for nearby coin and item drop collection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Get or wait for RemoteEvent
local function getCollectRemote()
	return ReplicatedStorage:WaitForChild("ItemCollect", 5)
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
		
		-- Find the closest collectible item (coins or drops)
		local closestItem = nil
		local closestDistance = COLLECT_DISTANCE
		
		for _, item in ipairs(workspace:GetChildren()) do
			-- Check for coins or item drops
			if item:FindFirstChild("CoinType") or item:FindFirstChild("ItemType") then
				-- Use GetPivot() which works on both parts and models
				local itemPivot = item:GetPivot()
				if itemPivot then
					local distance = (itemPivot.Position - playerRoot.Position).Magnitude
					if distance <= closestDistance then
						closestDistance = distance
						closestItem = item
					end
				end
			end
		end
		
		-- Collect the closest item
		if closestItem then
			local remote = getCollectRemote()
			if remote then
				remote:FireServer(closestItem)
			end
		end
	end
end)

-- Update character reference on respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)

