-- ManaManager.lua
-- Handles mana consumption and regeneration
-- Used for running, skills, and other mana-dependent features

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ManaManager = {}

-- Track running state for each player
local playerRunningState = {}
-- Track mana drain connections
local playerManaConnections = {}
-- Track accumulated mana drain per player (for handling IntValue precision)
local accumulatedManaDrain = {}
-- Mana settings
local MANA_DRAIN_PER_SECOND_RUNNING = 1
local MANA_REGEN_PER_SECOND = 0.5

-- Get mana values for a player
local function getManaValues(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil, nil end
	
	local currentMana = stats:FindFirstChild("CurrentMana")
	local maxMana = stats:FindFirstChild("MaxMana")
	
	if not currentMana or not maxMana then return nil, nil end
	
	return currentMana, maxMana
end

-- Start mana drain loop for a player
local function startManaDrainLoop(player)
	-- Stop existing loop if any
	if playerManaConnections[player.UserId] then
		playerManaConnections[player.UserId]:Disconnect()
	end
	
	local lastLogTime = {} -- Track last time we logged to avoid spam
	
	local connection = RunService.Heartbeat:Connect(function()
		-- Check if player still exists
		if not player or not player.Parent then
			if playerManaConnections[player.UserId] then
				playerManaConnections[player.UserId]:Disconnect()
				playerManaConnections[player.UserId] = nil
			end
			playerRunningState[player.UserId] = nil
			return
		end
		
		local character = player.Character
		if not character then return end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		local currentMana, maxMana = getManaValues(player)
		if not currentMana or not maxMana then return end
		
		local isRunning = playerRunningState[player.UserId] or false
		
		-- Drain mana if running
		if isRunning and humanoid.Health > 0 then
			-- Accumulate mana drain
			accumulatedManaDrain[player.UserId] = (accumulatedManaDrain[player.UserId] or 0) + (MANA_DRAIN_PER_SECOND_RUNNING / 60)
			
			-- When accumulated drain reaches 1, apply it to mana
			if accumulatedManaDrain[player.UserId] >= 1 then
				local drainToApply = math.floor(accumulatedManaDrain[player.UserId])
				accumulatedManaDrain[player.UserId] = accumulatedManaDrain[player.UserId] - drainToApply
				
				local oldMana = currentMana.Value
				currentMana.Value = math.max(0, currentMana.Value - drainToApply)
			end
		else
			-- Regenerate mana when not running (but not over max)
			accumulatedManaDrain[player.UserId] = (accumulatedManaDrain[player.UserId] or 0) - (MANA_REGEN_PER_SECOND / 60)
			
			-- When accumulated regen reaches 1, apply it to mana
			if accumulatedManaDrain[player.UserId] <= -1 then
				local regenToApply = math.floor(math.abs(accumulatedManaDrain[player.UserId]))
				accumulatedManaDrain[player.UserId] = accumulatedManaDrain[player.UserId] + regenToApply
				
				local oldMana = currentMana.Value
				currentMana.Value = math.min(maxMana.Value, currentMana.Value + regenToApply)
			end
		end
	end)
	
	playerManaConnections[player.UserId] = connection
end

-- Set running state for a player
function ManaManager.SetRunning(player, isRunning)
	if not player then return end
	local previousState = playerRunningState[player.UserId] or false
	if previousState ~= isRunning then
		playerRunningState[player.UserId] = isRunning
	else
		-- Log when we try to set the same state (for debugging)
	end
end

-- Check if player is running
function ManaManager.IsRunning(player)
	return playerRunningState[player.UserId] or false
end

-- Consume mana (for skills, special attacks, etc.)
-- Returns true if mana was consumed, false if insufficient mana
function ManaManager.ConsumeMana(player, amount)
	if not player or amount <= 0 then return false end
	
	local currentMana, maxMana = getManaValues(player)
	if not currentMana then return false end
	
	if currentMana.Value >= amount then
		local oldMana = currentMana.Value
		currentMana.Value = currentMana.Value - amount
		print(string.format("[ManaManager] %s consumed mana: %.2f -> %.2f (spent %.2f)", 
			player.Name, oldMana, currentMana.Value, amount))
		return true
	end
	
	print(string.format("[ManaManager] %s INSUFFICIENT mana for ability! Required: %.2f, Current: %.2f", 
		player.Name, amount, currentMana.Value))
	return false
end

-- Restore mana (for potions, abilities, etc.)
function ManaManager.RestoreMana(player, amount)
	if not player or amount <= 0 then return end
	
	local currentMana, maxMana = getManaValues(player)
	if not currentMana or not maxMana then return end
	
	local oldMana = currentMana.Value
	currentMana.Value = math.min(maxMana.Value, currentMana.Value + amount)

end

-- Set mana drain rate (for different skills/effects)
function ManaManager.SetDrainRate(newRate)
	MANA_DRAIN_PER_SECOND_RUNNING = newRate
end

-- Get current mana drain rate
function ManaManager.GetDrainRate()
	return MANA_DRAIN_PER_SECOND_RUNNING
end

-- Initialize mana manager for a player
function ManaManager.InitializePlayer(player)
	if not player then return end
	
	playerRunningState[player.UserId] = false
	startManaDrainLoop(player)
end

-- Cleanup player data
function ManaManager.CleanupPlayer(player)
	if not player then return end
	
	local userId = player.UserId
	if playerManaConnections[userId] then
		playerManaConnections[userId]:Disconnect()
		playerManaConnections[userId] = nil
	end
	playerRunningState[userId] = nil
	accumulatedManaDrain[userId] = nil
end

-- Setup player on join
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		-- Wait for stats to be ready
		local stats = player:WaitForChild("Stats", 10)
		if stats then
			ManaManager.InitializePlayer(player)
		end
	end)
end)

-- Cleanup on player disconnect
Players.PlayerRemoving:Connect(function(player)
	ManaManager.CleanupPlayer(player)
end)

return ManaManager
