-- DungeonUI Client Module
-- Place under StarterPlayerScripts/ClientHandler/DungeonUI.lua

local DungeonUI = {}

-- Table to store EntryItemButton click connections by button instance
local entryItemButtonConnections = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")

-- Listen for DungeonUIEvent from server
local DungeonUIEvent = ReplicatedStorage:WaitForChild("DungeonUIEvent")
local DungeonEntryEvent = ReplicatedStorage:WaitForChild("DungeonEntryEvent")
local DungeonsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonsData"))

-- Center-screen message utility
local function showCenterScreenMessage(text, duration)
	duration = duration or 2
	local messageGui = playerGui:FindFirstChild("CenterScreenMessage")
	if not messageGui then
		messageGui = Instance.new("ScreenGui")
		messageGui.Name = "CenterScreenMessage"
		messageGui.ResetOnSpawn = false
		messageGui.Parent = playerGui
		local label = Instance.new("TextLabel")
		label.Name = "MessageLabel"
		label.Size = UDim2.new(0.6, 0, 0.1, 0)
		label.Position = UDim2.new(0.2, 0, 0.45, 0)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(30,30,30)
		label.TextColor3 = Color3.fromRGB(255,255,255)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Visible = false
		label.Parent = messageGui
	end
	local label = messageGui:FindFirstChild("MessageLabel")
	if label then
		label.Text = text
		label.Visible = true
		label.BackgroundTransparency = 0.3
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.2
		-- Fade out after duration
		task.spawn(function()
			task.wait(duration)
			if label then
				for i=0,1,0.1 do
					label.TextTransparency = i
					label.TextStrokeTransparency = 0.2 + i*0.8
					label.BackgroundTransparency = 0.3 + i*0.7
					task.wait(0.03)
				end
				label.Visible = false
			end
		end)
	end
end

-- When DungeonUIEvent is fired, show DungeonUI and set all info
DungeonUIEvent.OnClientEvent:Connect(function(toMap)
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local gameGui = playerGui:FindFirstChild("GameGui")
	if not gameGui then return end
	local dungeonUI = gameGui:FindFirstChild("DungeonUI")
	if not dungeonUI then return end
	dungeonUI.Visible = true

	local background = dungeonUI:FindFirstChild("Background")
	if not background then return end

	-- Center the background in the screen
	if playerGui then
		local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local bgSize = background.Size
		if typeof(bgSize) == "UDim2" then
			-- If using scale, just center with anchor point
			background.AnchorPoint = Vector2.new(0.5, 0.5)
			background.Position = UDim2.new(0.5, 0, 0.5, 0)
		else
			-- Fallback: set to center using offset
			background.Position = UDim2.new(0, (viewportSize.X - bgSize.X.Offset) / 2, 0, (viewportSize.Y - bgSize.Y.Offset) / 2)
		end
	end

	local data = DungeonsData[toMap]

	-- Entry Item Button logic
	local entryItemButton = background:FindFirstChild("EntryItemButton")
	if entryItemButton and (entryItemButton:IsA("TextButton") or entryItemButton:IsA("ImageButton")) then
		print("[DungeonUI] EntryItemButton found, setting up click handler.")
		-- Remove previous connection for this button if it exists
		if entryItemButtonConnections[entryItemButton] then
			entryItemButtonConnections[entryItemButton]:Disconnect()
			entryItemButtonConnections[entryItemButton] = nil
		end
		local newConn = entryItemButton.MouseButton1Click:Connect(function()
			print("[DungeonUI] EntryItemButton clicked for map:", toMap)
			-- Hide the DungeonUI
			dungeonUI.Visible = false
			if DungeonEntryEvent then
				print("[DungeonUI] Firing DungeonEntryEvent to server for map:", toMap)
				DungeonEntryEvent:FireServer(toMap)
			else
				warn("[DungeonUI] DungeonEntryEvent RemoteEvent not found in ReplicatedStorage!")
			end
		end)
		entryItemButtonConnections[entryItemButton] = newConn
	else
		print("[DungeonUI] EntryItemButton not found or not a Button.")
	end

	-- Robux Entry Button logic
	local robuxEntryButton = background:FindFirstChild("RobuxEntryButton")
	if robuxEntryButton and (robuxEntryButton:IsA("TextButton") or robuxEntryButton:IsA("ImageButton")) then
		print("[DungeonUI] RobuxEntryButton found, setting up click handler.")
		if entryItemButtonConnections[robuxEntryButton] then
			entryItemButtonConnections[robuxEntryButton]:Disconnect()
			entryItemButtonConnections[robuxEntryButton] = nil
		end
		local newConn = robuxEntryButton.MouseButton1Click:Connect(function()
			print("[DungeonUI] RobuxEntryButton clicked for map:", toMap)
			dungeonUI.Visible = false
			-- Fire to server to register pending Robux dungeon entry
			if DungeonEntryEvent then
				DungeonEntryEvent:FireServer(toMap, true)
			end
			-- Prompt player to purchase developer product (10 Robux)
			local DEV_PRODUCT_ID = 3525149275 -- REPLACE with your actual Developer Product ID for 10 Robux
			local player = Players.LocalPlayer
			if DEV_PRODUCT_ID == 0 then
				warn("[DungeonUI] Please set the correct Developer Product ID for Robux entry!")
				showCenterScreenMessage("Robux entry not configured.", 2.5)
				return
			end
			MarketplaceService:PromptProductPurchase(player, DEV_PRODUCT_ID)
		end)
		entryItemButtonConnections[robuxEntryButton] = newConn
	end

	-- Set Title
	local titleLabel = background:FindFirstChild("Title")
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = tostring(toMap)
		-- Set Drops
		local dropsFrame = background:FindFirstChild("Drops")
		if dropsFrame then
			local dropsLabel = dropsFrame:FindFirstChild("TextLabel")
			if dropsLabel and dropsLabel:IsA("TextLabel") then
				if data and data.DropsText then
					dropsLabel.Text = data.DropsText
				else
					dropsLabel.Text = ""
				end
			end
		end
	end

	-- Set Description
	local descLabel = background:FindFirstChild("Description")
	if descLabel and descLabel:IsA("TextLabel") then
		if data and data.Story then
			descLabel.Text = data.Story
		else
			descLabel.Text = ""
		end
	end

	-- Set Requirement
	local reqLabel = background:FindFirstChild("Requirement")
	if reqLabel and reqLabel:IsA("TextLabel") then
		if data then
			local reqs = {}
			if data.EntryLevelRequirement then
				table.insert(reqs, "Level: " .. tostring(data.EntryLevelRequirement))
			end
			if data.EntryItemRequirement then
				table.insert(reqs, "Dungeon Entry: " .. tostring(data.EntryItemRequirement))
			end
			if data.TimeLimitMinutes then
				table.insert(reqs, "Time Limit: " .. tostring(data.TimeLimitMinutes) .. " min")
			end
			reqLabel.Text = #reqs > 0 and table.concat(reqs, "\n") or ""
		else
			reqLabel.Text = ""
		end
	end
end)

-- Listen for DungeonEntryEvent fired back from server for failure
DungeonEntryEvent.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.success == false and data.reason then
		local player = Players.LocalPlayer
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			showCenterScreenMessage(data.reason, 2.5)
		end
	end
end)
-- (Removed duplicate label-setting code from DungeonEntryEvent.OnClientEvent)

return DungeonUI
