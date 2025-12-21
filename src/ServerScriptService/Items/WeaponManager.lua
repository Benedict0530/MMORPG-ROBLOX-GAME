-- WeaponManager.lua
-- Handles weapon/tool usage: animations, sounds, effects


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WeaponData = require(ReplicatedStorage.Modules.WeaponData)
local WeaponDataStore = require(script.Parent.WeaponDataStore)
local EnemyStatsDataStore = require(script.Parent.Parent.Enemies.EnemyStatsDataStore)

-- Create RemoteEvent for showing enemy damage text on clients
local damageEvent = ReplicatedStorage:FindFirstChild("EnemyDamage")
if not damageEvent then
	damageEvent = Instance.new("RemoteEvent")
	damageEvent.Name = "EnemyDamage"
	damageEvent.Parent = ReplicatedStorage
end



local lastAttackTimes = {} -- keys are player instances
local WeaponManager = {}

-- Helper: Get or create Health IntValue for enemy
local function getOrCreateEnemyHealth(enemyModel, enemyStats)
	local enemyHealth = enemyModel:FindFirstChild("Health")
	if not enemyHealth then
		enemyHealth = Instance.new("IntValue")
		enemyHealth.Name = "Health"
		enemyHealth.Value = enemyStats and enemyStats.Health or 1
		enemyHealth.Parent = enemyModel
	end
	return enemyHealth
end



-- Modular attack logic for each weapon
function WeaponManager.PerformAttack(player, tool)
	if not player or not tool or not tool.Name then return end
	-- Server-side validation: ensure player owns and has equipped the tool
	local character = player.Character
	if not character then
		warn("[WeaponManager] Player " .. player.Name .. " has no character.")
		return
	end
	local backpack = player:FindFirstChild("Backpack") or player.Backpack
	if tool.Parent ~= character and tool.Parent ~= backpack then
		warn("[WeaponManager] Player " .. player.Name .. " does not own tool " .. tool.Name)
		return
	end
	if tool.Parent ~= character then
		warn("[WeaponManager] Player " .. player.Name .. " is not holding tool " .. tool.Name)
		return
	end

	-- Passed validation, perform attack
	local weaponName = tool.Name
	local weaponStats = WeaponData.GetWeaponStats(weaponName)
	local damage = weaponStats and weaponStats.damage or 1
	local speed = weaponStats and weaponStats.speed or 1
	local now = tick()
	local lastAttack = lastAttackTimes[player] or 0
	if (now - lastAttack) < (speed) then
		warn("[WeaponManager] " .. player.Name .. " tried to attack too quickly with " .. weaponName)
		return
	end
	lastAttackTimes[player] = now

	local hitPart = tool:FindFirstChild("HitPart")
	if not hitPart then
		warn("[WeaponManager] Tool " .. tool.Name .. " has no HitPart child.")
		return
	end

	local hitEnemies = {}
	local function onTouched(hit)
		-- Ignore if hit is a player character
		local hitParent = hit.Parent
		if hitParent and Players:GetPlayerFromCharacter(hitParent) then
			return
		end
		local enemyModel = hit:FindFirstAncestorOfClass("Model")
		-- Only process if NOT a player character
		if enemyModel and enemyModel:FindFirstChild("Humanoid") and not hitEnemies[enemyModel] then
			if Players:GetPlayerFromCharacter(enemyModel) then
				return -- skip player models
			end
			hitEnemies[enemyModel] = true
			local enemyName = enemyModel.Name
			local enemyStats = EnemyStatsDataStore.loadEnemyStats(enemyName)
			local enemyHealth = getOrCreateEnemyHealth(enemyModel, enemyStats)
			if not enemyHealth:IsA("IntValue") then
				warn("[WeaponManager] Enemy Health is not IntValue for model " .. enemyName)
				return
			end
			local oldHealth = enemyHealth.Value
			enemyHealth.Value = math.max(oldHealth - damage, 0)
			-- Show damage text on all clients
			damageEvent:FireAllClients(enemyModel, damage)
			print(string.format("[WeaponManager] %s hit enemy '%s' for %d damage. HP: %d/%d", player.Name, enemyName, damage, enemyHealth.Value, enemyStats and enemyStats.Health or 1))
			if enemyHealth.Value <= 0 then
				print(string.format("[WeaponManager] Enemy '%s' defeated by %s", enemyName, player.Name))
				local humanoid = enemyModel:FindFirstChild("Humanoid")
				if humanoid then humanoid.Health = 0 end
			end
		end
	end

	local touchedConn = hitPart.Touched:Connect(onTouched)
	task.delay(0.3, function()
		if touchedConn then touchedConn:Disconnect() end
	end)
end

-- Connect weapon/tool usage to effects and logic
function WeaponManager.ConnectTool(tool)
	if not tool or not tool.Name then return end
	local swingEvent = tool:FindFirstChild("SwingEvent")
	if swingEvent then
		swingEvent.OnServerEvent:Connect(function(player)
			WeaponManager.PerformAttack(player, tool)
		end)
	else
		print("[WeaponManager] Tool '" .. tool.Name .. "' does not have a SwingEvent.")
	end
end

-- Utility: Connect all tools in ReplicatedStorage.Weapons
function WeaponManager.ConnectAllWeapons()
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if weaponsFolder then
		for _, tool in ipairs(weaponsFolder:GetChildren()) do
			WeaponManager.ConnectTool(tool)
		end
	end
end


return WeaponManager
