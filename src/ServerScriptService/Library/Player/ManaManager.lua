-- ManaManager.lua
-- Handles mana consumption and regeneration
-- Used for running, skills, and other mana-dependent features

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ManaManager = {}

-- Track running state for each player (legacy, not used for regen logic)
local playerRunningState = {}
-- Track mana drain connections
local playerManaConnections = {}
-- Track accumulated mana drain per player (for handling IntValue precision)
local accumulatedManaDrain = {}
-- Track last time mana decreased for each player
local lastManaDecreaseTime = {}
-- Mana settings
local MANA_DRAIN_PER_SECOND_RUNNING = 1
local MANA_REGEN_PERCENT_PER_SECOND = 0.05 -- 5% of max mana per second

-- Get mana values for a player
local function getManaValues(player)
	local stats = player:FindFirstChild("Stats")
	if not stats then return nil, nil end
	
	local currentMana = stats:FindFirstChild("CurrentMana")
	local maxMana = stats:FindFirstChild("MaxMana")
	
	if not currentMana or not maxMana then return nil, nil end
	
	return currentMana, maxMana
end


-- Start mana drain/regen loop for a player
local function startManaDrainLoop(player)
	-- Stop existing loop if any
	if playerManaConnections[player.UserId] then
		playerManaConnections[player.UserId]:Disconnect()
	end

	local lastManaValue = nil
	local connection = RunService.Heartbeat:Connect(function()
		-- Check if player still exists
		if not player or not player.Parent then
			if playerManaConnections[player.UserId] then
				playerManaConnections[player.UserId]:Disconnect()
				playerManaConnections[player.UserId] = nil
			end
			playerRunningState[player.UserId] = nil
			lastManaDecreaseTime[player.UserId] = nil
			return
		end

		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local currentMana, maxMana = getManaValues(player)
		if not currentMana or not maxMana then return end

		-- Track last mana value and time of decrease
		if lastManaValue == nil then
			lastManaValue = currentMana.Value
		end
		if currentMana.Value < lastManaValue then
			lastManaDecreaseTime[player.UserId] = tick()
		end
		lastManaValue = currentMana.Value

		local now = tick()
		local canRegen = false
		if lastManaDecreaseTime[player.UserId] then
			canRegen = (now - lastManaDecreaseTime[player.UserId]) >= 3
		else
			canRegen = true -- If never decreased, allow regen
		end

		-- Drain mana if running (legacy, keep for compatibility)
		local isRunning = playerRunningState[player.UserId] or false
		if isRunning and humanoid.Health > 0 then
			accumulatedManaDrain[player.UserId] = (accumulatedManaDrain[player.UserId] or 0) + (MANA_DRAIN_PER_SECOND_RUNNING / 60)
			if accumulatedManaDrain[player.UserId] >= 1 then
				local drainToApply = math.floor(accumulatedManaDrain[player.UserId])
				accumulatedManaDrain[player.UserId] = accumulatedManaDrain[player.UserId] - drainToApply
				local oldMana = currentMana.Value
				currentMana.Value = math.max(0, currentMana.Value - drainToApply)
			end
		elseif canRegen and humanoid.Health > 0 then
			-- Regenerate mana if not decreased for 3 seconds (5% of max mana per second)
			local regenAmount = (maxMana.Value * MANA_REGEN_PERCENT_PER_SECOND) / 60
			accumulatedManaDrain[player.UserId] = (accumulatedManaDrain[player.UserId] or 0) - regenAmount
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
		return true
	end
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
-- PlayerAdded handler moved to Init.server.lua for centralized initialization

-- Cleanup on player disconnect
Players.PlayerRemoving:Connect(function(player)
	ManaManager.CleanupPlayer(player)
end)

return ManaManager
