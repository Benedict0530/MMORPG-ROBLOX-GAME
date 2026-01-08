local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeaponData = require(ReplicatedStorage.Modules.WeaponData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Hide default Roblox health bar immediately
pcall(function()
	local healthGui = playerGui:WaitForChild("HealthGui", 5)
	if healthGui then
		healthGui.Enabled = false
	end
end)

-- ============ CONSTANTS ============
local DEFAULT_NEEDED_EXP = 10
local DAMAGE_TEXT_DURATION = 1.5
local DAMAGE_TEXT_RISE = 2
local DAMAGE_TEXT_HEIGHT = 3
local WAIT_TIMEOUT = 5

-- ============ CHARACTER STATE ============
local character
local stats
local money
local level
local maxHealth
local currentHealth
local maxMana
local currentMana
local experience
local neededExperience
local previousHealth

-- ============ UI ELEMENTS ============
local gameGui
local gameGuiFrame
local healthBar
local manaBar
local coins
local levelText
local experienceBar
local experienceText

-- ============ EVENT CONNECTIONS ============
local connections = {}

-- ============ CLEANUP CONNECTIONS ============
local function disconnectAll()
	for _, connection in pairs(connections) do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(connections)
end

-- ============ UTILITY FUNCTIONS ============
local function formatNumberWithCommas(num)
	local formatted = tostring(num)
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- ============ UI UPDATE FUNCTIONS ============
local function updateCoins(value)
	if coins then
		coins.Text = "$ " .. formatNumberWithCommas(value)
	end
end

local function updateLevel(value)
	if levelText then
		levelText.Text = "Lv " .. tostring(value)
	end
end

local function updateHealthBar(value)
	if not maxHealth or maxHealth.Value <= 0 then return end
	local healthPercent = math.max(0, math.min(value / maxHealth.Value, 1))
	healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
end

local function updateManaBar(value)
	if not manaBar then return end
	if not maxMana or maxMana.Value <= 0 then return end
	local manaPercent = math.max(0, math.min(value / maxMana.Value, 1))
	manaBar.Size = UDim2.new(manaPercent, 0, 1, 0)
end

local function updateExperienceBar()
	if not experience or not neededExperience or not experienceBar then 
		return 
	end
	
	local exp = experience.Value or 0
	local needed = neededExperience.Value or DEFAULT_NEEDED_EXP
	
	if needed <= 0 then needed = DEFAULT_NEEDED_EXP end
	
	local expPercent = math.max(0, math.min(exp / needed, 1))
	experienceBar.Size = UDim2.new(expPercent, 0, 1, 0)
	
	if experienceText then
		experienceText.Text = formatNumberWithCommas(exp) .. "/" .. formatNumberWithCommas(needed) .. " XP"
	end
end

-- ============ STATSINFO UPDATE FUNCTIONS ============
local function updateStatsInfoDisplay()
	if not stats or not gameGuiFrame then return end
	
	local statsInfo = gameGuiFrame:FindFirstChild("StatsInfo")
	if not statsInfo then return end
	
	local textsFolder = statsInfo:FindFirstChild("Background")
	if textsFolder then
		textsFolder = textsFolder:FindFirstChild("Texts")
	end
	
	local statsValueFolder = statsInfo:FindFirstChild("Background")
	if statsValueFolder then
		statsValueFolder = statsValueFolder:FindFirstChild("StatsValue")
	end
	
	if not textsFolder or not statsValueFolder then return end
	
	-- Update Texts folder (stat labels)
	local healthText = textsFolder:FindFirstChild("Health")
	local manaText = textsFolder:FindFirstChild("Mana")
	local attackText = textsFolder:FindFirstChild("Attack")
	local defenceText = textsFolder:FindFirstChild("Defence")
	local dexterityText = textsFolder:FindFirstChild("Dexterity")
	local statPointsText = textsFolder:FindFirstChild("Stat Points")
	
	-- Update StatsValue folder (stat values)
	local healthValue = statsValueFolder:FindFirstChild("Health")
	local manaValue = statsValueFolder:FindFirstChild("Mana")
	local attackValue = statsValueFolder:FindFirstChild("Attack")
	local defenceValue = statsValueFolder:FindFirstChild("Defence")
	local damageValue = statsValueFolder:FindFirstChild("Damage")
	local criticalValue = statsValueFolder:FindFirstChild("Critical")
	local statPointsValue = statsValueFolder:FindFirstChild("Stat Points")
	local dexterityValue = statsValueFolder:FindFirstChild("Dexterity")
	
	-- Get stat objects from player stats
	local maxHealthStat = stats:FindFirstChild("MaxHealth")
	local currentHealthStat = stats:FindFirstChild("CurrentHealth")
	local maxManaStat = stats:FindFirstChild("MaxMana")
	local currentManaStat = stats:FindFirstChild("CurrentMana")
	local attackStat = stats:FindFirstChild("Attack")
	local defenceStat = stats:FindFirstChild("Defence")
	local dexterityStat = stats:FindFirstChild("Dexterity")
	local statPointsStat = stats:FindFirstChild("StatPoints")
	local resetPointsStat = stats:FindFirstChild("ResetPoints")
	
	-- Update text displays
	if healthText and maxHealthStat and currentHealthStat then healthText.Text = "Health:" end
	if healthValue and maxHealthStat and currentHealthStat then healthValue.Text = tostring(currentHealthStat.Value) .. "/" .. tostring(maxHealthStat.Value) end
	
	if manaText and maxManaStat and currentManaStat then manaText.Text = "Mana:" end
	if manaValue and maxManaStat and currentManaStat then manaValue.Text = tostring(currentManaStat.Value) .. "/" .. tostring(maxManaStat.Value) end
	
	if attackText and attackStat then attackText.Text = "Attack:" end
	if attackValue and attackStat then attackValue.Text = tostring(attackStat.Value) end
	
	if defenceText and defenceStat then defenceText.Text = "Defence:" end
	if defenceValue and defenceStat then defenceValue.Text = tostring(defenceStat.Value) end
	
	if dexterityText and dexterityStat then dexterityText.Text = "Dexterity:" end
	if dexterityValue and dexterityStat then dexterityValue.Text = tostring(dexterityStat.Value) end
	
	-- Damage range: min (base * 0.4) to max (base * 2 * 1.6 = base * 3.2) to match server logic
	if damageValue and attackStat then
		local attackDamage = attackStat.Value
		local weaponDamage = 0
		-- Check for equipped weapon and get its damage
		if character then
			local equippedTool = character:FindFirstChildOfClass("Tool")
			if equippedTool then
				local weaponStats = WeaponData.GetWeaponStats(equippedTool.Name)
				if weaponStats and weaponStats.damage then
					weaponDamage = weaponStats.damage
				end
			end
		end
		local base = attackDamage + weaponDamage
		local minDamage = math.floor(base * 0.4)
		local maxDamage = math.floor(base * 3.2)
		damageValue.Text = "Damage: " .. formatNumberWithCommas(minDamage) .. " - " .. formatNumberWithCommas(maxDamage)
	end
	
	if statPointsText and statPointsStat then statPointsText.Text = "Stat Points:" end
	if statPointsValue and statPointsStat then statPointsValue.Text = tostring(statPointsStat.Value) end
	
	-- Critical chance is based on Dexterity: every 3 Dexterity = 1% critical chance
	if criticalValue and dexterityStat then
		local criticalChance = (dexterityStat.Value / 3)
		criticalValue.Text = "Critical Chance: " .. string.format("%.2f", criticalChance) .. "%"
	end
end

-- ============ DAMAGE TEXT DISPLAY ============
local function showDamageText(targetPart, damageAmount, isEnemy, isCritical)
	if not targetPart or not targetPart.Parent then return end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, DAMAGE_TEXT_HEIGHT, 0)
	billboard.MaxDistance = 100
	billboard.Parent = targetPart
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "DamageText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "-" .. formatNumberWithCommas(damageAmount)
	textLabel.TextScaled = false
	textLabel.Font = Enum.Font.FredokaOne
	
	-- Neon sky blue for critical, white for normal enemy damage, red for player damage
	if isCritical then
		textLabel.TextSize = 32 -- Bigger for critical
		textLabel.TextColor3 = Color3.fromRGB(30, 100, 180) -- Darker blue
	else
		textLabel.TextSize = 24
		-- Red if player damage (isEnemy = false), white if enemy damage (isEnemy = true)
		textLabel.TextColor3 = isEnemy and Color3.fromRGB(255, 254, 254) or Color3.fromRGB(255, 0, 0)
	end
	textLabel.Parent = billboard
	
	local textStroke = Instance.new("UIStroke")
	-- White stroke for critical, gray for normal
	textStroke.Color = isCritical and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(84, 84, 84)
	textStroke.Thickness = isCritical and 0.5 or 2
	textStroke.Parent = textLabel
	
	local startTime = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / DAMAGE_TEXT_DURATION, 1)
		
		billboard.StudsOffset = Vector3.new(0, DAMAGE_TEXT_HEIGHT + (progress * DAMAGE_TEXT_RISE), 0)
		textLabel.TextTransparency = progress
		textStroke.Transparency = progress
		
		if progress >= 1 then
			connection:Disconnect()
			billboard:Destroy()
		end
	end)
