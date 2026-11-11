--!strict
-- Place ids of the published Contract Miners experience (universe 10775831606).

local Places = {}

Places.HUB = 100148712877412
Places.MISSION = 97544086152505

function Places.published(): boolean
	return Places.HUB ~= 0 and Places.MISSION ~= 0
end

return Places
