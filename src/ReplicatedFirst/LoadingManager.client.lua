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
	--print("[LoadingManager] No Frame/Background found in LoadingGui, GUI structure: " .. table.concat({loadingGui:GetChildren()}, ", "))
end

-- Find the loading percentage label
local loadingLabel = loadingFrame and loadingFrame:FindFirstChild("TextLabel")



-- Define major loading steps
local loadingSteps = {
	"Loading GUI",                -- 1
	"Waiting for PlayerGui",      -- 2
	"Waiting for Character",      -- 3
	"Preloading Accessories",     -- 4
	"Preloading Particles",       -- 5
	"Loading Inventory",          -- 6
	"Loading Inventory UI",       -- 7
	"Loading Client Modules",     -- 8 (NEW)
	"Waiting for Weapon Equip",   -- 9
	"Preloading Animations",      -- 10
}
local totalSteps = #loadingSteps
local completedSteps = 0
local lastPercent = 0
local function updateLoadingLabel(targetPercent, animate)
	if not loadingLabel then return end
	targetPercent = targetPercent or math.floor((completedSteps / totalSteps) * 100)
	if targetPercent >= 100 and completedSteps < totalSteps then targetPercent = 99 end
	if targetPercent > 100 then targetPercent = 100 end
	if not animate then
		loadingLabel.Text = "Loading ... " .. targetPercent .. "%"
		lastPercent = targetPercent
		return
	end
	-- Animate from lastPercent to targetPercent
	local step = (targetPercent > lastPercent) and 1 or -1
	for p = lastPercent + step, targetPercent, step do
		loadingLabel.Text = "Loading ... " .. p .. "%"
		lastPercent = p
		task.wait(0.01)
	end
end
updateLoadingLabel()


-- Step 1: GUI loaded and visible
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Step 2: Wait for PlayerGui
if not playerGui or not playerGui.Parent then
	repeat task.wait(0.05) until playerGui and playerGui.Parent
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Step 3: Wait for character
if not player.Character then
	local waited = 0
	while not player.Character do
		task.wait(0.05)
		waited = waited + 0.05
		if waited % 0.2 < 0.06 then
			-- Animate progress during wait
			local percent = math.floor((completedSteps / totalSteps) * 100)
			updateLoadingLabel(percent, false)
		end
	end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Step 4: Preload accessories (from ReplicatedStorage for client compatibility)
local accessoriesFolders = {"Orbs", "OrbItems", "Armor Accessories"}
local accessoriesToPreload = {}
for _, folderName in ipairs(accessoriesFolders) do
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("Accessory") then
				table.insert(accessoriesToPreload, obj)
			end
		end
	end
end


-- Preload all accessories (simulate by cloning/destroying)
for i, accessory in ipairs(accessoriesToPreload) do
	pcall(function()
		local clone = accessory:Clone()
		clone:Destroy()
	end)
	if i % 5 == 0 then
		local percent = math.floor((completedSteps / totalSteps) * 100)
		updateLoadingLabel(percent, false)
	end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Step 5: Preload particles (from ReplicatedStorage for client compatibility)
local vfxFolders = {"HandVFX"}
local particlesToPreload = {}
for _, folderName in ipairs(vfxFolders) do
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				table.insert(particlesToPreload, obj)
			end
		end
	end
end


-- Preload all particles (simulate by enabling/disabling)
for i, particle in ipairs(particlesToPreload) do
	pcall(function()
		particle.Enabled = true
		task.wait(0.01)
		particle.Enabled = false
	end)
	if i % 5 == 0 then
		local percent = math.floor((completedSteps / totalSteps) * 100)
		updateLoadingLabel(percent, false)
	end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

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

-- Function to preload slash VFX particles
local function preloadSlashVFX()
	local character = player.Character
	if not character then return false end
	
	-- Try to find Slash1 and Slash2 in the player's UpperTorso
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso then
		return false
	end
	
	-- Preload Slash1 and Slash2 by enabling/disabling them
	local vfxPreloaded = 0
	for _, slashName in ipairs({"Slash1", "Slash2"}) do
		local slash = upperTorso:FindFirstChild(slashName)
		if slash then
			pcall(function()
				-- Trigger particle emission briefly to cache them
				local function enableParticles(parent)
					if parent:IsA("ParticleEmitter") then
						parent.Enabled = true
					end
					for _, child in ipairs(parent:GetChildren()) do
						enableParticles(child)
					end
				end
				
				local function disableParticles(parent)
					if parent:IsA("ParticleEmitter") then
						parent.Enabled = false
					end
					for _, child in ipairs(parent:GetChildren()) do
						disableParticles(child)
					end
				end
				
				enableParticles(slash)
				task.wait(0.5) -- Play for 5 seconds to cache
				disableParticles(slash)
				
				vfxPreloaded = vfxPreloaded + 1
			end)
		end
	end
	
	return vfxPreloaded > 0
end



-- Preload all accessories (simulate by cloning/destroying)
for _, accessory in ipairs(accessoriesToPreload) do
	pcall(function()
		 local clone = accessory:Clone()
		 clone:Destroy()
	end)
end
completedSteps = completedSteps + 1
updateLoadingLabel()

-- Preload all particles (simulate by enabling/disabling)
for _, particle in ipairs(particlesToPreload) do
	pcall(function()
		 particle.Enabled = true
		 task.wait(0.05)
		 particle.Enabled = false
	end)
end
completedSteps = completedSteps + 1
updateLoadingLabel()

