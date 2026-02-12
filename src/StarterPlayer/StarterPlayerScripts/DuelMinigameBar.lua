-- DuelMinigameBar.lua
-- UI and logic for duel timing minigame bar

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

local module = {}

-- Settings for the bar
local BAR_WIDTH = 400
local BAR_HEIGHT = 40
local SAFEZONE_WIDTH = 80
local BAR_MOVE_TIME_DEFAULT = 1.5 -- initial seconds for bar to move left to right
local BAR_MOVE_TIME_MIN = 0.6 -- minimum speed
local BAR_MOVE_TIME_DECAY = 0.08 -- how much to speed up per round

function module.CreateBar(parent, onResult, roundNum)
	       local screenGui = Instance.new("ScreenGui")
	       screenGui.Name = "DuelMinigameBarGui"
	       screenGui.ResetOnSpawn = false
	       screenGui.Parent = parent

	       local barFrame = Instance.new("Frame")
	       barFrame.Name = "BarFrame"
	       barFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	       barFrame.Position = UDim2.new(0.5, -BAR_WIDTH/2, 0.8, 0)
	       barFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	       barFrame.BorderSizePixel = 0
	       barFrame.Parent = screenGui

	       -- Randomize safe zone position
	       local safeZoneLeft = math.random(0, BAR_WIDTH - SAFEZONE_WIDTH)
	       local safeZone = Instance.new("Frame")
	       safeZone.Name = "SafeZone"
	       safeZone.Size = UDim2.new(0, SAFEZONE_WIDTH, 1, 0)
	       safeZone.Position = UDim2.new(0, safeZoneLeft, 0, 0)
	       safeZone.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	       safeZone.BorderSizePixel = 0
	       safeZone.Parent = barFrame

	       local marker = Instance.new("Frame")
	       marker.Name = "Marker"
	       marker.Size = UDim2.new(0, 10, 1, 0)
	       marker.Position = UDim2.new(0, 0, 0, 0)
	       marker.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	       marker.BorderSizePixel = 0
	       marker.Parent = barFrame

	       local tapped = false
	       local tapTime = nil
	       local markerTween

	       -- Calculate bar move time based on roundNum
	       local round = tonumber(roundNum) or 1
	       local barMoveTime = math.max(BAR_MOVE_TIME_DEFAULT - BAR_MOVE_TIME_DECAY * (round - 1), BAR_MOVE_TIME_MIN)

	       local function onTap()
		       if tapped then return end
		       tapped = true
		       if markerTween then markerTween:Cancel() end
		       local markerX = marker.Position.X.Scale * BAR_WIDTH + marker.Position.X.Offset
		       -- Calculate accuracy
		       local markerCenter = markerX + 5
		       local safeLeft = safeZoneLeft
		       local safeRight = safeZoneLeft + SAFEZONE_WIDTH
		       local result = "Miss"
		       if markerCenter >= safeLeft and markerCenter <= safeRight then
			       result = "Safe"
		       end
		       if onResult then onResult(result, markerCenter, safeLeft, safeRight) end
		       screenGui:Destroy()
	       end

	       -- Input (use UserInputService instead of ScreenGui.InputBegan)
	       local UserInputService = game:GetService("UserInputService")
	       local inputConn
	       inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		       if processed then return end
		       if not screenGui.Parent then return end -- GUI destroyed
		       if not screenGui.Enabled then return end
		       if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			       onTap()
		       end
	       end)
	       -- Clean up connection when GUI is destroyed
	       screenGui.AncestryChanged:Connect(function(_, parent)
		       if not parent and inputConn then
			       inputConn:Disconnect()
			       inputConn = nil
		       end
	       end)

	       -- Animate marker
	       marker.Position = UDim2.new(0, 0, 0, 0)
	       markerTween = TweenService:Create(marker, TweenInfo.new(barMoveTime, Enum.EasingStyle.Linear), {Position = UDim2.new(1, -10, 0, 0)})
	       markerTween:Play()
	       markerTween.Completed:Connect(function()
		       if not tapped then
			       onTap()
		       end
	       end)

		return screenGui
	end

	return module
