local PetAnimation = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Get PetData module
local PetData = require(ReplicatedStorage.Modules.PetData)

-- Track all pets and their animations
-- Structure: { [petModel] = { idleTrack, walkTrack, movementConnection } }
local activePets = {}

-- Function to load and play animation
local function loadAnimation(petModel, animationId, looped)
	if not petModel:FindFirstChild("AnimationController") then
		warn("[Pet Animation] Pet model missing AnimationController")
		return nil
	end
	
	local animator = petModel.AnimationController:FindFirstChild("Animator")
	if not animator then
		warn("[Pet Animation] Pet AnimationController missing Animator")
		return nil
	end
	
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId
	anim.Parent = petModel
	
	local track = animator:LoadAnimation(anim)
	track.Looped = looped or false
	
	return track
end

-- Function to setup pet animations
function PetAnimation:SetupPet(petModel, petName)
	-- Clean up if this pet already has animations
	if activePets[petModel] then
		PetAnimation:RemovePet(petModel)
	end
	
	-- Get pet data
	local petData = PetData:GetPetData(petName)
	if not petData then
		warn("[Pet Animation] Pet data not found for:", petName)
		return
	end
	
	-- Create entry for this pet
	activePets[petModel] = {
		idleTrack = nil,
		walkTrack = nil,
		movementConnection = nil
	}
	
	-- Load idle animation
	if petData.IdleAnimationId then
		local idleTrack = loadAnimation(petModel, petData.IdleAnimationId, true)
		if idleTrack then
			idleTrack:Play()
			activePets[petModel].idleTrack = idleTrack
			--print("[Pet Animation] Playing idle animation for:", petName)
		end
	end
	
	-- Load walk animation (don't play yet, wait for movement detection)
	if petData.WalkAnimationId then
		local walkTrack = loadAnimation(petModel, petData.WalkAnimationId, true)
		if walkTrack then
			activePets[petModel].walkTrack = walkTrack
			--print("[Pet Animation] Walk animation loaded for:", petName)
		end
	end
	
	-- Setup movement detection
	if activePets[petModel].idleTrack and activePets[petModel].walkTrack then
		PetAnimation:SetupMovementDetection(petModel)
	end
end

-- Function to detect pet movement and switch animations
function PetAnimation:SetupMovementDetection(petModel)
	local humanoidRootPart = petModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end
	
	local petData = activePets[petModel]
	if not petData then
		return
	end
	
	local lastPosition = humanoidRootPart.Position
	local isWalking = false
	local movementThreshold = 0.05 -- Minimum distance to be considered "moving"
	
	-- Check movement every frame
	local connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not petModel or not petModel.Parent or not activePets[petModel] then
			return
		end
		
		local currentPosition = humanoidRootPart.Position
		local distance = (currentPosition - lastPosition).Magnitude
		
		local currentIdleTrack = petData.idleTrack
		local currentWalkTrack = petData.walkTrack
		
		-- If pet position is changing (moving), play walk animation
		if distance > movementThreshold then
			if not isWalking then
				isWalking = true
				-- Stop idle, start walking
				if currentIdleTrack and currentIdleTrack.IsPlaying then
					currentIdleTrack:Stop()
				end
				if currentWalkTrack and not currentWalkTrack.IsPlaying then
					currentWalkTrack:Play()
				end
				--print("[Pet Animation] Pet", petModel.Name, "is walking")
			end
		else
			-- Pet position is not changing (stopped), play idle animation
			if isWalking then
				isWalking = false
				-- Stop walking, start idle
				if currentWalkTrack and currentWalkTrack.IsPlaying then
					currentWalkTrack:Stop()
				end
				if currentIdleTrack and not currentIdleTrack.IsPlaying then
					currentIdleTrack:Play()
				end
				--print("[Pet Animation] Pet", petModel.Name, "is idle")
			end
		end
		
		lastPosition = currentPosition
	end)
	
	-- Store the connection so we can disconnect it later
	petData.movementConnection = connection
end

