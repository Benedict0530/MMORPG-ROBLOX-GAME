
-- Only run this script once per server
_G.EnemiesAutoApplyHasRun = _G.EnemiesAutoApplyHasRun or false
if _G.EnemiesAutoApplyHasRun then
	warn("[EnemiesAutoApply] Script already ran on this server. Skipping.")
	return
end
_G.EnemiesAutoApplyHasRun = true

local EnemiesManager = require(script.Parent.EnemiesModule)

local enemiesFolder = workspace:FindFirstChild("Enemies")
if enemiesFolder then
	print("[EnemiesAutoApply] Enemies folder found.")
	local foundAny = false
	for _, model in ipairs(enemiesFolder:GetChildren()) do
		if model:IsA("Model") then
			print("[EnemiesAutoApply] Initializing enemy model: " .. tostring(model.Name))
			task.spawn(EnemiesManager.Start, model)
			foundAny = true
		else
			print("[EnemiesAutoApply] Skipped non-model object: " .. tostring(model.Name) .. " (type: " .. tostring(model.ClassName) .. ")")
		end
	end
	if not foundAny then
		warn("[EnemiesAutoApply] No enemy models found in Enemies folder.")
	end
else
	warn("[EnemiesAutoApply] Enemies folder not found in Workspace!")
end
