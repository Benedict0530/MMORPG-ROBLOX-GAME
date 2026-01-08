-- PlayerNameDisplay.lua
-- Server-side: Disables default Roblox name display for all players
-- Client-side script creates custom BillboardGui name tags

local Players = game:GetService("Players")

local PlayerNameDisplay = {}

-- Disable default name display for a player
function PlayerNameDisplay.HideDefaultName(player)
	if not player or not player.Character then
		return
	end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.NameDisplayDistance = 0 -- Hide default name
		print("[PlayerNameDisplay] Disabled default name display for:", player.Name)
	end
end

-- Setup a player when they join
function PlayerNameDisplay.SetupPlayer(player)
	-- Disable name on spawn
	if player.Character then
		PlayerNameDisplay.HideDefaultName(player)
	end
	
	-- Disable name on respawn
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		PlayerNameDisplay.HideDefaultName(player)
	end)
end

-- Initialize for all players
function PlayerNameDisplay.Initialize()
	-- Setup existing players
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerNameDisplay.SetupPlayer(player)
	end
	
	-- Setup new players
	Players.PlayerAdded:Connect(function(player)
		PlayerNameDisplay.SetupPlayer(player)
	end)
	
	print("[PlayerNameDisplay] Server: Initialized name display handler")
end

return PlayerNameDisplay