end

-- ============ EXPERIENCE TEXT DISPLAY ============
local function showExperienceText(expAmount)
	if not character then return end
	
	local targetPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not targetPart or not targetPart.Parent then return end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, DAMAGE_TEXT_HEIGHT + 3, 0)
	billboard.MaxDistance = 999999
	billboard.Parent = targetPart
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "ExperienceText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "+" .. formatNumberWithCommas(expAmount) .. " XP"
	textLabel.TextScaled = false
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextSize = 24
	textLabel.TextColor3 = Color3.fromRGB(255, 254, 254) -- White
	textLabel.Parent = billboard
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(84, 84, 84) -- Gray stroke
	textStroke.Thickness = 2
	textStroke.Parent = textLabel
	
	local startTime = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / DAMAGE_TEXT_DURATION, 1)
		
		-- Float upward like damage text
		billboard.StudsOffset = Vector3.new(0, DAMAGE_TEXT_HEIGHT + 3 + (progress * DAMAGE_TEXT_RISE), 0)
		textLabel.TextTransparency = progress
		textStroke.Transparency = progress
		
		if progress >= 1 then
			connection:Disconnect()
			billboard:Destroy()
		end
	end)
end



local function updateHealthWithDamage(value)
	previousHealth = value
	updateHealthBar(value)
