-- -- StarterClothes.lua
-- -- Automatically equips default shirt and pants on player spawn

-- local Players = game:GetService("Players")

-- local SHIRT_ID = "http://www.roblox.com/asset/?id=155136467"
-- local PANTS_ID = "http://www.roblox.com/asset/?id=155136428"

-- local function onCharacterAdded(character)
-- 	-- Add Shirt
-- 	if not character:FindFirstChildOfClass("Shirt") then
-- 		local shirt = Instance.new("Shirt")
-- 		shirt.ShirtTemplate = SHIRT_ID
-- 		shirt.Parent = character
-- 	end
-- 	-- Add Pants
-- 	if not character:FindFirstChildOfClass("Pants") then
-- 		local pants = Instance.new("Pants")
-- 		pants.PantsTemplate = PANTS_ID
-- 		pants.Parent = character
-- 	end
-- end

-- local function onPlayerAdded(player)
-- 	player.CharacterAdded:Connect(onCharacterAdded)
-- 	if player.Character then
-- 		onCharacterAdded(player.Character)
-- 	end
-- end

-- Players.PlayerAdded:Connect(onPlayerAdded)
-- -- For studio test mode (already present players)
-- for _, player in ipairs(Players:GetPlayers()) do
-- 	onPlayerAdded(player)
-- end
