-- LoadingManager.client.lua
-- Manages the loading screen and hides it when the game is fully loaded
-- Placed in ReplicatedFirst to run before anything else

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Clone the loading GUI from ReplicatedStorage (not from script, as Rojo deletes script children on sync)
local loadingGuiTemplate = ReplicatedStorage:WaitForChild("LoadingGuiTemplate", 10)
if not loadingGuiTemplate then
	warn("[LoadingManager] LoadingGuiTemplate not found in ReplicatedStorage!")
	return
end

local loadingGui = loadingGuiTemplate:Clone()
loadingGui.Parent = playerGui

-- ENSURE the loading GUI is visible from the start
loadingGui.Enabled = true

-- Try to find and show the main frame/background
local loadingFrame = loadingGui:FindFirstChild("Frame") or loadingGui:FindFirstChild("Background")
if loadingFrame then
	loadingFrame.Visible = true
else
	print("[LoadingManager] No Frame/Background found in LoadingGui, GUI structure: " .. table.concat({loadingGui:GetChildren()}, ", "))
end

-- Track when loading started (to enforce minimum display time)
local loadingStartTime = tick()

-- Function to check if player has equipped weapon
local function hasEquippedWeapon()
	local character = player.Character
	if not character then return false end
	
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return true, child
		end
	end
	
	return false, nil
end

-- Function to preload animations by playing them
local function preloadAnimationsFromWeapon(weapon)
	local character = player.Character
	if not character or not weapon then return false end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return false end
	
	-- Play each animation child in the weapon
	local animationsPlayed = 0
	for _, child in ipairs(weapon:GetChildren()) do
		if child:IsA("Animation") then
			pcall(function()
				local track = animator:LoadAnimation(child)
				if track then
					track:Play()
					task.wait(0.1)  -- Brief play to cache it
					track:Stop()
					animationsPlayed = animationsPlayed + 1
				end
			end)
		end
	end
	
	return animationsPlayed > 0
end

-- Wait for player to equip weapon and preload animations
local maxAttempts = 600  -- 5 minutes max
local attempts = 0
local checkInterval = 0.5
local animationsPreloaded = false

while attempts < maxAttempts do
	local hasWeapon, equippedWeapon = hasEquippedWeapon()
	
	if hasWeapon and not animationsPreloaded then
		-- Try to preload animations from equipped weapon
		animationsPreloaded = preloadAnimationsFromWeapon(equippedWeapon)
		if animationsPreloaded then
			break
		end
	end
	
	attempts = attempts + 1
	task.wait(checkInterval)
end

-- Enforce MINIMUM loading screen display time (at least 2 seconds)
local elapsedTime = tick() - loadingStartTime
local minimumDisplayTime = 2
if elapsedTime < minimumDisplayTime then
	local remainingTime = minimumDisplayTime - elapsedTime
	task.wait(remainingTime)
end

-- Try to fade the loading GUI
if loadingFrame then
	-- Simple fade: reduce transparency
	local startTransparency = loadingFrame.BackgroundTransparency or 0
	for i = 0, 10 do
		if loadingFrame then
			loadingFrame.BackgroundTransparency = startTransparency + (i / 10) * (1 - startTransparency)
		end
		task.wait(0.05)
	end
end

-- Hide the loading screen
if loadingFrame then
	loadingFrame.Visible = false
end
loadingGui.Enabled = false