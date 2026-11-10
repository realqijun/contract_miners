--!strict
-- Place ids of the published experience. Filled in when the places are published.

local Places = {}

Places.HUB = 0
Places.MISSION = 0

function Places.published(): boolean
	return Places.HUB ~= 0 and Places.MISSION ~= 0
end

return Places
