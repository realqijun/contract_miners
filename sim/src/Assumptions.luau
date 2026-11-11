--!strict
-- Everything the simulation must assume because the game does not state it as data: how big a
-- Vrill looks down a gun barrel, how fast a crew moves through a cave, how often it mines.
-- Geometry comes from the Vrill models (src/server/Models/Vrill.luau); pacing is an estimate the
-- second audit run should replace with playtest telemetry. Every value here is a knob, not truth.

local Assumptions = {}

export type Target = {
	-- Silhouette radius of the body (studs), and of the weakspot.
	radius: number,
	weakRadius: number,
	-- Share of the time the weakspot faces the shooter (Bulwark, Wasp and Ravager hide it behind).
	exposure: number,
	-- Share of non-weakspot hits that land on armour parts.
	armorShare: number,
	-- Typical engagement distance (studs) and sideways speed while closing (studs per second).
	distance: number,
	lateral: number,
	-- Wasps orbit out of a flamer's reach but dip close when they lose line of sight.
	nearDistance: number?,
	nearShare: number?,
}

-- From the part sizes in Vrill.luau: body and weakspot balls, armour plates seen from the front.
Assumptions.TARGETS = {
	Drone = { radius = 0.9, weakRadius = 0.6, exposure = 0.8, armorShare = 0, distance = 12, lateral = 6 },
	Warrior = { radius = 1.5, weakRadius = 0.7, exposure = 0.75, armorShare = 0.35, distance = 14, lateral = 5 },
	Bulwark = { radius = 2.6, weakRadius = 1.2, exposure = 0.25, armorShare = 0.75, distance = 16, lateral = 3 },
	Spitter = { radius = 1.8, weakRadius = 0.85, exposure = 0.9, armorShare = 0, distance = 40, lateral = 0 },
	-- Hive.hoverNear orbits at 18 studs out and 12 up (21.6 studs), dropping to 8 above without sight.
	Wasp = {
		radius = 1.0,
		weakRadius = 0.5,
		exposure = 0.35,
		armorShare = 0,
		distance = 21.6,
		lateral = 10.8,
		nearDistance = 8,
		nearShare = 0.2,
	},
	Ravager = { radius = 3.2, weakRadius = 1.1, exposure = 0.2, armorShare = 0.45, distance = 18, lateral = 4 },
} :: { [string]: Target }

-- Combat ---------------------------------------------------------------------------------------

