local GameGui = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeaponData = require(ReplicatedStorage.Modules.WeaponData)


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- Disable the default Roblox leaderboard (PlayerList)
pcall(function()
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

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
local cachedBaseStats = {} -- Cache base stats locally to avoid fallback issues

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
	--print("[GameGui] Updating StatsInfo display...")
	task.wait(0.05)
	local statsInfo = gameGuiFrame:FindFirstChild("StatsInfo")
	if not statsInfo then return end
	local textsFolder = statsInfo:FindFirstChild("Background")
	if textsFolder then textsFolder = textsFolder:FindFirstChild("Texts") end
	local statsValueFolder = statsInfo:FindFirstChild("Background")
	if statsValueFolder then statsValueFolder = statsValueFolder:FindFirstChild("StatsValue") end
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
	local criticalChanceValue = statsValueFolder:FindFirstChild("CriticalChance")
	local criticalDamageValue = statsValueFolder:FindFirstChild("CriticalDamage")
	local statPointsValue = statsValueFolder:FindFirstChild("Stat Points")
	local dexterityValue = statsValueFolder:FindFirstChild("Dexterity")
	local defenseOutputValue = statsValueFolder:FindFirstChild("DefenseOutput")

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

	-- Show only base stats
	if healthText and maxHealthStat and currentHealthStat then healthText.Text = "Health:" end
	if healthValue and maxHealthStat and currentHealthStat then 
		healthValue.Text = tostring(currentHealthStat.Value) .. "/" .. tostring(maxHealthStat.Value) 
	end
	if manaText and maxManaStat and currentManaStat then manaText.Text = "Mana:" end
	if manaValue and maxManaStat and currentManaStat then 
		manaValue.Text = tostring(currentManaStat.Value) .. "/" .. tostring(maxManaStat.Value) 
	end
	if attackText and attackStat then attackText.Text = "Attack:" end
	if attackValue and attackStat then 
		attackValue.Text = tostring(attackStat.Value)
	end
	if defenceText and defenceStat then defenceText.Text = "Defence:" end
	if defenceValue and defenceStat then 
		defenceValue.Text = tostring(defenceStat.Value)
	end
	if dexterityText and dexterityStat then dexterityText.Text = "Dexterity:" end
	if dexterityValue and dexterityStat then 
		dexterityValue.Text = tostring(dexterityStat.Value)
	end
	if statPointsText and statPointsStat then statPointsText.Text = "Stat Points:" end
	if statPointsValue and statPointsStat then statPointsValue.Text = tostring(statPointsStat.Value) end

	-- Calculate and display Defense Output (matches server logic)
	if defenseOutputValue and attackStat and defenceStat then
		-- Calculate equipped armor defense (client-side, same as server)
		local function getArmorDef(slotName)
			local slot = stats:FindFirstChild(slotName)
			if slot and slot:IsA("Folder") then
				local nameValue = slot:FindFirstChild("name")
				local armorName = nameValue and nameValue.Value or ""
				local ArmorData = require(game:GetService("ReplicatedStorage").Modules.ArmorData)
				if armorName ~= "" and ArmorData[armorName] and ArmorData[armorName].Defense then
					return ArmorData[armorName].Defense
				end
			end
			return 0
		end
		local armorDefense = getArmorDef("EquippedHelmet") + getArmorDef("EquippedSuit") + getArmorDef("EquippedLegs") + getArmorDef("EquippedShoes")
		local defence = defenceStat.Value or 0
		-- Defense Output = sqrt(Defence + ArmorDefence) - defense works on its own, armor adds to it
		local totalDefense = defence + armorDefense
		local defenseOutput = math.floor(math.sqrt(totalDefense))
		defenseOutputValue.Text = formatNumberWithCommas(defenseOutput)
	end

	       -- Calculate orb multipliers (client-side, for display only)
	       local attackMult, defenceMult = 1, 1
	       local critChanceMult, critDamageMult = 1, 1
	       local equippedOrb = stats:FindFirstChild("EquippedOrb")
	       local orbMultiplierLabel = statsInfo:FindFirstChild("OrbBonus")
	       if equippedOrb and equippedOrb:IsA("Folder") then
		       local orbNameValue = equippedOrb:FindFirstChild("name")
		       local orbName = orbNameValue and orbNameValue.Value or ""
		       if orbName ~= "" then
			       local OrbData = require(game:GetService("ReplicatedStorage").Modules.OrbData)
			       local orbData = OrbData.GetOrbData(orbName)
			       if orbData and orbData.stats then
				       attackMult = orbData.stats.Attack or 1
				       defenceMult = orbData.stats.Defence or 1
				       critChanceMult = orbData.stats.CriticalChance or 1
				       critDamageMult = orbData.stats.CriticalDamage or 1
			       end
		       end
	       end

		       -- Calculate and display deterministic damage and crit chance (client-side, for display only)
		       if damageValue or criticalChanceValue or criticalDamageValue then
			       -- Find equipped PRIMARY weapon (Tool in character)
			       local equippedWeaponName = nil
			       if character then
				       for _, child in ipairs(character:GetChildren()) do
					       if child:IsA("Tool") then
						       equippedWeaponName = child.Name
						       break
					       end
				       end
			       end
			       
			       -- Calculate PRIMARY weapon damage
			       local weaponStats = equippedWeaponName and WeaponData.GetWeaponStats(equippedWeaponName) or nil
			       local weaponDamage = weaponStats and weaponStats.damage or 0
			       local baseAttack = attackStat and attackStat.Value or 1
			       local dexterity = dexterityStat and dexterityStat.Value or 0
			       -- Apply orb multipliers
			       local effectiveAttack = math.floor(baseAttack * attackMult)
			       -- Damage formula: Weapon Damage × (1 + effectiveAttack/100)
			       local baseDamage = math.floor(weaponDamage * (1 + (effectiveAttack / 100)))
			       
			       -- Check for SECONDARY weapon and calculate its damage
			       local secondaryBaseDamage = 0
			       local hasSecondary = false
			       local secondaryEquipped = stats:FindFirstChild("SecondaryEquipped")
			       if secondaryEquipped and secondaryEquipped:IsA("Folder") then
				       local secondaryName = secondaryEquipped:FindFirstChild("name")
				       if secondaryName and secondaryName.Value ~= "" then
					       hasSecondary = true
					       local secondaryWeaponStats = WeaponData.GetWeaponStats(secondaryName.Value)
					       local secondaryWeaponDamage = secondaryWeaponStats and secondaryWeaponStats.damage or 0
					       secondaryBaseDamage = math.floor(secondaryWeaponDamage * (1 + (effectiveAttack / 100)))
				       end
			       end
			       
			       -- Crit chance: (dexterity / 3) * critChanceMult
			       local critChance = (dexterity / 3) * critChanceMult
			       if critChance > 100 then critChance = 100 end
			       -- Crit multiplier from stat (default 50% = 1.5x), then apply orb crit damage multiplier
			       local critDmgStat = stats:FindFirstChild("CriticalDamage")
			       local critMult = 1.5
			       if critDmgStat and critDmgStat.Value then
				       critMult = 1 + (critDmgStat.Value / 100)
			       end
			       critMult = critMult * critDamageMult
			       local critDamage = math.floor(baseDamage * critMult)
			       
			       -- Display damage (Primary or Primary - Secondary)
			       if damageValue then
				       if hasSecondary then
					       damageValue.Text = formatNumberWithCommas(baseDamage) .. " - " .. formatNumberWithCommas(secondaryBaseDamage + baseDamage)
				       else
					       damageValue.Text = formatNumberWithCommas(baseDamage)
				       end
			       end
			       if criticalChanceValue then
				       criticalChanceValue.Text = string.format("%.1f%%", critChance)
			       end
			       if criticalDamageValue then
				       criticalDamageValue.Text = string.format("+ %s%%", formatNumberWithCommas(math.floor((critMult-1)*100)))
			       end
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
		while true do
			stats = player:FindFirstChild("Stats")
			if stats then break end
			player.ChildAdded:Wait()
		end
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

-- ============ CHARACTER SETUP ============
local function setupCharacter(newCharacter)
	-- Cleanup old connections
	disconnectAll()

	-- Always hide default Roblox health bar on character spawn
	pcall(function()
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

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
	
	-- Wait for orb to be equipped before first stats display
	-- This ensures orb multipliers are available when UI first renders
	--print("[GameGui] Waiting for orb to be equipped before first stats display...")
	local orbEquipWaitStart = tick()
	while true do
		local isOrbEquipped = false
		local success = pcall(function()
			local isOrbEquippedFunction = ReplicatedStorage:FindFirstChild("IsOrbEquippedFunction")
			if not isOrbEquippedFunction then
				isOrbEquippedFunction = Instance.new("RemoteFunction")
				isOrbEquippedFunction.Name = "IsOrbEquippedFunction"
				isOrbEquippedFunction.Parent = ReplicatedStorage
			end
			isOrbEquipped = isOrbEquippedFunction:InvokeServer()
		end)
		
		if success and isOrbEquipped then
			--print("[GameGui] ✓ Orb equipped, proceeding with stats display")
			break
		end
		
		-- Timeout after 5 seconds
		if tick() - orbEquipWaitStart > 5 then
			--print("[GameGui] Timeout waiting for orb (5s), proceeding anyway")
			break
		end
		
		task.wait(0.1)
	end
	
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


	-- Helper to connect both name and id changes for a folder
	local function connectFolderChanges(folderName, connKeyPrefix)
		local folder = stats:FindFirstChild(folderName)
		if folder and folder:IsA("Folder") then
			local nameValue = folder:FindFirstChild("name")
			local idValue = folder:FindFirstChild("id")
			if nameValue then
				connections[connKeyPrefix .. "Name"] = nameValue.Changed:Connect(function()
					--print("[GameGui] " .. folderName .. " name changed - updating UI")
					task.wait(1.2)
					updateStatsInfoDisplay()
				end)
			end
			if idValue then
				connections[connKeyPrefix .. "Id"] = idValue.Changed:Connect(function()
					--print("[GameGui] " .. folderName .. " id changed - updating UI")
					task.wait(1.2)
					updateStatsInfoDisplay()
				end)
			end
		end
	end

	-- Listen for changes to equipped weapon, orb, and all armor slots
	connectFolderChanges("Equipped", "equippedWeapon")
	connectFolderChanges("SecondaryEquipped", "equippedSecondaryWeapon")
	connectFolderChanges("EquippedOrb", "equippedOrb")
	connectFolderChanges("EquippedHelmet", "equippedHelmet")
	connectFolderChanges("EquippedSuit", "equippedSuit")
	connectFolderChanges("EquippedLegs", "equippedLegs")

	-- Also connect health, mana changes to StatsInfo (for visual consistency)
	connections.healthStatsInfo = currentHealth.Changed:Connect(updateStatsInfoDisplay)
	connections.maxHealthStatsInfo = maxHealth.Changed:Connect(updateStatsInfoDisplay)
	connections.manaStatsInfo = currentMana.Changed:Connect(updateStatsInfoDisplay)
	connections.maxManaStatsInfo = maxMana.Changed:Connect(updateStatsInfoDisplay)

	-- Listen for server signal to refresh stats UI (fired after stat allocation/reset)
	local refreshStatsUIEvent = ReplicatedStorage:FindFirstChild("RefreshStatsUI")
	if refreshStatsUIEvent then
		connections.refreshStatsUI = refreshStatsUIEvent.OnClientEvent:Connect(function()
			--print("[GameGui] Received RefreshStatsUI signal from server")
			updateStatsInfoDisplay()
		end)
	end
	
	-- Initial update of StatsInfo (with fresh base stats from server)
	--print("[GameGui] Initial update of StatsInfo for player " .. player.Name)
	updateStatsInfoDisplay()
	
	-- Setup Character button to toggle StatsInfo
	if gameGuiFrame then
		local characterButton = gameGuiFrame:FindFirstChild("Character")
		local statsInfo = gameGuiFrame:FindFirstChild("StatsInfo")
		if characterButton and statsInfo then
			connections.characterButton = characterButton.MouseButton1Click:Connect(function()
				statsInfo.Visible = not statsInfo.Visible
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
					
					   -- Use a stricter debounce and disable the button during debounce to prevent double-fire
					   local statDebounce = false
					   local function setupStatButton(button, statType)
						   if button then
							   button.MouseButton1Click:Connect(function()
								   if not statDebounce and button.Active ~= false then
									   statDebounce = true
									   button.Active = false
									   sendStatAllocationRequest(statType)
									   task.delay(0.25, function()
										   statDebounce = false
										   button.Active = true
									   end)
								   end
							   end)
						   end
					   end
					   setupStatButton(addHealth, "MaxHealth")
					   setupStatButton(addMana, "MaxMana")
					   setupStatButton(addAttack, "Attack")
					   setupStatButton(addDefence, "Defence")
					   setupStatButton(addDexterity, "Dexterity")
					
					if resetStats then
						-- Update reset button text with reset points count
						local function updateResetButtonText()
							local resetPoints = stats:FindFirstChild("ResetPoints")
							local resetText = resetStats:FindFirstChild("Text")
							if resetText and resetPoints then
								resetText.Text = "Reset (" .. tostring(resetPoints.Value) .. ")"
							end
						end
						
						-- Initial update
						updateResetButtonText()
						
						-- Connect to ResetPoints changes
						local resetPoints = stats:FindFirstChild("ResetPoints")
						if resetPoints then
							connections.resetPointsText = resetPoints.Changed:Connect(updateResetButtonText)
						end
						
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

if character then
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			updateStatsInfoDisplay()
		elseif child:IsA("Accessory") then
			-- Listen for orb accessory changes
			updateStatsInfoDisplay()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			updateStatsInfoDisplay()
		elseif child:IsA("Accessory") then
			-- Listen for orb accessory changes
			updateStatsInfoDisplay()
		end
	end)
end

-- ============ WORLD CHAT LISTENER ============
-- Configuration for world chat stacking
local WORLD_CHAT_DURATION = 8
local WORLD_CHAT_MAX_MESSAGES = 5
local WORLD_CHAT_BASE_Y = 0.02
local WORLD_CHAT_STACK_OFFSET = 0.12

-- Function to reposition all world chat messages
local function repositionWorldChats()
	if not gameGui then return end
	local frame = gameGui:FindFirstChild("Frame")
	if not frame then return end
	
	local worldChats = {}
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") and child.Name:match("^WorldChat") then
			table.insert(worldChats, child)
		end
	end
	
	-- Sort by creation time (oldest first)
	table.sort(worldChats, function(a, b)
		local aNum = tonumber(a.Name:match("%d+")) or 0
		local bNum = tonumber(b.Name:match("%d+")) or 0
		return aNum < bNum
	end)
	
	-- Reposition from bottom to top
	for index, chat in ipairs(worldChats) do
		local yPos = WORLD_CHAT_BASE_Y + ((index - 1) * WORLD_CHAT_STACK_OFFSET)
		chat.Position = UDim2.new(0.3, 0, yPos, 0)
	end
end

-- Listen for cross-server admin world chat
local worldChatEvent = ReplicatedStorage:WaitForChild("WorldChatEvent", 10)
if worldChatEvent then
	local worldChatCounter = 0
	
	worldChatEvent.OnClientEvent:Connect(function(playerName, message)
		if not gameGui then return end
		local frame = gameGui:FindFirstChild("Frame")
		if not frame then return end
		
		-- Count existing world chats
		local existingChats = {}
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("TextLabel") and child.Name:match("^WorldChat") then
				table.insert(existingChats, child)
			end
		end
		
		-- Remove oldest if we hit max
		if #existingChats >= WORLD_CHAT_MAX_MESSAGES then
			table.sort(existingChats, function(a, b)
				local aNum = tonumber(a.Name:match("%d+")) or 0
				local bNum = tonumber(b.Name:match("%d+")) or 0
				return aNum < bNum
			end)
			existingChats[1]:Destroy()
		end
		
		-- Create new WorldChat label
		worldChatCounter = worldChatCounter + 1
		local worldChat = Instance.new("TextLabel")
		worldChat.Name = "WorldChat" .. worldChatCounter
		worldChat.Size = UDim2.new(0.4, 0, 0.1, 0)
		worldChat.Position = UDim2.new(0.3, 0, WORLD_CHAT_BASE_Y, 0)
		worldChat.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		worldChat.BackgroundTransparency = 0.3
		worldChat.BorderSizePixel = 0
		worldChat.Font = Enum.Font.GothamBold
		worldChat.TextSize = 20
		worldChat.TextColor3 = Color3.fromRGB(255, 215, 0)
		worldChat.TextWrapped = true
		worldChat.TextXAlignment = Enum.TextXAlignment.Center
		worldChat.TextYAlignment = Enum.TextYAlignment.Center
		worldChat.Text = "📢 " .. playerName .. ": " .. message
		worldChat.Parent = frame
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = worldChat
		
		-- Reposition all messages
		repositionWorldChats()
		
		-- Auto-remove after duration
		task.delay(WORLD_CHAT_DURATION, function()
			if worldChat and worldChat.Parent then
				worldChat:Destroy()
				repositionWorldChats()
			end
		end)
	end)
end

return GameGui
