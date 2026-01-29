-- ChatBillboardHandler.lua
-- Server-side custom chat billboard system with Roblox TextService filtering

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

-- Bad words list (extra strict layer)
local badwords = require(script.Parent.Library.badwords)

-- =====================
-- RemoteEvents
-- =====================
local chatEvent = Instance.new("RemoteEvent")
chatEvent.Name = "InGameChatEvent"
chatEvent.Parent = ReplicatedStorage

local broadcastEvent = Instance.new("RemoteEvent")
broadcastEvent.Name = "ChatBroadcastEvent"
broadcastEvent.Parent = ReplicatedStorage

print("[InGameChat] ✓ RemoteEvents created")

-- =====================
-- Configuration
-- =====================
local CHAT_DISPLAY_DURATION = 5
local CHAT_MAX_WIDTH = 10
local CHAT_OFFSET_Y = 5
local CHAT_STACK_HEIGHT = 1.3
local MAX_MESSAGE_LENGTH = 100

-- =====================
-- Roblox mandatory text filter
-- =====================
local function robloxFilter(player, text)
	local success, textFilterResult = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
	end)

	if not success then
		warn("[ChatFilter] Roblox filter failed:", textFilterResult)
		return "[Message could not be filtered]"
	end

	local ok, filtered = pcall(function()
		return textFilterResult:GetNonChatStringForBroadcastAsync(player.UserId)
	end)
	if ok then
		return filtered
	else
		warn("[ChatFilter] Failed to get filtered string:", filtered)
		return "[Message could not be filtered]"
	end
end


-- =====================
-- Extra strict bad-word censor
-- =====================
local function censorBadWordsCaseInsensitive(message)
	-- Always censor 'gay' (case-insensitive, hardcoded)
	local function censorWord(msg, word)
		local lowerMsg = msg:lower()
		local lowerWord = word:lower()
		local start = 1
		while true do
			local s, e = lowerMsg:find(lowerWord, start, true)
			if not s then break end
			msg = msg:sub(1, s-1) .. string.rep("#", e-s+1) .. msg:sub(e+1)
			lowerMsg = msg:lower()
			start = s + (e-s+1)
		end
		return msg
	end
	message = censorWord(message, "gay")
	-- Also censor all words in badwords list (case-insensitive)
	for _, badword in ipairs(badwords) do
		message = censorWord(message, badword)
	end
	return message
end

-- =====================
-- Billboard repositioning
-- =====================
local function updateBillboardPositions(humanoidRootPart)
	local billboards = {}

	for _, child in ipairs(humanoidRootPart:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "ChatBillboard" then
			table.insert(billboards, child)
		end
	end

	for index, billboard in ipairs(billboards) do
		billboard.StudsOffset = Vector3.new(
			0,
			CHAT_OFFSET_Y + ((index - 1) * CHAT_STACK_HEIGHT),
			0
		)
	end
end

-- =====================
-- Create chat billboard
-- =====================
local function createChatBillboard(player, message)
	if not player.Character then return end

	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local count = 0
	for _, child in ipairs(humanoidRootPart:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "ChatBillboard" then
			count += 1
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChatBillboard"
	billboard.Size = UDim2.new(CHAT_MAX_WIDTH, 0, 1.2, 0)
	billboard.MaxDistance = 1000
	billboard.StudsOffset = Vector3.new(
		0,
		CHAT_OFFSET_Y + (count * CHAT_STACK_HEIGHT),
		0
	)
	billboard.Parent = humanoidRootPart

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -10, 1, -6)
	textLabel.Position = UDim2.new(0, 5, 0, 3)
	textLabel.BackgroundTransparency = 1
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.Text = message
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Font = Enum.Font.GothamSemibold
	textLabel.Parent = frame

	task.delay(CHAT_DISPLAY_DURATION, function()
		local tween = TweenService:Create(
			frame,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}
		)

		tween:Play()
		tween.Completed:Connect(function()
			billboard:Destroy()
			updateBillboardPositions(humanoidRootPart)
		end)
	end)
end

-- =====================
-- Handle incoming chat
-- =====================

chatEvent.OnServerEvent:Connect(function(player, message)
	if typeof(message) ~= "string" then return end
	if message == "" then return end

	if #message > MAX_MESSAGE_LENGTH then
		message = message:sub(1, MAX_MESSAGE_LENGTH)
	end

	message = message
		:gsub("<", "")
		:gsub(">", "")
		:gsub("rbxassetid://", "")

	-- Case-insensitive custom filter FIRST
	message = censorBadWordsCaseInsensitive(message)

	-- Roblox filter for compliance
	message = robloxFilter(player, message)

	-- Billboard + broadcast
	createChatBillboard(player, message)
	broadcastEvent:FireAllClients(player.DisplayName, message)

	print("[InGameChat]", player.Name, ":", message)
end)

print("[InGameChat] ✓ Custom chat billboard system ready")
