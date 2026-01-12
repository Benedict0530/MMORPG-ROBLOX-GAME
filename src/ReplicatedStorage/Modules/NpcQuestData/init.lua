-- NpcQuestData.lua
-- Stores all NPC quest dialogue and data

local NpcQuestData = {}

-- Quest data structure
NpcQuestData.Quests = {
	[1] = {
		questId = 1,
		questName = "Sticky Beginnings",
		questIcon = "🟢",
		description = "Clear out the sticky Gloop creatures",
		npcName = "Forest Warden",
		mapName = "Grimleaf Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "Adventurer… the forest is acting strange.\nA sticky creature called Gloop is leaking from the ground."
			},
			{
				npc = "Forest Warden",
				text = "They are weak now, but they spread fast.\nCan you clear them out?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll take care of them.",
				type = "accept", -- accept, question, decline
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Thank you, brave adventurer!\nYou must defeat 10 Gloop creatures."
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 10 Gloop Crushers",
				enemyType = "Gloop Crusher", -- Type of enemy that counts toward this objective
				target = 10,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 50,
			gold = 250
		},
		
		-- Quest status
		status = "available", -- available, accepted, completed, failed
		questGiver = "Forest Warden"
	},
	
	[2] = {
		questId = 2,
		questName = "Growing Threat",
		questIcon = "🟡",
		description = "More Gloop creatures are appearing",
		npcName = "Forest Warden",
		mapName = "Grimleaf Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "Good work, but more are coming!\nThe infestation is spreading faster than before."
			},
			{
				npc = "Forest Warden",
				text = "I need you to eliminate more of them.\nCan you handle 20 this time?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'm ready for more.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Excellent! Defeat 20 Gloop creatures.\nThe threat grows with each passing moment."
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 20 Gloop Crushers",
				enemyType = "Gloop Crusher",
				target = 20,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 100,
			gold = 500
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[3] = {
		questId = 3,
		questName = "The Infection Spreads",
		questIcon = "🔴",
		description = "The Gloop infestation is rapidly growing",
		npcName = "Forest Warden",
		mapName = "Grimleaf Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "This is worse than I feared...\nThe Gloop creatures are multiplying exponentially!"
			},
			{
				npc = "Forest Warden",
				text = "We need to push back harder.\nCan you defeat 30 of them?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I won't let them take over.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "That's the spirit! Defeat 30 Gloop creatures.\nThe fate of the forest rests in your hands."
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 30 Gloop Crushers",
				enemyType = "Gloop Crusher",
				target = 30,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 200,
			gold = 1000
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[4] = {
		questId = 4,
		questName = "Critical Point",
		questIcon = "🟣",
		description = "The infestation reaches critical levels",
		npcName = "Forest Warden",
		mapName = "Grimleaf Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "We're running out of time!\nThe Gloop creatures have infested the entire forest!"
			},
			{
				npc = "Forest Warden",
				text = "I need one final massive push.\nCan you defeat 50 of them?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll do whatever it takes.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Thank you! Defeat 50 Gloop creatures.\nIf we succeed, we can contain this..."
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 50 Gloop Crushers",
				enemyType = "Gloop Crusher",
				target = 50,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 500,
			gold = 2500
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[5] = {
		questId = 5,
		questName = "The Mother",
		questIcon = "💜",
		description = "Defeat the mother of all Gloop creatures",
		npcName = "Forest Warden",
		mapName = "Grimleaf Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "You've done well, but there's one more threat...\nThe source of this infestation - the Giant Gloop Crusher!"
			},
			{
				npc = "Forest Warden",
				text = "It's massive and incredibly dangerous.\nBut if we defeat it, the infestation will stop spreading.\nAre you ready?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll defeat it and end this.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Go forth, hero! Defeat the Giant Gloop Crusher.\nThe fate of Grimleaf depends on you!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 1 Giant Gloop Crusher",
				enemyType = "Giant Gloop Crusher",
				target = 1,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 1000,
			gold = 5000
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	}
}

-- Map quests relationship (map name -> quest IDs)
NpcQuestData.MapQuests = {
	["Grimleaf Entrance"] = {1, 2, 3, 4, 5},
	["Grimleaf 1"] = {1, 2, 3, 4, 5},
	["Frozen Realm"] = 2,
	-- Add more maps and their corresponding quests here
}

-- Function to get quest by ID
function NpcQuestData.GetQuest(questId)
	return NpcQuestData.Quests[questId]
end

-- Function to get quest by map name (returns first quest in chain)
function NpcQuestData.GetQuestByMapName(mapName)
	local questIds = NpcQuestData.MapQuests[mapName]
	if not questIds then return nil end
	
	-- If it's a table (quest chain), return the first quest
	if type(questIds) == "table" then
		return NpcQuestData.GetQuest(questIds[1])
	else
		-- If it's a single quest ID, return that quest
		return NpcQuestData.GetQuest(questIds)
	end
end

-- Function to get the next available quest in a map's quest chain
-- Returns the first incomplete quest, or nil if all are completed
function NpcQuestData.GetNextAvailableQuestByMapName(mapName, player)
	local questIds = NpcQuestData.MapQuests[mapName]
	if not questIds then return nil end
	
	-- If it's a single quest, just return it
	if type(questIds) ~= "table" then
		return NpcQuestData.GetQuest(questIds)
	end
	
	-- For quest chains, find the first incomplete quest
	if player then
		for _, questId in ipairs(questIds) do
			local questFolder = player:FindFirstChild("Quests")
			if questFolder then
				local questValue = questFolder:FindFirstChild("Quest_" .. questId)
				if not questValue then
					-- Quest not started yet, return this one
					return NpcQuestData.GetQuest(questId)
				else
					-- Check if completed
					local statusValue = questValue:FindFirstChild("status")
					if statusValue and statusValue.Value ~= "completed" then
						-- Quest not completed, return this one
						return NpcQuestData.GetQuest(questId)
					end
				end
			end
		end
		-- All quests completed
		return nil
	else
		-- No player provided, return first quest
		return NpcQuestData.GetQuest(questIds[1])
	end
end

-- Function to get all quests for a map (for quest chains)
function NpcQuestData.GetAllQuestsByMapName(mapName)
	local questIds = NpcQuestData.MapQuests[mapName]
	if not questIds then return {} end
	
	-- If it's a table (quest chain), return all quests
	if type(questIds) == "table" then
		local quests = {}
		for _, questId in ipairs(questIds) do
			table.insert(quests, NpcQuestData.GetQuest(questId))
		end
		return quests
	else
		-- If it's a single quest ID, return it wrapped in a table
		return {NpcQuestData.GetQuest(questIds)}
	end
end

-- Function to get quest dialogue
function NpcQuestData.GetDialogue(questId, dialogueIndex)
	local quest = NpcQuestData.GetQuest(questId)
	if quest and quest.dialogue then
		return quest.dialogue[dialogueIndex or 1]
	end
	return nil
end

-- Function to get quest responses
function NpcQuestData.GetResponses(questId)
	local quest = NpcQuestData.GetQuest(questId)
	if quest then
		return quest.responses
	end
	return {}
end

-- Function to get quest rewards
function NpcQuestData.GetRewards(questId)
	local quest = NpcQuestData.GetQuest(questId)
	if quest then
		return quest.rewards
	end
	return nil
end

print("[NpcQuestData] Quest data loaded successfully")

return NpcQuestData
