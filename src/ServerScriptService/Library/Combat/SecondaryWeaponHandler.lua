local SecondaryWeaponHandler = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local WeaponData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponData"))
local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))

-- Initialize the handler
function SecondaryWeaponHandler:Initialize()
	--print("[SecondaryWeaponHandler] Initializing...")
	
	-- Function to equip secondary weapon accessory (visual only, no stat update)
	local function equipSecondaryAccessory(player)
		local stats = player:FindFirstChild("Stats")
		if not stats then return end
		
		local secondaryEquippedFolder = stats:FindFirstChild("SecondaryEquipped")
		if not secondaryEquippedFolder then return end
		
		local nameValue = secondaryEquippedFolder:FindFirstChild("name")
		local idValue = secondaryEquippedFolder:FindFirstChild("id")
		
		if not nameValue or not idValue or nameValue.Value == "" then
			return
		end
		
		local weaponName = nameValue.Value
		local weaponId = idValue.Value
		
		local character = player.Character
		if not character then return end
		
		-- Remove any existing secondary weapon accessory
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") and child:GetAttribute("IsSecondaryWeapon") then
				child:Destroy()
			end
		end
		
		-- Find the weapon accessory in ReplicatedStorage/SecondWeapon
		local secondWeaponFolder = ReplicatedStorage:FindFirstChild("SecondWeapon")
		if secondWeaponFolder then
			local weaponAccessory = secondWeaponFolder:FindFirstChild(weaponName)
			if weaponAccessory and weaponAccessory:IsA("Accessory") then
				local clone = weaponAccessory:Clone()
				clone:SetAttribute("IsSecondaryWeapon", true)
				clone:SetAttribute("_ItemId", weaponId)
				clone.Parent = character
				--print("[SecondaryWeaponHandler] Re-equipped secondary weapon accessory:", weaponName, "for", player.Name)
			else
				warn("[SecondaryWeaponHandler] Secondary weapon accessory not found:", weaponName)
			end
		else
			warn("[SecondaryWeaponHandler] SecondWeapon folder not found in ReplicatedStorage")
		end
	end
	
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		-- Wait for stats to load
		task.spawn(function()
			local stats = player:WaitForChild("Stats", 10)
			if stats and player.Character then
				equipSecondaryAccessory(player)
			end
		end)
		
		-- Handle respawns
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5) -- Wait for character to fully load
			equipSecondaryAccessory(player)
		end)
	end
	
	-- Handle new players
	Players.PlayerAdded:Connect(function(player)
		-- Wait for stats to load
		task.spawn(function()
			local stats = player:WaitForChild("Stats", 10)
			if stats and player.Character then
				equipSecondaryAccessory(player)
			end
		end)
		
		-- Handle respawns
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5) -- Wait for character to fully load
			equipSecondaryAccessory(player)
		end)
	end)
	
	--print("[SecondaryWeaponHandler] Initialized successfully")
end

-- Equip secondary weapon (updates SecondaryEquipped stat only)
function SecondaryWeaponHandler:EquipSecondaryWeapon(player, weaponName, weaponId)
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[SecondaryWeaponHandler] No Stats folder found for", player.Name)
		return false
	end
	
	local secondaryEquippedFolder = stats:FindFirstChild("SecondaryEquipped")
	if not secondaryEquippedFolder then
		warn("[SecondaryWeaponHandler] No SecondaryEquipped folder found for", player.Name)
		return false
	end
	
	-- Update the SecondaryEquipped stat
	local nameValue = secondaryEquippedFolder:FindFirstChild("name")
	local idValue = secondaryEquippedFolder:FindFirstChild("id")
	
	if nameValue then nameValue.Value = weaponName end
	if idValue then idValue.Value = weaponId end
	
	--print("[SecondaryWeaponHandler] Equipped secondary weapon:", weaponName, "(id:", weaponId, ") for", player.Name)
	
	-- Find and equip the secondary weapon accessory
	local character = player.Character
	if character then
		-- Remove any existing secondary weapon accessory
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") and child:GetAttribute("IsSecondaryWeapon") then
				child:Destroy()
			end
		end
		
		-- Find the weapon accessory in ReplicatedStorage/SecondWeapon
		local secondWeaponFolder = ReplicatedStorage:FindFirstChild("SecondWeapon")
		if secondWeaponFolder then
			local weaponAccessory = secondWeaponFolder:FindFirstChild(weaponName)
			if weaponAccessory and weaponAccessory:IsA("Accessory") then
				local clone = weaponAccessory:Clone()
				clone:SetAttribute("IsSecondaryWeapon", true)
				clone:SetAttribute("_ItemId", weaponId)
				clone.Parent = character
				--print("[SecondaryWeaponHandler] Equipped secondary weapon accessory:", weaponName, "for", player.Name)
			else
				warn("[SecondaryWeaponHandler] Secondary weapon accessory not found:", weaponName)
			end
		else
			warn("[SecondaryWeaponHandler] SecondWeapon folder not found in ReplicatedStorage")
		end
	end
	
	-- Save to DataStore
	UnifiedDataStoreManager.SaveStats(player, false)
	
	-- Fire event to update UI
	local equippedChangedEvent = ReplicatedStorage:FindFirstChild("EquippedChanged")
	if equippedChangedEvent then
		equippedChangedEvent:FireClient(player)
	end
	
	return true
end

-- Unequip secondary weapon
function SecondaryWeaponHandler:UnequipSecondaryWeapon(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("[SecondaryWeaponHandler] No Stats folder found for", player.Name)
		return false
	end
	
	local secondaryEquippedFolder = stats:FindFirstChild("SecondaryEquipped")
	if not secondaryEquippedFolder then
		warn("[SecondaryWeaponHandler] No SecondaryEquipped folder found for", player.Name)
		return false
	end
	
	-- Clear the SecondaryEquipped stat
	local nameValue = secondaryEquippedFolder:FindFirstChild("name")
	local idValue = secondaryEquippedFolder:FindFirstChild("id")
	
	if nameValue then nameValue.Value = "" end
	if idValue then idValue.Value = "" end
	
	--print("[SecondaryWeaponHandler] Unequipped secondary weapon for", player.Name)
	
	-- Remove secondary weapon accessory from character
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") and child:GetAttribute("IsSecondaryWeapon") then
				child:Destroy()
				--print("[SecondaryWeaponHandler] Removed secondary weapon accessory from", player.Name)
			end
		end
	end
	
	-- Save to DataStore (will be saved on next save cycle or on player leave)
	UnifiedDataStoreManager.SaveStats(player, false)
	
	-- Fire event to update UI
	local equippedChangedEvent = ReplicatedStorage:FindFirstChild("EquippedChanged")
	if equippedChangedEvent then
		equippedChangedEvent:FireClient(player)
	end
	
	return true
end

-- Get secondary weapon stats
function SecondaryWeaponHandler:GetSecondaryWeaponStats(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil end
	
	local secondaryEquippedFolder = stats:FindFirstChild("SecondaryEquipped")
	if not secondaryEquippedFolder then return nil end
	
	local nameValue = secondaryEquippedFolder:FindFirstChild("name")
	local idValue = secondaryEquippedFolder:FindFirstChild("id")
	
	if not nameValue or not idValue or nameValue.Value == "" then
		return nil
	end
	
	return {
		name = nameValue.Value,
		id = idValue.Value
	}
end

return SecondaryWeaponHandler
