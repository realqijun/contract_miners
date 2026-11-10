--!strict
-- Mission types and their objective tuning.

export type MissionType = "Mining" | "Refinery"

local Missions = {}

Missions.TYPES = { "Mining", "Refinery" } :: { MissionType }

Missions.DISPLAY_NAME = {
	Mining = "Mining",
	Refinery = "Refinery",
} :: { [MissionType]: string }

Missions.MAX_PARTY = 4

-- Volticite to deposit, indexed by party size at launch.
Missions.MINING_TARGET = { 120, 160, 200, 200 }

-- Volticite spawned in the cave as a multiple of the target.
Missions.MINING_SURPLUS = 1.5

Missions.REFINERY_WELLS = 3
Missions.REFINERY_PUMP_SECONDS = 180
Missions.PIPE_SEGMENT_MAX = 80

Missions.LIFT_POD_COUNTDOWN = 90
Missions.RESULTS_SECONDS = 15

function Missions.isMissionType(value: unknown): boolean
	return value == "Mining" or value == "Refinery"
end

return Missions
