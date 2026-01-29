-- QuestDataStore.lua
-- Manages player quest progress and history
-- Tracks which quests are accepted, active, and completed

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local QuestDataStore = {}

local questStore = DataStoreService:GetDataStore("PlayerQuests")

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
			
			print("[QuestDataStore] Quest", questId, "loaded with status:", statusValue.Value)
		end
	end
	
	print("[QuestDataStore] ✅ Quest folder setup for", player.Name)
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
		print("[QuestDataStore] ⚠️ Quests folder not found for", player.Name)
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

		print("[QuestDataStore] ✅ Quest", questId, "accepted for", player.Name)
		didChange = true
	else
		-- Quest already exists, just update status if needed
		local statusValue = questValue:FindFirstChild("status")
		if statusValue and statusValue.Value ~= "completed" then
			statusValue.Value = "accepted"
			print("[QuestDataStore] ✅ Quest", questId, "marked as accepted for", player.Name)
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
		print("[QuestDataStore] ⚠️ Quests folder not found for", player.Name)
		return false
	end

	local questValue = questFolder:FindFirstChild("Quest_" .. questId)
	if not questValue then
		print("[QuestDataStore] ⚠️ Quest", questId, "not found for", player.Name)
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

		print("[QuestDataStore] ✅ Quest", questId, "completed for", player.Name)
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
		print("[QuestDataStore] ⚠️ No objective found for enemy type:", enemyType, "in quest", questId)
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
	print("[QuestDataStore] Quest", questId, "objective", objectiveIndex, "(", enemyType, ") progress updated to", progressValue.Value)

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
		print("[QuestDataStore] Quest", questId, "progress updated to", progressAmount, "for", player.Name)
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
	local data
	local success, err = pcall(function()
		data = questStore:GetAsync(key)
	end)
	
	if not success or not data then
		-- No quest data exists, create default
		data = table.clone(DEFAULT_QUEST_DATA)
		local createSuccess = pcall(function()
			questStore:SetAsync(key, data)
		end)
		if not createSuccess then
			warn("[QuestDataStore] Failed to create quest data for player " .. player.Name .. " (" .. player.UserId .. ")")
		end
	else
		-- Ensure proper structure
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
	
	print("[QuestDataStore] ✅ Quest data loaded for", player.Name)
end

-- Save quest data for player (called by UnifiedDataStoreManager)
function QuestDataStore.SaveQuestData(player)
	local key = "PlayerQuests_" .. player.UserId
	local questFolder = player:FindFirstChild("Quests")
	
	-- Convert folder structure to table
	local questsData = convertQuestFolderToTable(questFolder)
	local data = {
		quests = questsData
	}
	
	local success, err = pcall(function()
		questStore:SetAsync(key, data)
	end)
	
	if success then
		print("[QuestDataStore] ✅ Quest data saved for", player.Name)
	else
		warn("[QuestDataStore] ❌ Failed to save quest data for", player.Name, ":", err)
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
	
	print("[QuestDataStore] 🔍 Searching quests for enemy type:", enemyType, "| Normalized:", normalizedEnemyType)
	
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
						print("[QuestDataStore] ✅ Found matching quest:", questId, "for enemy:", normalizedEnemyType)
					end
					break  -- Found a match in this quest, no need to check other objectives
				end
			end
		end
	end
	
	return matchingQuests
end

-- Initialize quest data on player join
Players.PlayerAdded:Connect(function(player)
	task.wait(0.2) -- Small delay to ensure player is fully loaded
	QuestDataStore.LoadQuestData(player)
end)

print("[QuestDataStore] Quest Data Store loaded successfully")

return QuestDataStore
