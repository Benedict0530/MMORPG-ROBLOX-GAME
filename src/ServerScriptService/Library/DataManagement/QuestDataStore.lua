-- QuestDataStore.lua
-- Manages player quest progress and history
-- Tracks which quests are accepted, active, and completed

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local QuestDataStore = {}

local questStore = DataStoreService:GetDataStore("PlayerQuests")
print("[QuestDataStore] 🗄️ DataStore 'PlayerQuests' initialized")

-- Default quest data structure for each player
local DEFAULT_QUEST_DATA = {
	-- Quest status tracking: questId -> { status, progress, dateAccepted, dateCompleted }
	quests = {}
}

-- Setup folder structure in player for quest data
local function setupQuestFolder(player, data)
	local questFolder = Instance.new("Folder")
	questFolder.Name = "Quests"
	questFolder.Parent = player
	
	-- Store quest data as StringValue for easy access
	if data.quests and next(data.quests) then
		for questId, questData in pairs(data.quests) do
			local questValue = Instance.new("Folder")
			questValue.Name = "Quest_" .. questId
			questValue.Parent = questFolder
			
			-- Store status
			local statusValue = Instance.new("StringValue")
			statusValue.Name = "status"
			statusValue.Value = questData.status or "available"
			statusValue.Parent = questValue
			
			-- Store progress
			local progressValue = Instance.new("IntValue")
			progressValue.Name = "progress"
			progressValue.Value = questData.progress or 0
			progressValue.Parent = questValue
			
			-- Store date accepted
			local dateAcceptedValue = Instance.new("StringValue")
			dateAcceptedValue.Name = "dateAccepted"
			dateAcceptedValue.Value = questData.dateAccepted or ""
			dateAcceptedValue.Parent = questValue
			
			-- Store date completed
			local dateCompletedValue = Instance.new("StringValue")
			dateCompletedValue.Name = "dateCompleted"
			dateCompletedValue.Value = questData.dateCompleted or ""
			dateCompletedValue.Parent = questValue
			
			-- Restore ObjectiveProgress_* values from saved data
			if questData.objectiveProgress then
				for progressName, progressValue in pairs(questData.objectiveProgress) do
					local objProgressValue = Instance.new("IntValue")
					objProgressValue.Name = progressName
					objProgressValue.Value = progressValue
					objProgressValue.Parent = questValue
				end
			end
			
			--print("[QuestDataStore] Quest", questId, "loaded with status:", statusValue.Value)
		end
	end
	
	--print("[QuestDataStore] ✅ Quest folder setup for", player.Name)
end