-- Function to remove pet
function PetAnimation:RemovePet(petModel)
	if not petModel then
		-- If no specific pet provided, remove all pets
		for model, data in pairs(activePets) do
			if data.idleTrack then
				data.idleTrack:Stop()
			end
			if data.walkTrack then
				data.walkTrack:Stop()
			end
			if data.movementConnection then
				data.movementConnection:Disconnect()
			end
		end
		activePets = {}
		--print("[Pet Animation] All pets removed")
		return
	end
	
	-- Remove specific pet
	local petData = activePets[petModel]
	if petData then
		if petData.idleTrack then
			petData.idleTrack:Stop()
		end
		if petData.walkTrack then
			petData.walkTrack:Stop()
		end
		if petData.movementConnection then
			petData.movementConnection:Disconnect()
		end
		activePets[petModel] = nil
		--print("[Pet Animation] Pet removed:", petModel.Name)
	end
end

-- Function to check if a model is a valid pet
local function isValidPet(child)
	return child:IsA("Model") 
		and child:GetAttribute("IsPet") 
		and child:GetAttribute("PetName") ~= nil
end

-- Function to initialize a pet
local function initializePet(petModel)
	local petName = petModel:GetAttribute("PetName")
	if petName then
		task.wait(0.1) -- Wait for model to fully load
		PetAnimation:SetupPet(petModel, petName)
	end
end

-- Initialize immediately when module is required
task.spawn(function()
	--print("[Pet Animation] Module loaded, initializing...")
	--print("[Pet Animation] My UserId:", player.UserId)
	
	-- Check for existing pets in workspace on script load
	--print("[Pet Animation] Scanning workspace for pets...")
	for _, child in ipairs(workspace:GetChildren()) do
		local childIsPet = child:GetAttribute("IsPet")
		local childOwner = child:GetAttribute("OwnerUserId")
		local childPetName = child:GetAttribute("PetName")
		--print("[Pet Animation] Checking:", child.Name, "IsModel:", child:IsA("Model"), 
			--"IsPet attr:", childIsPet, 
			--"OwnerUserId attr:", childOwner,
			--"PetName attr:", childPetName)
		
		if child:IsA("Model") and childIsPet and childOwner then
			--print("[Pet Animation] Owner match?", childOwner, "==", player.UserId, "-->", childOwner == player.UserId)
		end
		
		if isValidPet(child) then
			--print("[Pet Animation] Found existing pet:", child.Name)
			initializePet(child)
		end
	end
	
	-- Also check inside Pets folder if it exists
	local petsFolder = workspace:FindFirstChild("Pets")
	if petsFolder then
		--print("[Pet Animation] Found Pets folder, scanning inside...")
		for _, child in ipairs(petsFolder:GetChildren()) do
			--print("[Pet Animation] Checking in Pets folder:", child.Name, "IsModel:", child:IsA("Model"), 
				--"IsPet attr:", child:GetAttribute("IsPet"), 
				--"OwnerUserId attr:", child:GetAttribute("OwnerUserId"),
				--"PetName attr:", child:GetAttribute("PetName"))
			if isValidPet(child) then
				--print("[Pet Animation] Found existing pet in folder:", child.Name)
				initializePet(child)
			end
		end
	end
	
	-- Listen for newly added pets
	workspace.ChildAdded:Connect(function(child)
		if isValidPet(child) then
			--print("[Pet Animation] New pet added:", child.Name)
			initializePet(child)
		end
	end)
	
	-- Listen for pets added to Pets folder
	if petsFolder then
		petsFolder.ChildAdded:Connect(function(child)
			if isValidPet(child) then
				--print("[Pet Animation] New pet added to Pets folder:", child.Name)
				initializePet(child)
			end
		end)
		
		petsFolder.ChildRemoved:Connect(function(child)
			if activePets[child] then
				--print("[Pet Animation] Pet removed from Pets folder:", child.Name)
				PetAnimation:RemovePet(child)
			end
		end)
	end
	
	-- Listen for pet removal
	workspace.ChildRemoved:Connect(function(child)
		if activePets[child] then
			--print("[Pet Animation] Pet removed from workspace:", child.Name)
			PetAnimation:RemovePet(child)
		end
	end)
	
	--print("[Pet Animation] Initialization complete")
end)

return PetAnimation
