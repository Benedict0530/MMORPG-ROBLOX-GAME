-- HealingCapsuleHandler.lua
-- Handles healing players who sit in HealingCapsule objects

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HealingCapsuleHandler = {}

-- Track which players are seated in capsules
local seatedPlayers = {}
-- Track accumulated healing (HP)
local accumulatedHealing = {}
-- Track accumulated mana regen (separate)
local accumulatedManaRegen = {}
-- Track touched connections for capsules
local capsuleConnections = {}

-- Healing settings (per second while seated)
local HEAL_PERCENT_PER_SECOND = 0.10 -- 10% of max health per second
local MANA_REGEN_PERCENT_PER_SECOND = 0.10 -- 10% of max mana per second

-- Setup collision detection for all capsules
local function setupCapsuleDetection(capsule)
	if capsuleConnections[capsule] then return end -- Already set up
	
	-- Find the seat part (usually named "Seat")
	local seatPart = capsule:FindFirstChild("Seat")
	if not seatPart or not seatPart:IsA("BasePart") then
		return
	end
	
	-- Check if seatPart is actually a Seat
	if not seatPart:IsA("Seat") then
		return
	end
	
	-- Monitor occupant changes for this seat
	local occupantConnection = seatPart.ChildAdded:Connect(function()
		-- This is just for monitoring, actual logic in heartbeat
	end)
	
	capsuleConnections[capsule] = {occupantConnection = occupantConnection}
end

-- Find all HealingCapsule models in workspace (recursive, including nested)
local function findHealingCapsules()
	local capsules = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and string.find(string.lower(descendant.Name), "healingcapsule") then
			table.insert(capsules, descendant)
		end
	end
	return capsules
end

-- Monitor for new capsules and set them up
local function monitorForNewCapsules()
	local capsules = findHealingCapsules()
	for _, capsule in ipairs(capsules) do
		setupCapsuleDetection(capsule)
	end
end

-- Initial setup for existing capsules
monitorForNewCapsules()

-- Monitor workspace for new capsules (including nested ones)
Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and string.find(string.lower(descendant.Name), "healingcapsule") then
		task.wait(0.1) -- Wait for model to fully load
		setupCapsuleDetection(descendant)
	end
end)

-- Also monitor when player sits in any seat (track capsule reference)
local function checkAllSeats()
	local function checkSeatsInModel(model)
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("Seat") and part.Parent then
				-- Check if this seat is part of a HealingCapsule
				local capsule = part.Parent
				if capsule:IsA("Model") and string.find(string.lower(capsule.Name), "healingcapsule") then
					part.Changed:Connect(function(property)
						if property == "Occupant" then
							local occupant = part.Occupant
							if occupant then
								local player = Players:GetPlayerFromCharacter(occupant.Parent)
								if player then
									seatedPlayers[player] = capsule
								end
							end
						end
					end)
				end
			end
		end
	end
	
	-- Check existing seats
	checkSeatsInModel(Workspace)
end

checkAllSeats()

-- Main healing loop using Heartbeat (like ManaManager)
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if not player or not player.Character then
			accumulatedHealing[player] = nil
			accumulatedManaRegen[player] = nil
			seatedPlayers[player] = nil
			continue
		end
		
		local character = player.Character
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			accumulatedHealing[player] = nil
			accumulatedManaRegen[player] = nil
			seatedPlayers[player] = nil
			continue
		end
		
		-- Check if player is sitting in a HealingCapsule seat
		local seatedCapsule = seatedPlayers[player]
		if seatedCapsule and seatedCapsule.Parent then
			local seatPart = seatedCapsule:FindFirstChild("Seat")
			-- Only heal if player is actually occupying the seat
			if seatPart and seatPart:IsA("Seat") and seatPart.Occupant == humanoid then
				-- Player is sitting in the capsule seat, apply healing
				
				-- Get stats
				local stats = player:FindFirstChild("Stats")
				if stats then
					local currentHealth = stats:FindFirstChild("CurrentHealth")
					local maxHealth = stats:FindFirstChild("MaxHealth")
					local currentMana = stats:FindFirstChild("CurrentMana")
					local maxMana = stats:FindFirstChild("MaxMana")
					
					-- Initialize accumulated values for this player
					accumulatedHealing[player] = (accumulatedHealing[player] or 0)
					accumulatedManaRegen[player] = (accumulatedManaRegen[player] or 0)
					
					-- Calculate healing based on max health percentage
					if maxHealth then
						local healPerFrame = (maxHealth.Value * HEAL_PERCENT_PER_SECOND) / 60
						accumulatedHealing[player] = accumulatedHealing[player] + healPerFrame
						
						-- Apply accumulated healing to HP
						if currentHealth and accumulatedHealing[player] >= 1 then
							local healAmount = math.floor(accumulatedHealing[player])
							accumulatedHealing[player] = accumulatedHealing[player] - healAmount
							currentHealth.Value = math.min(maxHealth.Value, currentHealth.Value + healAmount)
						end
					end
					
					-- Calculate mana regen based on max mana percentage
					if maxMana then
						local manaPerFrame = (maxMana.Value * MANA_REGEN_PERCENT_PER_SECOND) / 60
						accumulatedManaRegen[player] = accumulatedManaRegen[player] + manaPerFrame
						
						-- Apply accumulated mana regen
						if currentMana and accumulatedManaRegen[player] >= 1 then
							local manaAmount = math.floor(accumulatedManaRegen[player])
							accumulatedManaRegen[player] = accumulatedManaRegen[player] - manaAmount
							currentMana.Value = math.min(maxMana.Value, currentMana.Value + manaAmount)
						end
					end
				else
					print("[HealingCapsuleHandler] Stats not found for", player.Name)
				end
			else
				-- Player no longer sitting in this capsule
				accumulatedHealing[player] = nil
				accumulatedManaRegen[player] = nil
				seatedPlayers[player] = nil
			end
		else
			-- Player not in any capsule
			accumulatedHealing[player] = nil
			accumulatedManaRegen[player] = nil
			seatedPlayers[player] = nil
		end
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	seatedPlayers[player] = nil
	accumulatedHealing[player] = nil
	accumulatedManaRegen[player] = nil
end)

return HealingCapsuleHandler
