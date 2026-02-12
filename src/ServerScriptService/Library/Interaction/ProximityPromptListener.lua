-- ProximityPromptListener.lua
-- Listens for all ProximityPrompt.Triggered events in Workspace and fires a callback

local ServerScriptService = game:GetService("ServerScriptService")
local ShopHandler = require(ServerScriptService:WaitForChild("Library"):WaitForChild("Shop"):WaitForChild("ShopHandler"))
local ProximityPromptListener = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Table to store connections for cleanup
local promptConnections = {}

-- Disconnect all previous connections
local function disconnectAll()
	for prompt, conn in pairs(promptConnections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
		promptConnections[prompt] = nil
	end
end


local function defaultCallback(prompt, player)
	--print("[ProximityPromptListener] Prompt triggered:", prompt:GetFullName(), "by player:", player and player.Name)

	-- If the prompt's parent is a shop, fire the client with the map parent as parameter and the prompt instance
	local parent = prompt.Parent.Parent
	if parent and parent:IsA("Model") and parent.Name == "Shop" then
		--print("[ProximityPromptListener] Shop prompt detected. Parent:", parent.Name, "MapParent:", parent.Parent and parent.Parent.Name)
		local mapParent = parent.Parent
		if mapParent then
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local shopEvent = ReplicatedStorage:FindFirstChild("ShopEvent")
			if shopEvent then
				--print("[ProximityPromptListener] Firing ShopEvent to client:", player.Name, "with map:", mapParent.Name, "and prompt:", prompt)
				shopEvent:FireClient(player, "Show", prompt, mapParent.Name)
			else
				--print("[ProximityPromptListener] ShopEvent RemoteEvent not found in ReplicatedStorage!")
			end
		else
			--print("[ProximityPromptListener] Shop's parent has no mapParent!")
		end
	end
end

local currentCallback = defaultCallback

function ProximityPromptListener.Listen(onPromptTriggered)
	disconnectAll()
	currentCallback = onPromptTriggered or defaultCallback
	for _, prompt in ipairs(Workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			promptConnections[prompt] = prompt.Triggered:Connect(function(player)
				currentCallback(prompt, player)
			end)
		end
	end
	-- Listen for new ProximityPrompts added dynamically
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			promptConnections[descendant] = descendant.Triggered:Connect(function(player)
				currentCallback(descendant, player)
			end)
		end
	end)
end

-- Auto-listen on require with default callback
ProximityPromptListener.Listen()

-- Cleanup function
function ProximityPromptListener.DisconnectAll()
	disconnectAll()
end

return ProximityPromptListener
