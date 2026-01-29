-- ArmorsManager.lua
-- Handles equipping, unequipping, and validation for armor items

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ArmorData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ArmorData"))
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

local ArmorsManager = {}

-- Helper: Set equipped armor slot (Suit, Helmet, Legs, Shoes)
function ArmorsManager.SetEquippedArmor(player, armorName, itemId)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local armorInfo = ArmorData[armorName]
	if not armorInfo then return end
	local slotName = "Equipped" .. armorInfo.Type -- e.g., EquippedHelmet, EquippedShoes
	local slotFolder = stats:FindFirstChild(slotName)
	if not slotFolder then return end
	local nameValue = slotFolder:FindFirstChild("name")
	local idValue = slotFolder:FindFirstChild("id")
	if nameValue then nameValue.Value = armorName end
	if idValue then idValue.Value = itemId end
	UnifiedDataStoreManager.SaveStats(player, false)
	-- Wait for character and required parts to exist before attaching armor accessory
	local maxWait, waited = 3, 0
	while (not player.Character or not player.Character:FindFirstChild("Humanoid")) and waited < maxWait do
		task.wait(0.1)
		waited = waited + 0.1
	end
	ArmorsManager.CloneAndAttachArmorAccessory(player, armorName, armorInfo.Type)
end

-- Reusable function for cloning and attaching armor accessories
function ArmorsManager.CloneAndAttachArmorAccessory(player, armorName, armorType)
	-- Remove all accessories from the character that match either the armor type or the armor name
	local character = player.Character
	if character then
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local isTypeMatch = acc:GetAttribute("ArmorAccessoryType") == armorType
				local isNameMatch = acc.Name == armorName
				if isTypeMatch or isNameMatch then
					acc:Destroy()
				end
			end
		end
	end
	-- Find the matching folder in ServerStorage/Armor Accessories
	local ServerStorage = game:GetService("ServerStorage")
	local armorAccessoriesFolder = ServerStorage:FindFirstChild("Armor Accessories")
	if not armorAccessoriesFolder then return end
	local armorFolder = armorAccessoriesFolder:FindFirstChild(armorName)
	if armorFolder then
		print("[ArmorsManager] Found matching armor accessory folder for '" .. armorName .. "'")
	else
		warn("[ArmorsManager] No matching armor accessory folder found for '" .. armorName .. "'")
		return
	end
	if not character then
		warn("[ArmorsManager] Cannot equip accessories: player.Character is nil for '" .. player.Name .. "'")
		return
	end
	   for _, accessory in ipairs(armorFolder:GetChildren()) do
		   if accessory:IsA("Accessory") then
			   local clone = accessory:Clone()
			   -- Set CanCollide = false for all descendants
			   for _, desc in ipairs(clone:GetDescendants()) do
				   if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("Part") then
					   desc.CanCollide = false
				   end
			   end
			   clone.Parent = character
			   clone:SetAttribute("ArmorAccessoryType", armorType)
		   end
	   end
end

-- Helper: Unequip armor slot (Suit, Helmet, Legs, Shoes)
function ArmorsManager.UnequipArmor(player, armorType)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local slotName = "Equipped" .. armorType -- e.g., EquippedHelmet, EquippedShoes
	local slotFolder = stats:FindFirstChild(slotName)
	if not slotFolder then return end
	local nameValue = slotFolder:FindFirstChild("name")
	local idValue = slotFolder:FindFirstChild("id")
	if nameValue then nameValue.Value = "" end
	if idValue then idValue.Value = "" end
	UnifiedDataStoreManager.SaveStats(player, false)
end

-- Helper: Get equipped armor info for a slot (Suit, Helmet, Legs, Shoes)
function ArmorsManager.GetEquippedArmor(player, armorType)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	local slotName = "Equipped" .. armorType
	local slotFolder = stats:FindFirstChild(slotName)
	if not slotFolder then return nil end
	local nameValue = slotFolder:FindFirstChild("name")
	local idValue = slotFolder:FindFirstChild("id")
	return {
		name = nameValue and nameValue.Value or "",
		id = idValue and idValue.Value or ""
	}
end

-- Auto-equip armor accessories on character spawn (rejoin/respawn)
local function autoEquipArmorAccessories(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	for _, armorType in ipairs({"Suit", "Helmet", "Legs", "Shoes"}) do
		local slotName = "Equipped" .. armorType
		local slotFolder = stats:FindFirstChild(slotName)
		if slotFolder then
			local nameValue = slotFolder:FindFirstChild("name")
			local armorName = nameValue and nameValue.Value or ""
			if armorName ~= "" then
				ArmorsManager.CloneAndAttachArmorAccessory(player, armorName, armorType)
			end
		end
	end
end

-- Handle already-connected players on server start
local Players = game:GetService("Players")

local function onCharacterAdded(player, character)
	task.spawn(function()
		local humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 3)
		if not humanoid then warn("[ArmorsManager] Humanoid not found for " .. player.Name) return end
		task.wait(0.3)
		autoEquipArmorAccessories(player)
	end)
end

-- Connect for all current and future players
local function setupPlayerConnections(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerConnections(player)
end
Players.PlayerAdded:Connect(setupPlayerConnections)
-- Unequip and remove armor accessory from character (Suit, Helmet, Legs, Shoes)
function ArmorsManager.UnequipAndRemoveAccessory(player, armorType)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local slotName = "Equipped" .. armorType
	local slotFolder = stats:FindFirstChild(slotName)
	if not slotFolder then return end
	local nameValue = slotFolder:FindFirstChild("name")
	local idValue = slotFolder:FindFirstChild("id")
	local armorName = nameValue and nameValue.Value or ""
	if nameValue then nameValue.Value = "" end
	if idValue then idValue.Value = "" end
	-- Remove accessory from character
	local character = player.Character
	if character and armorName ~= "" then
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") and (acc:GetAttribute("ArmorAccessoryType") == armorType or acc.Name == armorName) then
				acc:Destroy()
			end
		end
	end
	UnifiedDataStoreManager.SaveStats(player, false)
end

return ArmorsManager



