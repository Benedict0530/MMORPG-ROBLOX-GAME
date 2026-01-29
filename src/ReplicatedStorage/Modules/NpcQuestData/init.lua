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
			gold = 100
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
			gold = 200
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
			gold = 250
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
			gold = 500
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
		
		-- Completion dialogue (shown after quest is completed)
		completionDialogue = {
			npc = "Forest Warden",
			text = "You've done it! You've saved Grimleaf Entrance!\nBut I fear this is only the beginning...\nThere's a deeper infestation spreading to the east.\nMy brother guards the path to Grimleaf 1.\nGo to him and tell him what you've learned.\nHe will need your help to contain the Red Gloop creatures!"
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
			gold = 1000
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[6] = {
		questId = 6,
		questName = "A New Threat Emerges",
		questIcon = "🟠",
		description = "Red Gloop creatures appear in Grimleaf",
		npcName = "Forest Warden",
		mapName = "Grimleaf 1",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "Thank you for stopping the Mother Gloop...\nBut our troubles aren't over yet!"
			},
			{
				npc = "Forest Warden",
				text = "A new variant has appeared - Red Gloop creatures!\nThey seem to be adapting. Can you clear them out along with the remaining Gloop Crushers?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll handle the new threat.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Excellent! Defeat 5 Gloop Crushers and 5 Red Gloop Crushers.\nStay vigilant out there!"
				}
			}
		},
		
		-- Quest objectives (multiple objectives for different enemy types)
		objectives = {
			{
				id = 1,
				description = "Defeat 5 Gloop Crushers",
				enemyType = "Gloop Crusher",
				target = 5,
				progress = 0,
				completed = false
			},
			{
				id = 2,
				description = "Defeat 5 Red Gloop Crushers",
				enemyType = "Red Gloop Crusher",
				target = 5,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 75,
			gold = 150
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[7] = {
		questId = 7,
		questName = "Red Invasion",
		questIcon = "🔴",
		description = "More Red Gloop creatures are spreading",
		npcName = "Forest Warden",
		mapName = "Grimleaf 1",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "The Red Gloop creatures are multiplying faster than the original species!\nThey're more aggressive and harder to contain."
			},
			{
				npc = "Forest Warden",
				text = "We need a bigger push. Can you defeat 10 of them?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll stop them.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "Thank you! Defeat 10 Red Gloop Crushers.\nThe forest's survival depends on it."
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 10 Red Gloop Crushers",
				enemyType = "Red Gloop Crusher",
				target = 10,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 150,
			gold = 300
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[8] = {
		questId = 8,
		questName = "Red Onslaught",
		questIcon = "💔",
		description = "The final stand against the Red Gloop invasion",
		npcName = "Forest Warden",
		mapName = "Grimleaf 1",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Warden",
				text = "This is our final stand! The Red Gloop creatures have overrun the forest!\nWe must push back with everything we have!"
			},
			{
				npc = "Forest Warden",
				text = "I'm asking for one last massive effort from you.\nCan you defeat 20 Red Gloop creatures?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "For Grimleaf! For the forest!",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Warden",
					text = "YES! Defeat 20 Red Gloop Crushers!\nIf we succeed, we can finally reclaim our home!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 20 Red Gloop Crushers",
				enemyType = "Red Gloop Crusher",
				target = 20,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 300,
			gold = 600
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Warden"
	},
	
	[9] = {
		questId = 9,
		questName = "The Exit Secured",
		questIcon = "🌊",
		description = "Defend the exit from the Red Gloop surge",
		npcName = "Forest Guardian",
		mapName = "Grimleaf Exit",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Guardian",
				text = "Brave warrior, the Red Gloop creatures are trying to break through to the exit!\nWe need to hold the line here."
			},
			{
				npc = "Forest Guardian",
				text = "Can you defeat 30 of them to slow their advance?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll hold the line.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Guardian",
					text = "Thank you! Defeat 30 Red Gloop Crushers.\nThe exit's safety depends on your strength!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 30 Red Gloop Crushers",
				enemyType = "Red Gloop Crusher",
				target = 30,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 400,
			gold = 800
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Guardian"
	},
	
	[10] = {
		questId = 10,
		questName = "Last Stand",
		questIcon = "🔥",
		description = "Make a final desperate stand against overwhelming odds",
		npcName = "Forest Guardian",
		mapName = "Grimleaf Exit",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Guardian",
				text = "They keep coming! The infestation is relentless!\nWe're being overwhelmed by sheer numbers!"
			},
			{
				npc = "Forest Guardian",
				text = "I need you to make another stand. Can you defeat 50 Red Gloop creatures?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I won't let them through!",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Guardian",
					text = "YES! Defeat 50 Red Gloop Crushers!\nFight with everything you have!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 50 Red Gloop Crushers",
				enemyType = "Red Gloop Crusher",
				target = 50,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 700,
			gold = 1400
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Guardian"
	},
	
	[11] = {
		questId = 11,
		questName = "The Red Mother",
		questIcon = "❤️",
		description = "Defeat the source of the Red Gloop infestation",
		npcName = "Forest Guardian",
		mapName = "Grimleaf Exit",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Forest Guardian",
				text = "You've slaughtered countless Red Gloop creatures, but there's one final threat...\nThe source of this red plague - the Red Giant Gloop Crusher!"
			},
			{
				npc = "Forest Guardian",
				text = "It's absolutely monstrous and impossibly powerful.\nBut if we defeat it, the infestation will finally end.\nAre you ready for this ultimate challenge?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll end this once and for all.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Forest Guardian",
					text = "Go forth, legendary hero! Defeat the Red Giant Gloop Crusher!\nThe entire realm depends on you!"
				}
			}
		},
		
		-- Completion dialogue (shown after quest is completed)
		completionDialogue = {
			npc = "Forest Guardian",
			text = "You've done the impossible! You've saved us all!\nThe Red Gloop infestation has finally been contained.\nYou are a true hero of Grimleaf.\nMay peace return to our forest once more..."
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 1 Red Giant Gloop Crusher",
				enemyType = "Red Giant Gloop Crusher",
				target = 1,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 1500,
			gold = 2000
		},
		
		-- Quest status
		status = "available",
		questGiver = "Forest Guardian"
	},
	
	[12] = {
		questId = 12,
		questName = "Frozen Beginning",
		questIcon = "❄️",
		description = "Clear out the Ice Gloop creatures",
		npcName = "Ice Warden",
		mapName = "Frozen Realm Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Ice Warden",
				text = "Welcome to the Frozen Realm...\nBut I'm afraid you've arrived at a dark time."
			},
			{
				npc = "Ice Warden",
				text = "Ice Gloop creatures have invaded our frozen lands.\nCan you help us clear them out?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll clear the Ice Gloop creatures.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Ice Warden",
					text = "Thank you, brave warrior!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 10 Ice Gloop Crushers",
				enemyType = "Ice Gloop Crusher",
				target = 10,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 150,
			gold = 250
		},
		
		-- Quest status
		status = "available",
		questGiver = "Ice Warden"
	},
	
	[13] = {
		questId = 13,
		questName = "Frozen Advance",
		questIcon = "❄️",
		description = "More Ice Gloop creatures are spreading",
		npcName = "Ice Warden",
		mapName = "Frozen Realm Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Ice Warden",
				text = "Excellent work! But the infestation continues to spread.\nWe need a stronger push!"
			},
			{
				npc = "Ice Warden",
				text = "Can you defeat 20 of them this time?"
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
					npc = "Ice Warden",
					text = "Your strength is admirable!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 20 Ice Gloop Crushers",
				enemyType = "Ice Gloop Crusher",
				target = 20,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 200,
			gold = 400
		},
		
		-- Quest status
		status = "available",
		questGiver = "Ice Warden"
	},
	
	[14] = {
		questId = 14,
		questName = "Frozen Crisis",
		questIcon = "❄️",
		description = "The Ice Gloop infestation intensifies",
		npcName = "Ice Warden",
		mapName = "Frozen Realm Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Ice Warden",
				text = "The situation grows dire!\nThe Ice Gloop creatures multiply at an alarming rate!"
			},
			{
				npc = "Ice Warden",
				text = "We must push back harder. Can you defeat 30 of them?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I won't let them consume the realm.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Ice Warden",
					text = "You are our only hope!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 30 Ice Gloop Crushers",
				enemyType = "Ice Gloop Crusher",
				target = 30,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 400,
			gold = 500
		},
		
		-- Quest status
		status = "available",
		questGiver = "Ice Warden"
	},
	
	[15] = {
		questId = 15,
		questName = "Frozen Onslaught",
		questIcon = "❄️",
		description = "The final stand against the Ice Gloop invasion",
		npcName = "Ice Warden",
		mapName = "Frozen Realm Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Ice Warden",
				text = "This is it... our final stand!\nThe Ice Gloop creatures have overrun nearly everything!"
			},
			{
				npc = "Ice Warden",
				text = "I need one last massive effort from you.\nCan you defeat 50 of them?"
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
					npc = "Ice Warden",
					text = "For the Frozen Realm!"
				}
			}
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 50 Ice Gloop Crushers",
				enemyType = "Ice Gloop Crusher",
				target = 50,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 900,
			gold = 1200
		},
		
		-- Quest status
		status = "available",
		questGiver = "Ice Warden"
	},
	
	[16] = {
		questId = 16,
		questName = "The Frozen Mother",
		questIcon = "❄️",
		description = "Defeat the source of the Ice Gloop infestation",
		npcName = "Ice Warden",
		mapName = "Frozen Realm Entrance",
		
		-- NPC Dialogue sections
		dialogue = {
			{
				npc = "Ice Warden",
				text = "You've performed miracles, but there's one final threat...\nThe source of this infestation - the Ice Giant Gloop Crusher!"
			},
			{
				npc = "Ice Warden",
				text = "It's a towering monstrosity of ice and corruption.\nBut if we defeat it, the infestation will stop spreading.\nAre you ready for this ultimate challenge?"
			}
		},
		
		-- Player response options
		responses = {
			{
				id = 1,
				text = "I'll defeat it and free the Frozen Realm.",
				type = "accept",
				action = "acceptQuest",
				nextDialogue = {
					npc = "Ice Warden",
					text = "Go now! The fate of our realm rests in your hands!"
				}
			}
		},
		
		-- Completion dialogue (shown after quest is completed)
		completionDialogue = {
			npc = "Ice Warden",
			text = "You've done the impossible! You've saved the Frozen Realm!\nYour legend will be sung in the ice halls for generations to come.\nYou are a true hero... but I fear there are still greater dangers ahead."
		},
		
		-- Quest objectives
		objectives = {
			{
				id = 1,
				description = "Defeat 1 Ice Giant Gloop Crusher",
				enemyType = "Ice Giant Gloop Crusher",
				target = 1,
				progress = 0,
				completed = false
			}
		},
		
		-- Quest rewards
		rewards = {
			experience = 2000,
			gold = 3000
		},
		
		-- Quest status
		status = "available",
		questGiver = "Ice Warden"
	}
}

-- Map quests relationship (map name -> quest IDs)
NpcQuestData.MapQuests = {
	["Grimleaf Entrance"] = {1, 2, 3, 4, 5},
	["Grimleaf 1"] = {6, 7, 8},
	["Grimleaf Exit"] = {9, 10, 11},
	["Frozen Realm Entrance"] = {12, 13, 14, 15, 16},
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
