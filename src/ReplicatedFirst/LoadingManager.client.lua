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

-- Function to check if all systems are ready
local function isGameFullyLoaded()
	-- Check 1: Player stats folder exists and has required values
	local stats = player:FindFirstChild("Stats")
	if not stats then
		return false, "Stats"
	end
	
	local requiredStats = {"Money", "Level", "MaxHealth", "CurrentHealth", "MaxMana", "CurrentMana", "Experience", "NeededExperience"}
	for _, statName in ipairs(requiredStats) do
		if not stats:FindFirstChild(statName) then
			return false, "Stats: " .. statName
		end
	end
	
	-- Check 2: Player inventory loaded (via RemoteFunction)
	local getInventory = ReplicatedStorage:FindFirstChild("GetPlayerInventory")
	if not getInventory or not getInventory:IsA("RemoteFunction") then
		return false, "GetPlayerInventory RemoteFunction"
	end
	
	local success, inventoryData = pcall(function()
		return getInventory:InvokeServer()
	end)
	if not success then
		return false, "Inventory (not responding)"
	end
	
	-- CRITICAL: Verify inventory actually has data
	if not inventoryData or type(inventoryData) ~= "table" or #inventoryData == 0 then
		return false, "Inventory (empty)"
	end
	
	-- Check 3: Player has equipped weapon
	local hasEquippedWeapon = false
	for _, tool in ipairs(player:GetChildren()) do
		if tool:IsA("Tool") then
			hasEquippedWeapon = true
			break
		end
	end
	
	if not hasEquippedWeapon then
		return false, "Equipped weapon"
	end
	
	-- All checks passed!
	return true, "Ready"
end

-- Wait for game to be fully loaded with detailed logging
local maxAttempts = 600 -- 300 seconds at 0.5s intervals (5 minutes max)
local attempts = 0
local checkInterval = 0.5
local lastStatus = ""

while attempts < maxAttempts do
	local isReady, status = isGameFullyLoaded()
	
	-- Only log when status changes to avoid spam
	if status ~= lastStatus then
		if isReady then
		else
		end
		lastStatus = status
	end
	
	if isReady then
		break
	end
	
	attempts = attempts + 1
	task.wait(checkInterval)
end

if attempts >= maxAttempts then
	warn("[LoadingManager] ⚠ Timeout: Game did not fully load after " .. (maxAttempts * checkInterval) .. " seconds")
	warn("[LoadingManager] Last status: " .. lastStatus)
	-- Continue anyway - might just be slow
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