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
		return true
	end
	
	-- Quest already exists, just update status if needed
	local statusValue = questValue:FindFirstChild("status")
	if statusValue and statusValue.Value ~= "completed" then
		statusValue.Value = "accepted"
		print("[QuestDataStore] ✅ Quest", questId, "marked as accepted for", player.Name)
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

-- Update quest progress (for tracking kills, etc)
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
					dateCompleted = dateCompletedValue and dateCompletedValue.Value or ""
				}
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
function QuestDataStore.GetQuestsByEnemyType(enemyType)
	-- Map enemy types to quest IDs and objectives
	-- This can be expanded as you add more quests
	local enemyQuestMap = {
		["Gloop Crusher"] = {
			questIds = {1, 2, 3, 4}, -- Quests 1-4: All involve killing Gloop Crusher
			enemyNames = {"Gloop Crusher", "gloop crusher", "Gloop", "gloop", "slime", "Slime"}
		},
		["Giant Gloop Crusher"] = {
			questIds = {5}, -- Quest 5: Kill 1 Giant Gloop Crusher
			enemyNames = {"Giant Gloop Crusher", "giant gloop crusher", "giant gloop", "Giant Gloop"}
		},
		["Spider"] = {
			questIds = {}, -- Future quest
			enemyNames = {"Spider", "spider"}
		},
		-- Add more enemy types and their corresponding quests here
	}
	
	-- Search for matching quest(s) based on enemy type
	local matchingQuests = {}
	for enemyKey, questData in pairs(enemyQuestMap) do
		for _, name in ipairs(questData.enemyNames) do
			if enemyType:lower():find(name:lower()) then
				for _, questId in ipairs(questData.questIds) do
					if not table.find(matchingQuests, questId) then
						table.insert(matchingQuests, questId)
					end
				end
				return matchingQuests
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
