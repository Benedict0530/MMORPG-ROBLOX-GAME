-- PowerRatingUpdater.client.lua
-- Place under StarterPlayerScripts/ClientHandler/PowerRatingUpdater.client.lua
-- Updates the Power Rating (PR) label in GameGui/Frame/Power Rating based on player stats, weapons, armor, and accessories

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local WAIT_TIMEOUT = 5

-- Utility: Format number with commas
local function formatNumberWithCommas(num)
	local formatted = tostring(num)
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- Calculate Power Rating (PR)
local function calculatePowerRating(stats)
	if not stats then return 0 end
	local attack = stats:FindFirstChild("Attack")
	local defence = stats:FindFirstChild("Defence")
	local dexterity = stats:FindFirstChild("Dexterity")
	local maxHealth = stats:FindFirstChild("MaxHealth")
	local maxMana = stats:FindFirstChild("MaxMana")

	local pr = 0
	pr = pr + (attack and attack.Value or 0) * 2
	pr = pr + (defence and defence.Value or 0) * 2
	pr = pr + (dexterity and dexterity.Value or 0)
	pr = pr + (maxHealth and math.floor(maxHealth.Value / 10) or 0)
	pr = pr + (maxMana and math.floor(maxMana.Value / 20) or 0)

	-- Add equipped weapon stats
	local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				local weaponStats = WeaponData.GetWeaponStats(child.Name)
				if weaponStats and weaponStats.damage then
					pr = pr + weaponStats.damage * 3
				end
			end
		end
	end

	-- Add equipped armor stats
	local ArmorData = require(ReplicatedStorage.Modules.ArmorData)
	local function getArmorDef(slotName)
		local slot = stats:FindFirstChild(slotName)
		if slot and slot:IsA("Folder") then
			local nameValue = slot:FindFirstChild("name")
			local armorName = nameValue and nameValue.Value or ""
			if armorName ~= "" and ArmorData[armorName] and ArmorData[armorName].Defense then
				return ArmorData[armorName].Defense
			end
		end
		return 0
	end
	pr = pr + getArmorDef("EquippedHelmet")
	pr = pr + getArmorDef("EquippedSuit")
	pr = pr + getArmorDef("EquippedLegs")
	pr = pr + getArmorDef("EquippedShoes")

	-- Add orb stats (if any)
	local OrbData = require(ReplicatedStorage.Modules.OrbData)
	local equippedOrb = stats:FindFirstChild("EquippedOrb")
	if equippedOrb and equippedOrb:IsA("Folder") then
		local orbNameValue = equippedOrb:FindFirstChild("name")
		local orbName = orbNameValue and orbNameValue.Value or ""
		if orbName ~= "" then
			local orbData = OrbData.GetOrbData(orbName)
			if orbData and orbData.stats then
				pr = pr + math.floor((orbData.stats.Attack or 0) * 2)
				pr = pr + math.floor((orbData.stats.Defence or 0) * 2)
				pr = pr + math.floor((orbData.stats.CriticalChance or 0) * 1.5)
				pr = pr + math.floor((orbData.stats.CriticalDamage or 0) * 1.5)
			end
		end
	end

	return pr
end

-- Update the Power Rating label
local lastPR = nil
local lastShownPR = nil
local lastChangeTime = 0
local function showPRChangeText(prLabel, diff)
	if not prLabel then return end
	-- Only show if enough time has passed since last change
	local now = tick()
	if now - lastChangeTime < 0.5 then return end
	lastChangeTime = now
	-- Create a ScreenGui for floating text if not present
	local floatingGui = playerGui:FindFirstChild("PRFloatingGui")
	if not floatingGui then
		floatingGui = Instance.new("ScreenGui")
		floatingGui.Name = "PRFloatingGui"
		floatingGui.IgnoreGuiInset = true
		floatingGui.ResetOnSpawn = false
		floatingGui.Parent = playerGui
	end
	local changeText = Instance.new("TextLabel")
	changeText.Size = UDim2.new(0, prLabel.AbsoluteSize.X, 0, 38)
	changeText.Position = UDim2.new(0, prLabel.AbsolutePosition.X, 0, prLabel.AbsolutePosition.Y + prLabel.AbsoluteSize.Y + 2)
	changeText.AnchorPoint = Vector2.new(0, 0)
	changeText.BackgroundTransparency = 1
	changeText.TextColor3 = diff > 0 and Color3.fromRGB(60, 220, 60) or Color3.fromRGB(220, 60, 60)
	changeText.TextStrokeTransparency = 0.15
	changeText.Font = Enum.Font.FredokaOne
	changeText.TextSize = 32
	changeText.Text = (diff > 0 and "+" or "") .. tostring(diff)
	changeText.ZIndex = 999
	changeText.Parent = floatingGui
	-- Animate fade out and slight downward movement
	task.spawn(function()
		for i = 0, 1, 0.07 do
			changeText.TextTransparency = i
			changeText.TextStrokeTransparency = 0.15 + i * 0.85
			changeText.Position = UDim2.new(0, prLabel.AbsolutePosition.X, 0, prLabel.AbsolutePosition.Y + prLabel.AbsoluteSize.Y + 2 + i * 16)
			task.wait(0.03)
		end
		changeText:Destroy()
	end)
end

local function animatePRLabel(prLabel, fromValue, toValue)
	if not prLabel then return end
	local duration = 1.0 -- Slower animation for better visibility
	local steps = 30
	local stepTime = duration / steps
	for i = 1, steps do
		local t = i / steps
		local current = math.floor(fromValue + (toValue - fromValue) * t)
		prLabel.Text = "Power Rating: " .. formatNumberWithCommas(current)
		task.wait(stepTime)
	end
	prLabel.Text = "Power Rating: " .. formatNumberWithCommas(toValue)
end


local function updatePowerRating(forceNoAnim)
	local gui = playerGui:FindFirstChild("GameGui")
	if not gui then return end
	local frame = gui:FindFirstChild("Frame")
	if not frame then return end
	local prLabel = frame:FindFirstChild("Power Rating")
	if not prLabel or not prLabel:IsA("TextLabel") then return end
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local pr = calculatePowerRating(stats)
	-- Only animate and show text if this is a real, user-driven change (not Heartbeat)
	if not forceNoAnim and lastPR ~= nil and pr ~= lastPR then
		showPRChangeText(prLabel, pr - lastPR)
		animatePRLabel(prLabel, lastPR, pr)
	else
		prLabel.Text = "Power Rating: " .. formatNumberWithCommas(pr)
	end
	lastPR = pr
end



-- Heartbeat: Only update the label (no animation/text)
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
	local gui = playerGui:FindFirstChild("GameGui")
	if not gui then return end
	local frame = gui:FindFirstChild("Frame")
	if not frame then return end
	local prLabel = frame:FindFirstChild("Power Rating")
	if not prLabel or not prLabel:IsA("TextLabel") then return end
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local pr = calculatePowerRating(stats)
	prLabel.Text = "Power Rating: " .. formatNumberWithCommas(pr)
end)

-- Initial setup
updatePowerRating()

return true
