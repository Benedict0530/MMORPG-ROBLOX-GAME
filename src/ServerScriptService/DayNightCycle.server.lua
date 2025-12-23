-- -- DayNightCycle.server.lua
-- -- Controls the in-game day/night cycle (10x faster than real time)

-- local Lighting = game:GetService("Lighting")
-- local RunService = game:GetService("RunService")

-- -- Configuration
-- local CYCLE_SPEED = 225
-- local INITIAL_TIME = 6 -- Start at 6:00 AM (morning)

-- -- Set initial time
-- Lighting.ClockTime = INITIAL_TIME

-- -- Ambient lighting settings for different times
-- local MORNING_AMBIENT = Color3.fromRGB(200, 200, 200)
-- local NOON_AMBIENT = Color3.fromRGB(255, 255, 255)
-- local EVENING_AMBIENT = Color3.fromRGB(255, 180, 100)
-- local NIGHT_AMBIENT = Color3.fromRGB(100, 100, 150)

-- -- Update time every frame
-- RunService.Heartbeat:Connect(function(deltaTime)
-- 	-- Increment clock time (10x speed)
-- 	-- deltaTime is in seconds, so we multiply by 10 to go 10x faster
-- 	Lighting.ClockTime = (Lighting.ClockTime + (deltaTime * CYCLE_SPEED / 3600)) % 24
	
-- 	-- Update ambient lighting based on time of day
-- 	local clockTime = Lighting.ClockTime
	
-- 	if clockTime >= 5 and clockTime < 7 then
-- 		-- Early morning (sunrise)
-- 		Lighting.Ambient = MORNING_AMBIENT:Lerp(NOON_AMBIENT, (clockTime - 5) / 2)
-- 	elseif clockTime >= 7 and clockTime < 12 then
-- 		-- Morning to noon
-- 		Lighting.Ambient = MORNING_AMBIENT:Lerp(NOON_AMBIENT, (clockTime - 7) / 5)
-- 	elseif clockTime >= 12 and clockTime < 18 then
-- 		-- Noon to evening
-- 		Lighting.Ambient = NOON_AMBIENT:Lerp(EVENING_AMBIENT, (clockTime - 12) / 6)
-- 	elseif clockTime >= 18 and clockTime < 20 then
-- 		-- Evening (sunset)
-- 		Lighting.Ambient = EVENING_AMBIENT:Lerp(NIGHT_AMBIENT, (clockTime - 18) / 2)
-- 	elseif clockTime >= 20 or clockTime < 5 then
-- 		-- Night
-- 		Lighting.Ambient = NIGHT_AMBIENT
-- 	end
-- end)