end

-- ============ EXPERIENCE GAIN TRACKING ============
local lastExperienceValue = 0

local function onExperienceGained(value)
	-- Calculate how much XP was gained this tick
	local expGained = value - lastExperienceValue
	lastExperienceValue = value
	
	-- Show floating experience text if gained XP (ignore first load which might be large jump)
	if expGained > 0 then
		showExperienceText(expGained)
	end
	
	updateExperienceBar()
end

-- ============ UI SETUP ============
local function getUIElements()
	local gui = playerGui:WaitForChild("GameGui", WAIT_TIMEOUT)
	if not gui then 
		warn("[GameGui] GameGui not found in PlayerGui!")
		return nil 
	end
	
	local frame = gui:WaitForChild("Frame", WAIT_TIMEOUT)
	if not frame then 
		warn("[GameGui] Frame not found in GameGui!")
		return nil 
	end
	
	local uiElements = {}
	
	-- Try to get each UI element with error handling
	local health = frame:WaitForChild("Health", WAIT_TIMEOUT)
	if health then
		uiElements.healthBar = health:WaitForChild("HealthBar", WAIT_TIMEOUT)
		if not uiElements.healthBar then warn("[GameGui] HealthBar not found") end
	else
		warn("[GameGui] Health container not found")
	end
	
	local mana = frame:WaitForChild("Mana", WAIT_TIMEOUT)
	if mana then
		uiElements.manaBar = mana:WaitForChild("ManaBar", WAIT_TIMEOUT)
		if not uiElements.manaBar then warn("[GameGui] ManaBar not found") end
	else
		warn("[GameGui] Mana container not found")
	end
	
	uiElements.coins = frame:WaitForChild("Coins", WAIT_TIMEOUT)
	if not uiElements.coins then warn("[GameGui] Coins text not found") end
	
	uiElements.levelText = frame:WaitForChild("Level", WAIT_TIMEOUT)
	if not uiElements.levelText then warn("[GameGui] Level text not found") end
	
	local experience = frame:WaitForChild("Experience", WAIT_TIMEOUT)
	if experience then
		uiElements.experienceBar = experience:WaitForChild("ExperienceBar", WAIT_TIMEOUT)
		uiElements.experienceText = experience:WaitForChild("Text", WAIT_TIMEOUT)
		if not uiElements.experienceBar then warn("[GameGui] ExperienceBar not found") end
		if not uiElements.experienceText then warn("[GameGui] Experience text not found") end
	else
		warn("[GameGui] Experience container not found")
	end
	
	-- Check if we got at least some elements
	if not uiElements.healthBar and not uiElements.manaBar then
		warn("[GameGui] Critical: Could not load health/mana bars!")
		return nil
	end
	
	return uiElements
