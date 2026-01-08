-- AdminId.lua
-- Stores admin and moderator IDs with special privileges

local AdminId = {}

-- Admin/Moderator user IDs
local ADMIN_IDS = {
	[1343215966] = "verified", -- Special verified admin (gets checkmark instead of "Admin" prefix)
	[8241827218] = "admin",
	[3486958254] = "admin",
    [7581112909] = "admin",
	[5691827619] = "admin",
}

-- Check if a player is an admin
function AdminId.IsAdmin(userId)
	return ADMIN_IDS[userId] ~= nil
end

-- Get the admin type for a player
function AdminId.GetAdminType(userId)
	return ADMIN_IDS[userId]
end

-- Get all admin IDs
function AdminId.GetAllAdminIds()
	local ids = {}
	for userId, _ in pairs(ADMIN_IDS) do
		table.insert(ids, userId)
	end
	return ids
end

return AdminId
