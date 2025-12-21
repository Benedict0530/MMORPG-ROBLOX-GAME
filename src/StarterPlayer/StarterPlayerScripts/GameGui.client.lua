local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)

-- Hide default Roblox health bar immediately
local healthGui = playerGui:WaitForChild("HealthGui", 5)
if healthGui then
	healthGui.Enabled = false
end
-- Variables that will be reset on character respawn
local character
local stats
local money
local level
local health
local mana
local experience
local neededExperience
local previousHealth

-- UI elements (will be refreshed on respawn)
local gameGui
local gameGuiFrame
local healthBar
local manaBar
local coins
local levelText
local experienceBar
local experienceText

-- Event connections that need cleanup
local healthConnection
local manaConnection
local moneyConnection
local levelConnection
local experienceConnection
local neededExperienceConnection

-- Update coins display when money changes
local function updateCoins(value)
	if coins then
		coins.Text = "$ " .. tostring(value)
	end
end

-- Update level display when level changes
local function updateLevel(value)
	if levelText then
		levelText.Text = "Lv " .. tostring(value)
	end
end

-- Update health bar when health changes
local function updateHealthBar(value)
	local maxHealth = 50
	local healthPercent = math.max(0, math.min(value / maxHealth, 1))
	healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
end

-- Update mana bar when mana changes
local function updateManaBar(value)
	manaBar.Size = UDim2.new(value / 5, 0, 1, 0) -- Assuming max mana is 5
end

-- Update experience bar and text when experience or needed experience changes
local function updateExperienceBar()
	if not experience or not neededExperience or not experienceBar then 
		return 
	end
	
	local exp = experience.Value or 0
	local needed = neededExperience.Value or 10
	
	-- Prevent division by zero
	if needed <= 0 then needed = 10 end
	
	local expPercent = math.max(0, math.min(exp / needed, 1))
	
	experienceBar.Size = UDim2.new(expPercent, 0, 1, 0)
	
	if experienceText then
		experienceText.Text = tostring(exp) .. "/" .. tostring(needed)
	end
	
	print("[GameGui] Experience updated: " .. exp .. "/" .. needed .. " (" .. math.floor(expPercent * 100) .. "%)")
end
-- Show damage text floating above torso
local function showDamageText(damageAmount)
	if not character then return end
	
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then return end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 100
	billboard.Parent = torso
	
	-- Create TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "DamageText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "-" .. tostring(damageAmount)
	textLabel.TextSize = 24
	textLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
	textLabel.TextScaled = false
	textLabel.Parent = billboard
	
	-- Add white stroke
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(84, 84, 84) -- White
	textStroke.Thickness = 2
	textStroke.Parent = textLabel
	
	-- Animate fade and rise
	local startTime = tick()
	local duration = 1.5 -- Duration of animation in seconds
	
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / duration, 1)
		
		-- Move up
		billboard.StudsOffset = Vector3.new(0, 3 + (progress * 2), 0)
		
		-- Fade out
		textLabel.TextTransparency = progress
		textStroke.Transparency = progress
		
		if progress >= 1 then
			connection:Disconnect()
			billboard:Destroy()
		end
	end)
end

-- Show damage text floating above enemy head
local function showEnemyDamageText(enemyModel, damageAmount)
	if not enemyModel or not enemyModel.Parent then return end
	
	local enemyHead = enemyModel:FindFirstChild("Head")
	if not enemyHead then return end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 100
	billboard.Parent = enemyHead
	
	-- Create TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "EnemyDamageText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "-" .. tostring(damageAmount)
	textLabel.TextSize = 24
	textLabel.TextColor3 = Color3.fromRGB(255, 254, 254)
	textLabel.TextScaled = false
	textLabel.Parent = billboard
	
	-- Add white stroke
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(84, 84, 84) -- Gray
	textStroke.Thickness = 2
	textStroke.Parent = textLabel
	
	-- Animate fade and rise
	local startTime = tick()
	local duration = 1.5 -- Duration of animation in seconds
	
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / duration, 1)
		
		-- Move up
		billboard.StudsOffset = Vector3.new(0, 3 + (progress * 2), 0)
		
		-- Fade out
		textLabel.TextTransparency = progress
		textStroke.Transparency = progress
		
		if progress >= 1 then
			connection:Disconnect()
			billboard:Destroy()
		end
	end)
