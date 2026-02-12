-- ParalysisHandler.client.lua
-- Handles paralysis effects when player gets hit in PVP
-- 1st Hit: Paralyze - jump and hold in air
-- 2nd Hit (while paralyzed): Knockback and ragdoll while flying
local ParalysisHandler = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Get or create paralysis state value in ReplicatedStorage
local isParalyzedValue = ReplicatedStorage:FindFirstChild("IsParalyzed")
if not isParalyzedValue then
	isParalyzedValue = Instance.new("BoolValue")
	isParalyzedValue.Name = "IsParalyzed"
	isParalyzedValue.Value = false
	isParalyzedValue.Parent = ReplicatedStorage
end

-- Get or wait for the ParalysisEvent and KnockbackEvent
local ParalysisEvent = ReplicatedStorage:WaitForChild("ParalysisEvent", 10)
local KnockbackEvent = ReplicatedStorage:WaitForChild("KnockbackEvent", 10)

-- Store original walk speed
local DEFAULT_WALK_SPEED = 16
local isParalyzed = false
local isRagdolled = false
local paralysisBodyVelocity = nil -- Store reference to paralysis body velocity

-- Function to disable movement
local function disableMovement()
	if humanoid then
		humanoid.WalkSpeed = 0 -- Set walk speed to 0 to prevent movement
	end
	isParalyzed = true
	isParalyzedValue.Value = true -- Update ReplicatedStorage value
	
	-- Cancel all animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end
	
	--print("[ParalysisHandler] Movement disabled and animations cancelled")
end

-- Function to enable movement
local function enableMovement()
	if humanoid then
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED -- Restore walk speed
	end
	isParalyzed = false
	isParalyzedValue.Value = false -- Update ReplicatedStorage value
	
	-- Fire event to resume player animations
	local resumeAnimationEvent = ReplicatedStorage:FindFirstChild("ResumeAnimationEvent")
	if resumeAnimationEvent then
		resumeAnimationEvent:FireServer()
	end
	
	--print("[ParalysisHandler] Movement enabled, animations resuming")
end

-- Function to jump and hold player in air
local function jumpAndHoldInAir()
	if humanoid and humanoidRootPart then
		-- Store original jump power
		local originalJumpHeight = humanoid.JumpHeight
		
		-- Lower the jump power
		humanoid.JumpHeight = 1.5 -- Reduced from default
		
		-- Make the character jump
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		--print("[ParalysisHandler] Player jumped with reduced power")
		
		-- Wait a moment for jump to register, then hold them in air
		task.wait(0.1)
		
		-- Restore original jump power
		humanoid.JumpHeight = originalJumpHeight
		
		-- Create a BodyVelocity to hold them in the air
		paralysisBodyVelocity = Instance.new("BodyVelocity")
		paralysisBodyVelocity.Velocity = Vector3.new(0, 0, 0) -- Zero velocity to keep in place
		paralysisBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		paralysisBodyVelocity.Parent = humanoidRootPart
		
		--print("[ParalysisHandler] Player held in air")
		
		-- Wait 1 second then remove the body velocity to let them fall
		task.wait(1.0)
		
		-- Only destroy if it still exists (may have been destroyed by 2nd hit)
		if paralysisBodyVelocity and paralysisBodyVelocity.Parent then
			paralysisBodyVelocity:Destroy()
			paralysisBodyVelocity = nil
		end
		
		--print("[ParalysisHandler] Player released to fall")
	end
end

-- Function to ragdoll the player (using proper Roblox ragdoll state)
local function ragdollPlayer(duration)
	if not character or isRagdolled then return end
	
	isRagdolled = true
	--print("[ParalysisHandler] Player ragdolled")
	
	-- Disable getting up so character stays ragdolled
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	
	-- Trigger ragdoll state (proper Roblox ragdoll)
	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	
	-- Wait for ragdoll duration
	task.wait(duration or 1.0)
	
	-- Re-enable getting up to allow recovery
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	
	isRagdolled = false
	--print("[ParalysisHandler] Ragdoll ended")
end

-- Function to apply knockback and ragdoll together
local function knockbackAndRagdoll(direction, force, duration)
	if humanoid and humanoidRootPart then
		-- Remove paralysis body velocity if it exists so knockback takes effect
		if paralysisBodyVelocity then
			paralysisBodyVelocity:Destroy()
			paralysisBodyVelocity = nil
		end
		
		-- Apply knockback velocity
		humanoidRootPart.AssemblyLinearVelocity = direction * force
		--print("[ParalysisHandler] Knockback applied with force: " .. force)
		
		-- Immediately ragdoll the player (they fly out while ragdolled)
		ragdollPlayer(duration or 1.0)
	end
end

-- Handle paralysis effect when hit
ParalysisEvent.OnClientEvent:Connect(function(duration)
	duration = duration or 1 -- Default to 1 second if not specified
	
	if isParalyzed then
		--print("[ParalysisHandler] Already paralyzed, ignoring additional paralysis")
		return
	end
	
	--print("[ParalysisHandler] Paralysis effect triggered for " .. duration .. " seconds")
	
	-- Disable movement
	disableMovement()
	
	-- Jump and hold in air
	jumpAndHoldInAir()
	
	-- Wait for duration (jumpAndHoldInAir already waits 1 second for the hold)
	-- Additional wait if duration is longer than 1
	if duration > 1 then
		task.wait(duration - 1)
	end
	
	-- Re-enable movement
	enableMovement()
	
	--print("[ParalysisHandler] Paralysis effect ended")
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	isParalyzed = false
	isRagdolled = false
	isParalyzedValue.Value = false -- Reset paralysis state
	--print("[ParalysisHandler] Character respawned, reset paralysis and ragdoll state")
end)

-- Handle knockback and ragdoll effect when hit 2nd time (during paralysis)
KnockbackEvent.OnClientEvent:Connect(function(direction, force)
	if not isParalyzed then
		--print("[ParalysisHandler] Not currently paralyzed, ignoring knockback")
		return
	end
	
	if isRagdolled then
		--print("[ParalysisHandler] Already ragdolled, ignoring knockback")
		return
	end
	
	--print("[ParalysisHandler] 2nd hit during paralysis! Knockback and ragdoll triggered")
	
	-- Apply knockback and ragdoll (player flies out while ragdolled)
	knockbackAndRagdoll(direction, force, 1.0)
	
	--print("[ParalysisHandler] Knockback and ragdoll effect ended")
end)

return ParalysisHandler
