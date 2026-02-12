

-- Wait for server initialization complete before requiring client modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local modulesRequired = false
local function requireAllModules()
   if modulesRequired then return end
   modulesRequired = true
   local thisScript = script
   for _, child in ipairs(thisScript:GetChildren()) do
	   if child:IsA("ModuleScript") then
		   local ok, result = pcall(function() return require(child) end)
		   if ok then
			   --print("[ClientHandler] Loaded module:", child.Name)
		   else
			   warn("[ClientHandler] Failed to load module:", child.Name, result)
		   end
	   end
   end
   -- Fire DClientModulesReady BindableEvent after all modules are required
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local dClientModulesReady = ReplicatedStorage:FindFirstChild("DClientModulesReady")
   if not dClientModulesReady then
	   dClientModulesReady = Instance.new("BindableEvent")
	   dClientModulesReady.Name = "DClientModulesReady"
	   dClientModulesReady.Parent = ReplicatedStorage
   end
   if dClientModulesReady and dClientModulesReady:IsA("BindableEvent") then
	   dClientModulesReady:Fire()
   end
end

-- Wait for the ServerReady RemoteEvent
local serverReadyEvent = ReplicatedStorage:FindFirstChild("ServerReady")
if serverReadyEvent then
	-- Listen for the event (server should fire to all clients when ready)
	serverReadyEvent.OnClientEvent:Connect(function()
		requireAllModules()
	end)
	-- Fallback: If the event was already fired before this script ran, require after short delay
	task.delay(2, function()
		requireAllModules()
	end)
else
	-- If event not found, fallback to requiring after short wait
	warn("[ClientHandler] ServerReady event not found! Proceeding after 5 seconds as fallback.")
	task.wait(5)
	requireAllModules()
end
