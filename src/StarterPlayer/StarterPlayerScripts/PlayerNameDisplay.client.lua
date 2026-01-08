-- PlayerNameDisplay.client.lua
-- Client-side custom player name display with BillboardGui
-- Uses a template frame from ReplicatedStorage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Load AdminId module to check for admins
local AdminId = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AdminId"))

-- Configuration
local NAME_DISPLAY_CONFIG = {
	distance = 100, -- Distance at which name is visible
	offset = Vector3.new(0, 3, 0), -- Offset above player's head
	showLevel = true,
}

-- Track created billboards to avoid duplicates
local createdBillboards = {}

print("[PlayerNameDisplay.client] Client script started")

-- Get the template frame from ReplicatedStorage
local function GetNameTagTemplate()
	local template = ReplicatedStorage:FindFirstChild("NameTagTemplate")
	if not template then
		warn("[PlayerNameDisplay.client] NameTagTemplate not found in ReplicatedStorage!")
		return nil
	end
	return template
end

-- Function to create name display for a player character
local function CreateNameDisplay(player, character)
	print("[PlayerNameDisplay.client] CreateNameDisplay called for:", player.Name)
	
	if not character or not player then 
		print("[PlayerNameDisplay.client] Invalid character or player")
		return 
	end
	
	-- Wait longer for HumanoidRootPart to exist (can take time for remote players)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoidRootPart then 
		print("[PlayerNameDisplay.client] No HumanoidRootPart for:", player.Name, "- will retry")
		-- Retry after a delay
		task.wait(2)
		if character and character.Parent then
			return CreateNameDisplay(player, character)
		end
		return 
	end
	
	-- Remove any existing custom name display
	local existingBillboard = humanoidRootPart:FindFirstChild("NameBillboard")
	if existingBillboard then
		existingBillboard:Destroy()
		print("[PlayerNameDisplay.client] Removed old billboard for:", player.Name)
	end
	
	-- Get the template
	local template = GetNameTagTemplate()
	if not template then
		warn("[PlayerNameDisplay.client] Cannot create name display without template")
		return
	end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameBillboard"
	billboard.Size = template.Size
	billboard.MaxDistance = NAME_DISPLAY_CONFIG.distance
	billboard.StudsOffset = NAME_DISPLAY_CONFIG.offset
	billboard.Parent = humanoidRootPart
	
	print("[PlayerNameDisplay.client] Created billboard for:", player.Name)
	
	-- Clone the template frame into the billboard
	local frameClone = template:Clone()
	frameClone.Position = UDim2.new(0.5, 0, 0, 0)
	frameClone.AnchorPoint = Vector2.new(0.5, 0)
	-- If this is the local player, put their nametag on top; otherwise use their UserId
	if player == LocalPlayer then
		frameClone.ZIndex = 1000 -- Local player's nametag always on top
	else
		frameClone.ZIndex = player.UserId % 100 -- Other players' nametags
	end
	frameClone.Parent = billboard
	
	-- Find the TextLabel in the cloned frame
	local textLabel = frameClone:FindFirstChild("NameLabel")
	if not textLabel then
		warn("[PlayerNameDisplay.client] NameLabel not found in template frame for:", player.Name)
		return
	end
	
	-- Store original text size for reference
	local originalTextSize = textLabel.TextSize
	
	-- Check if player is admin or verified and adjust size/position accordingly
	if AdminId.IsAdmin(player.UserId) then
		-- Make admin/verified names a bit bigger (1.5x multiplier)
		textLabel.TextSize = originalTextSize * 1.5
		-- Move billboard higher
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	else
		-- Keep default size and position for normal players
		billboard.StudsOffset = NAME_DISPLAY_CONFIG.offset
	end
	
	-- Build display text
	local displayText = player.DisplayName
	
	-- Check if player is admin
	if AdminId.IsAdmin(player.UserId) then
		local adminType = AdminId.GetAdminType(player.UserId)
		if adminType == "verified" then
			-- For verified admin (ID 1343215966), add crown after name
			displayText = player.DisplayName .. " 👑"
		else
			-- For other admins, add "[Admin]" before name
			displayText = "[Admin] " .. player.DisplayName
		end
	end
	
	-- Add level if available
	if NAME_DISPLAY_CONFIG.showLevel then
		local stats = player:FindFirstChild("Stats")
		if stats then
			local level = stats:FindFirstChild("Level")
			if level then
				displayText = "Lvl " .. tostring(level.Value) .. ". " .. displayText
			end
		end
	end
	
	textLabel.Text = displayText
	
	-- Set text color based on admin type
	if AdminId.IsAdmin(player.UserId) then
		local adminType = AdminId.GetAdminType(player.UserId)
		if adminType == "verified" then
			textLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red color for verified
		else
			textLabel.TextColor3 = Color3.fromRGB(135, 206, 250) -- Light blue color for regular admins
		end
	else
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White color for normal players
	end
	print("[PlayerNameDisplay.client] Set text:", displayText)
	
	-- Update name display if level changes
	if NAME_DISPLAY_CONFIG.showLevel then
		local stats = player:FindFirstChild("Stats")
		if stats then
			local level = stats:FindFirstChild("Level")
			if level then
				local function onLevelChanged()
					if textLabel and textLabel.Parent then
						-- Rebuild display text with level update
						local updatedText = player.DisplayName
						
						-- Check if player is admin
						if AdminId.IsAdmin(player.UserId) then
							local adminType = AdminId.GetAdminType(player.UserId)
							if adminType == "verified" then
								updatedText = player.DisplayName .. " 👑"
							else
								updatedText = "[Admin] " .. player.DisplayName
							end
						end
						
						-- Add level
						updatedText = "Lvl " .. tostring(level.Value) .. ". " .. updatedText
						textLabel.Text = updatedText
						
						-- Set text color based on admin type
						if AdminId.IsAdmin(player.UserId) then
							local adminType = AdminId.GetAdminType(player.UserId)
							if adminType == "verified" then
								textLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red color for verified
							else
								textLabel.TextColor3 = Color3.fromRGB(135, 206, 250) -- Light blue color for regular admins
							end
						else
							textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White color for normal players
						end
					end
				end
				level.Changed:Connect(onLevelChanged)
			end
		end
	end
	
	print("[PlayerNameDisplay.client] ✓ Created custom name display for:", player.Name)
	createdBillboards[player.UserId] = billboard
	return billboard