local inventoryLoaded = false
local inventoryEvent = ReplicatedStorage:FindFirstChild("InventoryLoaded")
if inventoryEvent and inventoryEvent:IsA("BindableEvent") then
	local waited = 0
	while not inventoryLoaded do
		local conn
		conn = inventoryEvent.Event:Connect(function()
			inventoryLoaded = true
			if conn then conn:Disconnect() end
		end)
		while not inventoryLoaded and waited < 5 do
			task.wait(0.05)
			waited = waited + 0.05
			if waited % 0.2 < 0.06 then
				local percent = math.floor((completedSteps / totalSteps) * 100)
				updateLoadingLabel(percent, false)
			end
		end
		if conn then conn:Disconnect() end
		if not inventoryLoaded then
			task.wait(0.1)
		end
	end
else
	-- Fallback: wait a short time, animate
	local waited = 0
	while waited < 0.5 do
		task.wait(0.05)
		waited = waited + 0.05
		if waited % 0.2 < 0.06 then
			local percent = math.floor((completedSteps / totalSteps) * 100)
			updateLoadingLabel(percent, false)
		end
	end
	inventoryLoaded = true
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)


-- Step: Wait for Inventory UI to finish initial refresh

local inventoryUIReadyEvent = ReplicatedStorage:FindFirstChild("InventoryUIReady")
if not inventoryUIReadyEvent then
	inventoryUIReadyEvent = Instance.new("BindableEvent")
	inventoryUIReadyEvent.Name = "InventoryUIReady"
	inventoryUIReadyEvent.Parent = ReplicatedStorage
end
if inventoryUIReadyEvent and inventoryUIReadyEvent:IsA("BindableEvent") then
	local waited = 0
	local ready = false
	local conn
	conn = inventoryUIReadyEvent.Event:Connect(function()
		ready = true
		if conn then conn:Disconnect() end
	end)
	while not ready and waited < 5 do
		task.wait(0.05)
		waited = waited + 0.05
		if waited % 0.2 < 0.06 then
			local percent = math.floor((completedSteps / totalSteps) * 100)
			updateLoadingLabel(percent, false)
		end
	end
	if conn then conn:Disconnect() end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Step: Require client modules and wait for DClientModulesReady
local dClientModulesReady = ReplicatedStorage:FindFirstChild("DClientModulesReady")
if not dClientModulesReady then
	dClientModulesReady = Instance.new("BindableEvent")
	dClientModulesReady.Name = "DClientModulesReady"
	dClientModulesReady.Parent = ReplicatedStorage
end
if dClientModulesReady and dClientModulesReady:IsA("BindableEvent") then
	local waited = 0
	local ready = false
	local conn
	conn = dClientModulesReady.Event:Connect(function()
		ready = true
		if conn then conn:Disconnect() end
	end)
	while not ready and waited < 5 do
		task.wait(0.05)
		waited = waited + 0.05
		if waited % 0.2 < 0.06 then
			local percent = math.floor((completedSteps / totalSteps) * 100)
			updateLoadingLabel(percent, false)
		end
	end
	if conn then conn:Disconnect() end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)






-- Wait for tool to actually appear in character or backpack before listening for WeaponConnected
local function waitForToolPresent(timeout)
	timeout = timeout or 5
	local startTime = tick()
	while tick() - startTime < timeout do
		local found = false
		local character = player.Character
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					found = true
					break
				end
			end
		end
		if not found then
			for _, child in ipairs(player:GetChildren()) do
				if child:IsA("Tool") then
					found = true
					break
				end
			end
		end
		if found then return true end
		task.wait(0.1)
	end
	return false
end


do
	local waited = 0
	while not waitForToolPresent(5) and waited < 5 do
		task.wait(0.05)
		waited = waited + 0.05
		if waited % 0.2 < 0.06 then
			local percent = math.floor((completedSteps / totalSteps) * 100)
			updateLoadingLabel(percent, false)
		end
	end
end

local weaponConnectedEvent = ReplicatedStorage:WaitForChild("WeaponConnected")
local weaponConnected = false
local weaponConnectedTimeout = 5
local weaponConnectedConn
weaponConnectedConn = weaponConnectedEvent.OnClientEvent:Connect(function(weaponName)
	weaponConnected = true
	if weaponConnectedConn then
		weaponConnectedConn:Disconnect()
	end
end)
local startTime = tick()
while not weaponConnected and tick() - startTime < weaponConnectedTimeout do
	task.wait(0.05)
	if (tick() - startTime) % 0.2 < 0.06 then
		local percent = math.floor((completedSteps / totalSteps) * 100)
		updateLoadingLabel(percent, false)
	end
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)


-- Step: Preload animations (if weapon equipped)
local weaponEquipped, weapon = hasEquippedWeapon()
if weaponEquipped then
	preloadAnimationsFromWeapon(weapon)
end
completedSteps = completedSteps + 1
updateLoadingLabel(nil, true)

-- Enforce MINIMUM loading screen display time (at least 2 seconds)
local elapsedTime = tick() - loadingStartTime
local minimumDisplayTime = 2
if elapsedTime < minimumDisplayTime then
	local remainingTime = minimumDisplayTime - elapsedTime
	task.wait(remainingTime)
end

-- Animate from 90% to 100% before hiding
local function animateTo100()
	if loadingLabel then
		for p = 91, 100 do
			loadingLabel.Text = "Loading ... " .. p .. "%"
			task.wait(0.03)
		end
	end
end
animateTo100()

-- Before hiding the loading screen, break joints and wait for respawn
local character = player.Character
if character then
	--print("[LoadingManager] Breaking joints to force respawn...")
	character:BreakJoints()
end
local newCharacter = player.CharacterAdded:Wait()
local humanoid = newCharacter:FindFirstChild("Humanoid")
while not humanoid do
	humanoid = newCharacter:FindFirstChild("Humanoid")
	task.wait(0.05)
end
--print("[LoadingManager] Respawned and Humanoid found, hiding loading screen.")

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