end

-- Update health bar when health changes
local function updateHealthBarWithDamage(value)
	local damage = previousHealth - value
	if damage > 0 then
		showDamageText(damage)
	end
	previousHealth = value
	updateHealthBar(value)
end

local function setupCharacter(newCharacter)
	-- Cleanup old connections
	if healthConnection then 
		healthConnection:Disconnect() 
	end
	if manaConnection then 
		manaConnection:Disconnect() 
	end
	if moneyConnection then 
		moneyConnection:Disconnect() 
	end
	if levelConnection then 
		levelConnection:Disconnect() 
	end
	if experienceConnection then 
		experienceConnection:Disconnect() 
	end
	if neededExperienceConnection then 
		neededExperienceConnection:Disconnect() 
	end
	
	character = newCharacter
	
	-- Refresh UI references on each respawn
	gameGui = playerGui:WaitForChild("GameGui", 5)
	gameGuiFrame = gameGui:WaitForChild("Frame", 5)
	healthBar = gameGuiFrame:WaitForChild("Health", 5):WaitForChild("HealthBar", 5)
	manaBar = gameGuiFrame:WaitForChild("Mana", 5):WaitForChild("ManaBar", 5)
	coins = gameGuiFrame:WaitForChild("Coins", 5)
	levelText = gameGuiFrame:WaitForChild("Level", 5)
	experienceBar = gameGuiFrame:WaitForChild("Experience", 5):WaitForChild("ExperienceBar", 5)
	experienceText = gameGuiFrame:WaitForChild("Experience", 5):WaitForChild("Text", 5)
	
	if not gameGui or not gameGuiFrame or not healthBar or not manaBar or not coins or not levelText or not experienceBar or not experienceText then
		warn("UI elements not found!")
		return
	end
	
	-- Wait for Stats folder to exist (with timeout)
	stats = player:WaitForChild("Stats", 5)
	if not stats then warn("Stats folder not found!") return end
	
	money = stats:WaitForChild("Money", 5)
	level = stats:WaitForChild("Level", 5)
	health = stats:WaitForChild("Health", 5)
	mana = stats:WaitForChild("Mana", 5)
	experience = stats:WaitForChild("Experience", 5)
	neededExperience = stats:WaitForChild("NeededExperience", 5)
	
	if not money or not level or not health or not mana or not experience or not neededExperience then warn("Missing stat values!") return end
	
	-- Reset health tracking with current value
	previousHealth = health.Value
	
	-- Update UI immediately with current values
	updateHealthBar(health.Value)
	updateManaBar(mana.Value)
	updateCoins(money.Value)
	updateLevel(level.Value)
	updateExperienceBar()
	
	-- Connect to changes
	moneyConnection = money.Changed:Connect(updateCoins)
	healthConnection = health.Changed:Connect(updateHealthBarWithDamage)
	manaConnection = mana.Changed:Connect(updateManaBar)
	levelConnection = level.Changed:Connect(updateLevel)
	experienceConnection = experience.Changed:Connect(updateExperienceBar)
	neededExperienceConnection = neededExperience.Changed:Connect(updateExperienceBar)
end

-- Initial character setup
setupCharacter(player.Character or player.CharacterAdded:Wait())

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	setupCharacter(newCharacter)
end)

-- Listen for enemy damage events from server
local damageEvent = ReplicatedStorage:WaitForChild("EnemyDamage")
damageEvent.OnClientEvent:Connect(function(enemyModel, damageAmount)
	showEnemyDamageText(enemyModel, damageAmount)
end)