-- Get quest status for a player
function QuestDataStore.GetQuestStatus(player, questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return "available"
	end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return "available"
	end
	
	local statusValue = questValue:FindFirstChild("status")
	return statusValue and statusValue.Value or "available"
end

-- Check if quest is completed
function QuestDataStore.IsQuestCompleted(player, questId)
	return QuestDataStore.GetQuestStatus(player, questId) == "completed"
end

-- Check if quest is accepted
function QuestDataStore.IsQuestAccepted(player, questId)
	local status = QuestDataStore.GetQuestStatus(player, questId)
	return status == "accepted" or status == "active"
end

-- Accept a quest (called when player clicks "I'll take care of them")
function QuestDataStore.AcceptQuest(player, questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		--print("[QuestDataStore] ⚠️ Quests folder not found for", player.Name)
		return false
	end

	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	local didChange = false
	if not questValue then
		-- Create new quest entry
		questValue = Instance.new("Folder")
		questValue.Name = "Quest_" .. questId
		questValue.Parent = questFolder

		-- Status
		local statusValue = Instance.new("StringValue")
		statusValue.Name = "status"
		statusValue.Value = "accepted"
		statusValue.Parent = questValue

		-- Progress
		local progressValue = Instance.new("IntValue")
		progressValue.Name = "progress"
		progressValue.Value = 0
		progressValue.Parent = questValue

		-- Date accepted
		local dateAcceptedValue = Instance.new("StringValue")
		dateAcceptedValue.Name = "dateAccepted"
		dateAcceptedValue.Value = os.date("%Y-%m-%d %H:%M:%S")
		dateAcceptedValue.Parent = questValue

		-- Date completed (empty)
		local dateCompletedValue = Instance.new("StringValue")
		dateCompletedValue.Name = "dateCompleted"
		dateCompletedValue.Value = ""
		dateCompletedValue.Parent = questValue

		--print("[QuestDataStore] ✅ Quest", questId, "accepted for", player.Name)
		didChange = true
	else
		-- Quest already exists, just update status if needed
		local statusValue = questValue:FindFirstChild("status")
		if statusValue and statusValue.Value ~= "completed" then
			statusValue.Value = "accepted"
			--print("[QuestDataStore] ✅ Quest", questId, "marked as accepted for", player.Name)
			didChange = true
		end
	end

	-- Mark quest data as pending for save if changed
	if didChange then
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		UnifiedDataStoreManager.MarkQuestDataPending(player.UserId)
		return true
	end
	return false
end

-- Complete a quest (called when player defeats required enemies)
function QuestDataStore.CompleteQuest(player, questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		--print("[QuestDataStore] ⚠️ Quests folder not found for", player.Name)
		return false
	end

	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		--print("[QuestDataStore] ⚠️ Quest", questId, "not found for", player.Name)
		return false
	end

	local statusValue = questValue:FindFirstChild("status")
	if statusValue then
		statusValue.Value = "completed"

		-- Set completion date
		local dateCompletedValue = questValue:FindFirstChild("dateCompleted")
		if dateCompletedValue then
			dateCompletedValue.Value = os.date("%Y-%m-%d %H:%M:%S")
		end

		--print("[QuestDataStore] ✅ Quest", questId, "completed for", player.Name)
		-- Mark quest data as pending for save
		local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
		UnifiedDataStoreManager.MarkQuestDataPending(player.UserId)
		return true
	end

	return false
end

-- Get quest progress
function QuestDataStore.GetQuestProgress(player, questId)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return 0
	end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return 0
	end
	
	local progressValue = questValue:FindFirstChild("progress")
	return progressValue and progressValue.Value or 0
end

-- Update quest progress for a specific enemy type (for multi-objective quests)
function QuestDataStore.UpdateQuestProgressByEnemyType(player, questId, enemyType, incrementAmount)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return
	end

	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return
	end

	-- Get the quest data to find which objective matches this enemy type
	local NpcQuestData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("NpcQuestData"))
	local quest = NpcQuestData.GetQuest(questId)
	if not quest or not quest.objectives then
		return
	end

	-- Find which objective matches this enemy type
	local objectiveIndex = nil
	for idx, objective in ipairs(quest.objectives) do
		if objective.enemyType == enemyType then
			objectiveIndex = idx
			break
		end
	end

	if not objectiveIndex then
		--print("[QuestDataStore] ⚠️ No objective found for enemy type:", enemyType, "in quest", questId)
		return
	end

	-- Create or update the progress value for this specific objective
	local progressValueName = "ObjectiveProgress_" .. objectiveIndex
	local progressValue = questValue:FindFirstChild(progressValueName)

	if not progressValue then
		progressValue = Instance.new("IntValue")
		progressValue.Name = progressValueName
		progressValue.Value = 0
		progressValue.Parent = questValue
	end

	-- Increment the progress
	progressValue.Value = progressValue.Value + incrementAmount
	--print("[QuestDataStore] Quest", questId, "objective", objectiveIndex, "(", enemyType, ") progress updated to", progressValue.Value)

	-- Mark quest data as pending for save
	local UnifiedDataStoreManager = require(ServerScriptService:WaitForChild("Library"):WaitForChild("DataManagement"):WaitForChild("UnifiedDataStoreManager"))
	UnifiedDataStoreManager.MarkQuestDataPending(player.UserId)
end

-- Update quest progress (legacy - for single objective quests)
function QuestDataStore.UpdateQuestProgress(player, questId, progressAmount)
	local questFolder = player:FindFirstChild("Quests")
	if not questFolder then
		return
	end
	
	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		return
	end
	
	local progressValue = questValue:FindFirstChild("progress")
	if progressValue then
		progressValue.Value = progressAmount
		--print("[QuestDataStore] Quest", questId, "progress updated to", progressAmount, "for", player.Name)
	end
end

-- Convert folder data to table for saving
local function convertQuestFolderToTable(questFolder)
	local questsData = {}
	
	if questFolder then
		for _, questValue in ipairs(questFolder:GetChildren()) do
			if questValue:IsA("Folder") and string.match(questValue.Name, "Quest_") then
				local questId = tonumber(string.sub(questValue.Name, 7))
				
				local statusValue = questValue:FindFirstChild("status")
				local progressValue = questValue:FindFirstChild("progress")
				local dateAcceptedValue = questValue:FindFirstChild("dateAccepted")
				local dateCompletedValue = questValue:FindFirstChild("dateCompleted")
				
				questsData[questId] = {
					status = statusValue and statusValue.Value or "available",
					progress = progressValue and progressValue.Value or 0,
					dateAccepted = dateAcceptedValue and dateAcceptedValue.Value or "",
					dateCompleted = dateCompletedValue and dateCompletedValue.Value or "",
					objectiveProgress = {} -- Store all objective progress values
				}
				
				-- Save all ObjectiveProgress_* values
				for _, child in ipairs(questValue:GetChildren()) do
					if string.match(child.Name, "ObjectiveProgress_") and child:IsA("IntValue") then
						questsData[questId].objectiveProgress[child.Name] = child.Value
					end
				end
			end
		end
	end
	
	return questsData
end

-- Load quest data for player
function QuestDataStore.LoadQuestData(player)
	local key = "PlayerQuests_" .. player.UserId
	print("[QuestDataStore] 🔍 Loading quest data for", player.Name, "with key:", key)
	
	local data
	local success, err = pcall(function()
		data = questStore:GetAsync(key)
	end)
	
	if not success then
		warn("[QuestDataStore] ❌ Failed to load quest data for", player.Name, ":", err)
		if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			warn("[QuestDataStore] ⚠️  Studio Access to API Services may be DISABLED!")
		end
		data = nil
	end
	
	if not data then
		-- No quest data exists, create default
		print("[QuestDataStore] 📝 No existing quest data found, creating default for", player.Name)
		data = table.clone(DEFAULT_QUEST_DATA)
		local createSuccess, createErr = pcall(function()
			questStore:SetAsync(key, data)
		end)
		if createSuccess then
			print("[QuestDataStore] ✅ Created new quest datastore entry for", player.Name)
		else
			warn("[QuestDataStore] ❌ Failed to create quest data for player", player.Name, "(" .. player.UserId .. "):", createErr)
			if tostring(createErr):find("502") or tostring(createErr):find("API Services") or tostring(createErr):find("Studio") then
				warn("[QuestDataStore] ⚠️  Studio Access to API Services may be DISABLED!")
			end
		end
	else
		-- Ensure proper structure
		print("[QuestDataStore] ✅ Loaded existing quest data for", player.Name, "| Quests count:", data.quests and #data.quests or 0)
		if not data.quests then
			data.quests = {}
		end
	end
	
	-- Remove any existing Quests folder
	local oldQuests = player:FindFirstChild("Quests")
	if oldQuests then
		oldQuests:Destroy()
	end
	
	-- Setup quest folder with loaded data
	setupQuestFolder(player, data)
	
	print("[QuestDataStore] ✅ Quest folder setup complete for", player.Name)
end

-- Save quest data for player (called by UnifiedDataStoreManager)
function QuestDataStore.SaveQuestData(player)
	local key = "PlayerQuests_" .. player.UserId
	local questFolder = player:FindFirstChild("Quests")
	
	print("[QuestDataStore] 💾 Saving quest data for", player.Name, "with key:", key)
	
	-- Convert folder structure to table
	local questsData = convertQuestFolderToTable(questFolder)
	local data = {
		quests = questsData
	}
	
	print("[QuestDataStore] 📊 Quest data to save:", #questsData, "quests")
	
	local success, err = pcall(function()
		questStore:SetAsync(key, data)
	end)
	
	if success then
		print("[QuestDataStore] ✅ Quest data saved successfully for", player.Name)
	else
		warn("[QuestDataStore] ❌ Failed to save quest data for", player.Name, ":", err)
		if tostring(err):find("502") or tostring(err):find("API Services") or tostring(err):find("Studio") then
			warn("[QuestDataStore] ⚠️  Studio Access to API Services may be DISABLED!")
		end
	end
	
	return success
end

-- Get quests that are affected by killing a specific enemy type
-- Returns a table of questIds that have objectives matching the enemy
-- Uses EXACT name matching, not substring matching
function QuestDataStore.GetQuestsByEnemyType(enemyType)
	local NpcQuestData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("NpcQuestData"))
	local matchingQuests = {}
	
	-- Normalize the enemy type for comparison (remove trailing numbers and spaces)
	local normalizedEnemyType = string.gsub(enemyType, "%d+$", "") -- Remove trailing digits
	normalizedEnemyType = string.gsub(normalizedEnemyType, "%s+$", "") -- Remove trailing spaces
	
	--print("[QuestDataStore] 🔍 Searching quests for enemy type:", enemyType, "| Normalized:", normalizedEnemyType)
	
	-- Loop through ALL quests and check if they have an objective matching this enemy type
	for questId = 1, 100 do  -- Check up to 100 quests (you can adjust this number)
		local quest = NpcQuestData.GetQuest(questId)
		if not quest then break end  -- No more quests
		
		-- Check if this quest has any objectives matching the enemy type
		if quest.objectives then
			for _, objective in ipairs(quest.objectives) do
				-- Use exact match (==) for enemy type (case-insensitive)
				if objective.enemyType and objective.enemyType:lower() == normalizedEnemyType:lower() then
					if not table.find(matchingQuests, questId) then
						table.insert(matchingQuests, questId)
						--print("[QuestDataStore] ✅ Found matching quest:", questId, "for enemy:", normalizedEnemyType)
					end
					break  -- Found a match in this quest, no need to check other objectives
				end
			end
		end
	end
	
	return matchingQuests
end

-- Reset quest data for a specific player
function QuestDataStore.ResetPlayerQuests(player)
	if not player then
		warn("[QuestDataStore] ❌ No player provided to ResetPlayerQuests")
		return false
	end
	
	local key = "PlayerQuests_" .. player.UserId
	
	-- 1. Remove existing Quests folder
	local questFolder = player:FindFirstChild("Quests")
	if questFolder then
		questFolder:Destroy()
		print("[QuestDataStore] 🗑️ Removed Quests folder for", player.Name)
	end
	
	-- 2. Create fresh default data
	local freshData = table.clone(DEFAULT_QUEST_DATA)
	
	-- 3. Save to DataStore (overwrites existing data)
	local success, err = pcall(function()
		questStore:SetAsync(key, freshData)
	end)
	
	if not success then
		warn("[QuestDataStore] ❌ Failed to reset quest data for", player.Name, ":", err)
		return false
	end
	
	-- 4. Setup new empty quest folder
	setupQuestFolder(player, freshData)
	
	print("[QuestDataStore] ✅ Quest data reset for", player.Name)
	return true
end

-- WIPE ENTIRE QUEST DATASTORE FOR ALL PLAYERS (DANGEROUS!)
function QuestDataStore.WipeAllQuestData()
	warn("[QuestDataStore] ⚠️⚠️⚠️ WIPING ENTIRE QUEST DATASTORE ⚠️⚠️⚠️")
	
	local successCount = 0
	local failureCount = 0
	
	-- Reset all currently online players
	for _, player in ipairs(Players:GetPlayers()) do
		local success = QuestDataStore.ResetPlayerQuests(player)
		if success then
			successCount = successCount + 1
		else
			failureCount = failureCount + 1
		end
	end
	
	warn("[QuestDataStore] 🗑️ Complete - Reset " .. successCount .. " players, " .. failureCount .. " failures")
	warn("[QuestDataStore] ⚠️ Note: Only ONLINE players were reset. Offline players will keep their quest data until they join and get manually reset.")
	
	return successCount, failureCount
end

--  QuestDataStore.WipeAllQuestData()

-- Initialize quest data on player join
-- PlayerAdded handler moved to Init.server.lua for centralized initialization

--print("[QuestDataStore] Quest Data Store loaded successfully")

return QuestDataStore