end

local function getStatValues()
	stats = player:WaitForChild("Stats", WAIT_TIMEOUT)
	if not stats then 
		warn("Stats folder not found!")
		return false
	end
	
	money = stats:WaitForChild("Money", WAIT_TIMEOUT)
	level = stats:WaitForChild("Level", WAIT_TIMEOUT)
	maxHealth = stats:WaitForChild("MaxHealth", WAIT_TIMEOUT)
	currentHealth = stats:WaitForChild("CurrentHealth", WAIT_TIMEOUT)
	maxMana = stats:WaitForChild("MaxMana", WAIT_TIMEOUT)
	currentMana = stats:WaitForChild("CurrentMana", WAIT_TIMEOUT)
	experience = stats:WaitForChild("Experience", WAIT_TIMEOUT)
	neededExperience = stats:WaitForChild("NeededExperience", WAIT_TIMEOUT)
	
	if not (money and level and maxHealth and currentHealth and maxMana and currentMana and experience and neededExperience) then
		warn("Missing stat values! Money:" .. tostring(money ~= nil) .. " Level:" .. tostring(level ~= nil) .. " MaxHealth:" .. tostring(maxHealth ~= nil) .. " CurrentHealth:" .. tostring(currentHealth ~= nil))
		return false
	end
	
	return true
end
-- ============ STAT ALLOCATION FUNCTIONS ============
local function sendStatAllocationRequest(statType)
	local statsUpdateEvent = ReplicatedStorage:WaitForChild("AllocateStatPoint", 5)
	if statsUpdateEvent then
		statsUpdateEvent:FireServer("Allocate", statType)
	else
		warn("[GameGui] AllocateStatPoint event not found")
	end
end

local function resetStatsRequest()
	local statsUpdateEvent = ReplicatedStorage:WaitForChild("AllocateStatPoint", 5)
	if statsUpdateEvent then
		statsUpdateEvent:FireServer("Reset")
	else
		warn("[GameGui] AllocateStatPoint event not found")
	end
end

