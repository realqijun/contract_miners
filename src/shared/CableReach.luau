--!strict
-- How far a miner standing at a position is from a Heavy Weapons cable, measured from the closest
-- point of the body, feet to just above the head, so a cable can be caught overhead from below or
-- at the feet from its top end. The client grabs cables with it and the server's movement checks
-- recognise riders with it.

local ToolsConfig = require(script.Parent.Config.Tools)

local CableReach = {}

-- The body spans this far below the root (the feet) up to CABLE_HANG above it.
local FEET = 3
local SAMPLES = 5

-- The distance from the body at `position` (a root position) to the cable from `a` to `b`, and how
-- far along the cable, from 0 at `a` to 1 at `b`, that closest point is.
function CableReach.measure(position: Vector3, a: Vector3, b: Vector3): (number, number)
	local ab = b - a
	local bestDistance, bestT = math.huge, 0
	for step = 0, SAMPLES - 1 do
		local reach = position + Vector3.yAxis * (-FEET + (FEET + ToolsConfig.CABLE_HANG) * step / (SAMPLES - 1))
		local t = math.clamp((reach - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local distance = (a + ab * t - reach).Magnitude
		if distance < bestDistance then
			bestDistance, bestT = distance, t
		end
	end
	return bestDistance, bestT
end

return CableReach
