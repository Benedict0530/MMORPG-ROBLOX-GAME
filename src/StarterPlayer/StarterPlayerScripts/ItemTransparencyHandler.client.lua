-- ItemTransparencyHandler.client.lua
-- Handles item transparency based on ownership for each player
-- Items appear faded (0.7) to players who didn't deal the most damage
-- Items appear normal (0) to the player who dealt the most damage

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Track items we've already set up
local monitoredItems = {}

-- Set transparency for all parts recursively
local function setItemTransparency(obj, transparency)
	if not obj then return end
	if obj:IsA("BasePart") then
		obj.Transparency = transparency
	end
	for _, child in ipairs(obj:GetChildren()) do
		setItemTransparency(child, transparency)
	end
end

-- Check if player can see this item at normal transparency
local function isPlayerOwner(item, currentPlayer)
	local dropOwner = item:FindFirstChild("DropOwner")
	if not dropOwner then return false end
	
	local ownerValue = dropOwner.Value
	return ownerValue and ownerValue == currentPlayer
end

-- Monitor an item and update its transparency based on ownership
local function monitorItem(item)
	if monitoredItems[item] then return end
	monitoredItems[item] = true
	
	task.spawn(function()
		while item and item.Parent do
			local dropOwner = item:FindFirstChild("DropOwner")
			local dropTime = item:FindFirstChild("DropTime")
			
			if dropOwner and dropTime then
				local ownerValue = dropOwner.Value
				local elapsedTime = tick() - dropTime.Value
			
			-- Get pickup restriction duration from the drop (defaults to 10 if not found)
			local pickupRestrictionDuration = 10
			local pickupRestrictionValue = item:FindFirstChild("PickupRestrictionDuration")
			if pickupRestrictionValue then
				pickupRestrictionDuration = pickupRestrictionValue.Value
			end
			
			local isOwnershipExpired = elapsedTime >= pickupRestrictionDuration
				
				if not isOwnershipExpired then
					-- Ownership window is active
					if ownerValue and ownerValue == player then
						-- This player is the owner: show normally
						targetTransparency = 0
					else
						-- This player is NOT the owner: show faded
						targetTransparency = 0.7
					end
				else
					-- Ownership expired: show normally to everyone
					targetTransparency = 0
				end
				
				-- Apply transparency
				setItemTransparency(item, targetTransparency)
			end
			
			task.wait(0.5)
		end
	end)
end

-- Monitor workspace for new items being spawned
local function monitorWorkspace()
	-- First, check for existing items
	local function checkExistingItems(parent)
		for _, obj in ipairs(parent:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("Folder") then
				-- Check if this is an item (has ItemType or CoinType tag)
				if obj:FindFirstChild("ItemType") or obj:FindFirstChild("CoinType") then
					if obj:FindFirstChild("DropOwner") and obj:FindFirstChild("DropTime") then
						monitorItem(obj)
					end
				end
			end
		end
	end
	
	checkExistingItems(workspace)
	
	-- Monitor for new items being added
	workspace.DescendantAdded:Connect(function(descendant)
		-- Check if this is an item with ownership info
		if (descendant:FindFirstChild("ItemType") or descendant:FindFirstChild("CoinType")) and 
		   descendant:FindFirstChild("DropOwner") and 
		   descendant:FindFirstChild("DropTime") then
			monitorItem(descendant)
		end
	end)
end

-- Start monitoring when player loads
task.wait(0.1)
monitorWorkspace()

-- Re-monitor on character respawn to catch any new items
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	monitorWorkspace()
end)
