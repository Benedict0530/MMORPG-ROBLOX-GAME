-- ButtonAnimateModule.lua
-- Handles button hover animations and click effects

local ButtonAnimateModule = {}

-- Function to animate button on hover
local function setupButtonAnimation(button, buttonName)
	if not button then return end
	
	-- Store original properties
	local originalSize = button.Size
	local originalPosition = button.Position
	local originalScale = 1
	
	local isHovering = false
	local hoverScale = 1.1 -- 10% bigger
	local moveUpDistance = UDim.new(0, -10) -- Move up 10 pixels
	
	-- Hover effect on mouse enter
	button.MouseEnter:Connect(function()
		if isHovering then return end
		isHovering = true
		
		-- Animate size increase
		button.Size = UDim2.new(
			originalSize.X.Scale * hoverScale, originalSize.X.Offset,
			originalSize.Y.Scale * hoverScale, originalSize.Y.Offset
		)
		
		-- Animate position (move higher)
		button.Position = UDim2.new(
			originalPosition.X.Scale, originalPosition.X.Offset,
			originalPosition.Y.Scale, originalPosition.Y.Offset + moveUpDistance.Offset
		)
		
		print("[ButtonAnimateModule] 🎯 Hovering over:", buttonName)
	end)
	
	-- Restore on mouse leave
	button.MouseLeave:Connect(function()
		if not isHovering then return end
		isHovering = false
		
		-- Animate size back
		button.Size = originalSize
		
		-- Animate position back
		button.Position = originalPosition
		
		print("[ButtonAnimateModule] 👋 Left:", buttonName)
	end)
end

-- Main function to setup multiple buttons
function ButtonAnimateModule.SetupButtons(buttons)
	if type(buttons) == "table" then
		for buttonName, button in pairs(buttons) do
			setupButtonAnimation(button, buttonName)
		end
	else
		setupButtonAnimation(buttons, "Button")
	end
end

-- Setup single button
function ButtonAnimateModule.SetupButton(button, buttonName)
	setupButtonAnimation(button, buttonName or "Button")
end

print("[ButtonAnimateModule] Loaded successfully")

return ButtonAnimateModule