-- ============ THUMBSTICK VISIBILITY FUNCTION ============
local function updateThumbstickVisibility()
	local thumbstickGui = playerGui:FindFirstChild("ThumbstickGui")
	if not thumbstickGui then return end
	
	-- Get UI state
	local statsInfo = gameGuiFrame and gameGuiFrame:FindFirstChild("StatsInfo")
	local inventoryUI = gameGuiFrame and gameGuiFrame:FindFirstChild("InventoryUI")
	
	-- Check if either UI is visible
	local statsInfoOpen = statsInfo and statsInfo.Visible or false
	local inventoryUIOpen = inventoryUI and inventoryUI.Visible or false
	
	-- Disable thumbstick if either UI is open, otherwise enable if touch is enabled
	local UserInputService = game:GetService("UserInputService")
	if statsInfoOpen or inventoryUIOpen then
		thumbstickGui.Enabled = false
	else
		thumbstickGui.Enabled = UserInputService.TouchEnabled
	end
end

-- ============ CHARACTER SETUP ============
local function setupCharacter(newCharacter)
	-- Cleanup old connections
	disconnectAll()
	
	character = newCharacter
	
	-- Get UI elements
	local uiElements = getUIElements()
	if not uiElements then return end
	
	gameGui = uiElements.gameGui or playerGui:FindFirstChild("GameGui")
	gameGuiFrame = gameGui and gameGui:FindFirstChild("Frame")
	healthBar = uiElements.healthBar
	manaBar = uiElements.manaBar
	coins = uiElements.coins
	levelText = uiElements.levelText
	experienceBar = uiElements.experienceBar
	experienceText = uiElements.experienceText
	
	-- Get stat values
	if not getStatValues() then return end
	
	-- Reset health tracking with current value
	previousHealth = currentHealth.Value
	
	-- Update UI immediately with current values
	updateHealthBar(currentHealth.Value)
	updateManaBar(currentMana.Value)
	updateCoins(money.Value)
	updateLevel(level.Value)
	updateExperienceBar()
	
	-- Connect to changes
	connections.money = money.Changed:Connect(updateCoins)
	connections.currentHealth = currentHealth.Changed:Connect(updateHealthWithDamage)
	connections.maxHealth = maxHealth.Changed:Connect(updateHealthBar)
	connections.currentMana = currentMana.Changed:Connect(updateManaBar)
	connections.maxMana = maxMana.Changed:Connect(updateManaBar)
	connections.level = level.Changed:Connect(updateLevel)
	connections.experience = experience.Changed:Connect(onExperienceGained)
	connections.neededExperience = neededExperience.Changed:Connect(updateExperienceBar)
	
	-- Initialize last experience value for delta tracking
	lastExperienceValue = experience.Value
	
	-- Connect stat changes to StatsInfo updates
	local attack = stats:FindFirstChild("Attack")
	local defence = stats:FindFirstChild("Defence")
	local dexterity = stats:FindFirstChild("Dexterity")
	local statPoints = stats:FindFirstChild("StatPoints")
	
	if attack then
		connections.attack = attack.Changed:Connect(updateStatsInfoDisplay)
	end
	if defence then
		connections.defence = defence.Changed:Connect(updateStatsInfoDisplay)
	end
	if dexterity then
		connections.dexterity = dexterity.Changed:Connect(updateStatsInfoDisplay)
	end
	if statPoints then
		connections.statPoints = statPoints.Changed:Connect(updateStatsInfoDisplay)
	end
	
	-- Also connect health, mana changes to StatsInfo (for visual consistency)
	connections.healthStatsInfo = currentHealth.Changed:Connect(updateStatsInfoDisplay)
	connections.maxHealthStatsInfo = maxHealth.Changed:Connect(updateStatsInfoDisplay)
	connections.manaStatsInfo = currentMana.Changed:Connect(updateStatsInfoDisplay)
	connections.maxManaStatsInfo = maxMana.Changed:Connect(updateStatsInfoDisplay)
	
	-- Initial update of StatsInfo
	updateStatsInfoDisplay()
	
	-- Setup Character button to toggle StatsInfo
	if gameGuiFrame then
		local characterButton = gameGuiFrame:FindFirstChild("Character")
		local statsInfo = gameGuiFrame:FindFirstChild("StatsInfo")
		if characterButton and statsInfo then
			connections.characterButton = characterButton.MouseButton1Click:Connect(function()
				statsInfo.Visible = not statsInfo.Visible
				-- Update thumbstick visibility
				updateThumbstickVisibility()
			end)
		end
	end
	
	-- Setup Inventory button to toggle InventoryUI
	if gameGuiFrame then
		local inventoryButton = gameGuiFrame:FindFirstChild("Inventory")
		local inventoryUI = gameGuiFrame:FindFirstChild("InventoryUI")
		if inventoryButton and inventoryUI then
			connections.inventoryButton = inventoryButton.MouseButton1Click:Connect(function()
				inventoryUI.Visible = not inventoryUI.Visible
				-- Update thumbstick visibility
				updateThumbstickVisibility()
			end)
		end
	end
	
	-- Setup stat buttons (moved from main script body)
	if gameGuiFrame then
		local statsInfo = gameGuiFrame:FindFirstChild("StatsInfo")
		if statsInfo then
			local background = statsInfo:FindFirstChild("Background")
			if background then
				local buttons = background:FindFirstChild("Buttons")
				if buttons then
					local addHealth = buttons:FindFirstChild("AddHealth")
					local addMana = buttons:FindFirstChild("AddMana")
					local addAttack = buttons:FindFirstChild("AddAttack")
					local addDefence = buttons:FindFirstChild("AddDefence")
					local addDexterity = buttons:FindFirstChild("AddDexterity")
					local resetStats = buttons:FindFirstChild("ResetStats")
					
					if addHealth then
						connections.addHealth = addHealth.MouseButton1Click:Connect(function()
							sendStatAllocationRequest("MaxHealth")
						end)
					end
					
					if addMana then
						connections.addMana = addMana.MouseButton1Click:Connect(function()
							sendStatAllocationRequest("MaxMana")
						end)
					end
					
					if addAttack then
						connections.addAttack = addAttack.MouseButton1Click:Connect(function()
							sendStatAllocationRequest("Attack")
						end)
					end
					
					if addDefence then
						connections.addDefence = addDefence.MouseButton1Click:Connect(function()
							sendStatAllocationRequest("Defence")
						end)
					end
					
					if addDexterity then
						connections.addDexterity = addDexterity.MouseButton1Click:Connect(function()
							sendStatAllocationRequest("Dexterity")
						end)
					end
					
					if resetStats then
						connections.resetStats = resetStats.MouseButton1Click:Connect(function()
							local resetPoints = stats:FindFirstChild("ResetPoints")
							if resetPoints and resetPoints.Value <= 0 then
								-- Cannot reset: no reset points available

							else
								resetStatsRequest()
							end
						end)
					end
				else
					warn("[GameGui] Buttons folder not found in StatsInfo")
				end
			else
				warn("[GameGui] Background not found in StatsInfo")
			end
		else
			warn("[GameGui] StatsInfo not found in Frame")
		end
	else
		warn("[GameGui] GameGui not found in PlayerGui")
	end
end



-- ============ EVENT LISTENERS ============
-- Initial character setup
setupCharacter(player.Character or player.CharacterAdded:Wait())

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	setupCharacter(newCharacter)
end)

-- Listen for enemy damage events from server
local damageEvent = ReplicatedStorage:WaitForChild("EnemyDamage")
damageEvent.OnClientEvent:Connect(function(targetPart, damageAmount, isCritical, isFromPlayer)
	if targetPart then
		-- isFromPlayer: true = player damaged enemy (white), false = enemy damaged player (red)
		showDamageText(targetPart, damageAmount, isFromPlayer, isCritical)
	end
end)

-- Listen for weapon change event to update damage GUI
local weaponChangedEvent = ReplicatedStorage:WaitForChild("WeaponChangedEvent")
if weaponChangedEvent and weaponChangedEvent:IsA("BindableEvent") then
	weaponChangedEvent.Event:Connect(function()
		updateStatsInfoDisplay()
	end)
end