-- Simulation step, matching the Hive's 0.1 s think rate.
Assumptions.STEP = 0.1
-- Recoil settles this many seconds after a kick; faster follow-ups inherit the residual.
Assumptions.RECOIL_RECOVERY = 0.25
-- Fastest a player clicks a semi-automatic trigger, and re-presses after a burst.
Assumptions.CLICK_INTERVAL = 0.15
Assumptions.REPRESS = 0.08
-- Seconds to swap between primary and secondary.
Assumptions.SWAP = 0.3
-- Players switch to the secondary for a Vrill type when it kills at least this much faster
-- (secondary time / primary time), while it has more than this share of its ammo left.
Assumptions.SECONDARY_ADVANTAGE = 0.6
Assumptions.SECONDARY_RESERVE = 0.25
-- Vrill crowding one crew member before an area weapon (flame cone, mortar) is preferred.
Assumptions.AREA_CROWD = 3
-- The rotary cannon's trigger is released at the client's 0.99 heat guard and held again once
-- heat falls to this level.
Assumptions.SPIN_RESUME_HEAT = 0.3
-- Players top up a magazine below this share when not firing.
Assumptions.TACTICAL_RELOAD = 0.5
-- Mean seconds of an uninterrupted firing spell (uptime gaps are drawn around it).
Assumptions.FIRING_SPELL = 2.5
-- Melee crowds form within this radius of the player they chase; area attacks hit the crowd.
Assumptions.CROWD_RADIUS = 9
-- Share of the crowd inside a flame cone: (2 x half-angle + this) / 120 degrees of approach front.
Assumptions.CONE_FRONT_BONUS = 20
Assumptions.CONE_FRONT = 120
-- Path length through caves relative to a straight line for walking Vrill.
Assumptions.PATH_FACTOR = 1.3
-- A lured pack crowds this tightly around a Decoy Beacon: share inside a 7 stud blast.
Assumptions.DECOY_PACK = 0.85
-- The width of the approach front a 15 stud fence must cover to catch everything.
Assumptions.FENCE_FRONT = 26
-- Distance from the crew at which the Mechanic strings a fence.
Assumptions.FENCE_DISTANCE = 9
-- Share of the crew standing inside a 10 stud Aegis Dome while it is up.
Assumptions.DOME_INSIDE = 0.8
-- Seconds a reviver spends reaching a downed teammate (the hold itself is Player.REVIVE_SECONDS).
Assumptions.REVIVE_TRAVEL = 3
-- Seconds to reach and fix a broken pipe segment (the hold is the repair prompt's 2 s).
Assumptions.REPAIR_TRAVEL = 8
Assumptions.REPAIR_HOLD = 2
-- Pipe segments within reach of a structure-hunting Vrill (it hits the nearest one).
Assumptions.PIPE_SEGMENT_LENGTH = 8

-- Missions -------------------------------------------------------------------------------------

-- Pacing below was set by hand toward the design's 15 to 20 minute missions; with it a mid-skill
-- crew of four finishes a Mining mission in about 12 minutes and a solo player in about 16.
-- These are the least certain numbers in the model: replace them with measured times.

-- Average travel speed through tunnels as a share of sprint speed (turns, ledges, looking).
Assumptions.TRAVEL_EFFICIENCY = 0.55
-- Walked distance relative to the shortest tunnel route: exploring with no map (dead ends,
-- backtracking), heading for an on-screen marker, or retracing a known way.
Assumptions.ROUTE_EXPLORE = 3
Assumptions.ROUTE_MARKED = 1.3
Assumptions.ROUTE_KNOWN = 1.15
-- Distance walked inside each cavern visited, as a multiple of its horizontal radius.
Assumptions.CAVERN_WALK = 1.6
-- Seconds to find and reach each Volticite vein (they sit on walls and ceilings), per miner.
Assumptions.VEIN_SEEK = 25
-- Share of a cavern's Volticite a crew gathers before moving on; the rest is too awkward to reach.
Assumptions.VEIN_REACH = 0.8
-- Extra miners help less than the first (they cluster and wait on each other).
Assumptions.MINER_EFFICIENCY = 0.75
-- Share of Ferrin nodes and health crystals in visited caverns that the crew mines.
Assumptions.FERRIN_MINED = 0.6
Assumptions.CRYSTALS_MINED = 0.7
-- Seconds per Ferrin node or health crystal mined.
Assumptions.NODE_SECONDS = 4
-- Height climbed per second when only the pickaxe is available (digging a ramp).
Assumptions.PICKAXE_CLIMB = 1.5
-- Seconds of setup per cable, and per foam step (aim, place, jump).
Assumptions.CABLE_SETUP = 1.5
Assumptions.FOAM_STEP = 0.6
-- Height gained per foam pad (a jump is about 4.5 studs).
Assumptions.FOAM_RISE = 3.5
-- Plasma Cutter ramp progress per stud of dig radius per second, before heat downtime.
Assumptions.CUTTER_RAMP = 1.4
-- Seconds from the Dropcan landing to the crew moving (orientation, first ping).
Assumptions.START_SECONDS = 20
-- Seconds to call and place the Refinery at its site (hold plus a look around).
Assumptions.REFINERY_SETUP = 15
-- Pipe-laying walk speed as a share of normal travel (looking back, re-anchoring).
Assumptions.PIPE_PACE = 0.8
-- Seconds a resupply pod takes to call, land and be used.
Assumptions.RESUPPLY_SECONDS = 15
-- A resupply is called when the crew's average ammo or health falls below this share.
Assumptions.RESUPPLY_AT = 0.4

-- Resupply pods' worth of Ferrin a Refinery crew banks before connecting the last pipe.
Assumptions.PUMP_FERRIN_BANK = 2

-- The power index finds the swarm size at which a crew of four takes this much damage per player
-- (about half of health plus shield).
Assumptions.POWER_DAMAGE = 65

-- Missions per progression cache entry, and progression careers per configuration.
Assumptions.MISSION_SAMPLES = 12
Assumptions.CAREERS = 6
Assumptions.MAX_MISSIONS = 60

return Assumptions
