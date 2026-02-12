-- AttackBridge.lua
-- ModuleScript to allow other scripts to trigger a player attack

local AttackBridge = {}

local performAttackFunc = nil

function AttackBridge.setPerformAttack(func)
	performAttackFunc = func
end

function AttackBridge.triggerAttack(tool)
	if performAttackFunc then
		performAttackFunc(tool, true) -- true = ignore duel block for minigame
	end
end

return AttackBridge
