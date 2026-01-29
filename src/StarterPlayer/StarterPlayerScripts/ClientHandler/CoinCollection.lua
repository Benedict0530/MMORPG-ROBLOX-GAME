-- CoinCollection.client.lua
-- Handles E key input for nearby coin and item drop collection
local CoinCollection = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundModule = require(ReplicatedStorage.Modules.SoundModule)
local SFXEvent = ReplicatedStorage:FindFirstChild("SFXEvent")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local pickupButton = nil

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
		-- Just notify server to collect nearest item
		local remote = getCollectRemote()
		if remote then
			remote:FireServer()
		end
	end
end)



-- Setup pickup button for mobile
local function setupPickupButton()
	-- Only setup if touch is enabled
	if not UserInputService.TouchEnabled then return end
	
	local playerGui = player:WaitForChild("PlayerGui")
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	pickupButton = frame:FindFirstChild("PickupButton")
	if not pickupButton then return end
	
	-- Handle pickup button click
	pickupButton.MouseButton1Click:Connect(function()
		-- Prevent multiple collections in quick succession
		if collectDebounce then return end
		collectDebounce = true
		task.delay(COLLECT_COOLDOWN, function() collectDebounce = false end)
		-- Just notify server to collect nearest item
		local remote = getCollectRemote()
		if remote then
			remote:FireServer()
		end
	end)
end

-- Setup pickup button after player GUI is loaded
task.wait(0.5)
setupPickupButton()

-- Update character reference on respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)
return CoinCollection