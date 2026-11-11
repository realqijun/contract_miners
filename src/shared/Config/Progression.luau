--!strict
-- Credits, class XP, levels and how upgrade tiers unlock. Tuned by the balance audit toward
-- linear progression: the same number of average missions per level, with credits keeping pace.

local Progression = {}

Progression.MAX_LEVEL = 5

-- Total XP needed to reach each level (level 1 is the start).
Progression.LEVEL_XP = { 0, 3000, 6000, 9000, 12000 }

-- Paid to every surviving crew member for a successful mission. With the Volticite share below, an
-- average successful mission of either type pays about 1500 credits: 12 missions buy all 15 tiers.
Progression.BASE_CREDITS = { Mining = 1330, Refinery = 1500 }
Progression.BASE_XP = { Mining = 1000, Refinery = 1000 }

-- Mining missions also pay per Volticite the whole team delivered.
Progression.CREDITS_PER_VOLTICITE = 1

-- Fractions of the full reward.
Progression.FAILURE_FRACTION = 0.25
Progression.LEFT_BEHIND_FRACTION = 0.5

-- Which upgrade tiers each level opens. Every level opens something, so progress is felt each time:
-- weapons lead and tools follow.
Progression.TIER_UNLOCKS = {
	[1] = { weapons = 1, tools = 1 },
	[2] = { weapons = 2, tools = 1 },
	[3] = { weapons = 2, tools = 2 },
	[4] = { weapons = 3, tools = 2 },
	[5] = { weapons = 3, tools = 3 },
} :: { [number]: { weapons: number, tools: number } }

-- Price of one upgrade choice in each tier.
Progression.UPGRADE_COST = { 600, 1200, 1800 }

function Progression.levelFor(xp: number): number
	local level = 1
	for index, required in Progression.LEVEL_XP do
		if xp >= required then
			level = index
		end
	end
	return level
end

-- The highest tier open for an item kind at a level. `kind` is "weapons" or "tools".
function Progression.tierOpen(level: number, kind: "weapons" | "tools"): number
	return Progression.TIER_UNLOCKS[math.clamp(level, 1, Progression.MAX_LEVEL)][kind]
end

export type Outcome = "Success" | "Failure"

-- Credits and XP for one player at the end of a mission.
function Progression.reward(
	missionType: string,
	outcome: Outcome,
	delivered: number,
	leftBehind: boolean
): (number, number)
	local credits = (Progression.BASE_CREDITS :: any)[missionType] or 0
	local xp = (Progression.BASE_XP :: any)[missionType] or 0
	if missionType == "Mining" then
		credits += delivered * Progression.CREDITS_PER_VOLTICITE
	end
	local fraction = 1
	if outcome == "Failure" then
		fraction = Progression.FAILURE_FRACTION
	elseif leftBehind then
		fraction = Progression.LEFT_BEHIND_FRACTION
	end
	return math.floor(credits * fraction + 0.5), math.floor(xp * fraction + 0.5)
end

return Progression