end

-- Setup a player
local function SetupPlayer(player)
	print("[PlayerNameDisplay.client] SetupPlayer called for:", player.Name)
	
	-- Always connect to CharacterAdded first
	player.CharacterAdded:Connect(function(character)
		print("[PlayerNameDisplay.client] Character loaded for:", player.Name)
		task.wait(0.3)
		CreateNameDisplay(player, character)
	end)
	
	-- If character already exists, set it up immediately
	if player.Character then
		print("[PlayerNameDisplay.client] Character already exists for:", player.Name)
		task.wait(0.3)
		CreateNameDisplay(player, player.Character)
	else
		print("[PlayerNameDisplay.client] Waiting for character for:", player.Name)
	end
end

-- Initialize
local function Initialize()
	print("[PlayerNameDisplay.client] Initializing...")
	
	-- Setup all players (including self)
	for _, player in ipairs(Players:GetPlayers()) do
		print("[PlayerNameDisplay.client] Setting up existing player:", player.Name)
		SetupPlayer(player)
	end
	
	-- Setup new players
	Players.PlayerAdded:Connect(function(player)
		print("[PlayerNameDisplay.client] New player joined:", player.Name)
		task.wait(0.5)
		SetupPlayer(player)
	end)
	
	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		if createdBillboards[player.UserId] then
			createdBillboards[player.UserId]:Destroy()
			createdBillboards[player.UserId] = nil
			print("[PlayerNameDisplay.client] Cleaned up display for:", player.Name)
		end
	end)
	
	print("[PlayerNameDisplay.client] ✓ Initialized custom player name displays")
end

-- Wait for LocalPlayer to load
if not LocalPlayer then
	LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer")
end

-- Wait longer to ensure other players are loaded
task.wait(2)
Initialize()


