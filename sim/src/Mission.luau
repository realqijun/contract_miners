--!strict
-- A whole mission on a real generated cave (the game's own Cave/Layout module): travel between
-- caverns with the crew's climbing tools, mining or Refinery pipe-laying, ambient Vrill and
-- Spitters met along the way, timed swarms on the Spawner's clock, resupplies bought with Ferrin,
-- the objective swarms, and the Lift Pod countdown. Rewards come from Progression.reward.
--
-- Mirrored server rules (logic, not numbers): the Refinery site score and the three wells furthest
-- from it (RefineryMission.chooseSite/placeWells), the Lift Pod landing in the cavern furthest from
-- the crew (Extraction.chooseLandingSite), and Volticite spread by cavern volume with the landing
-- cavern weighted 0.15 (Deposits.placeVolticite).

local Arena = require("./Arena")
local Assumptions = require("./Assumptions")
local Crew = require("./Crew")
local Game = require("./Game")
local Loader = require("./Loader")
local Rng = require("./Rng")

local Layout = Loader.require("src/shared/Cave/Layout")
local Vector3 = (require("@lune/roblox") :: any).Vector3

local Server = Game.Server
local Missions = Game.Missions
local Resources = Game.Resources
local EnemiesConfig = Game.Enemies

local Mission = {}

local JUMP_HEIGHT = Game.Player.JUMP_POWER ^ 2 / (2 * 196.2)
local LANDING_WEIGHT = Loader.literal(
	"src/server/Mission/Deposits.luau",
	"if index == world%.layout%.startCavern then volume %* ([%d%.]+)"
)

export type Result = {
	outcome: "Success" | "Failure",
	-- Where a failed mission fell apart.
	phase: string,
	delivered: number,
	seconds: number,
	leftBehind: { [number]: boolean },
	swarmDamage: { number },
	swarms: number,
	downs: number,
	resupplies: number,
	rewards: { { credits: number, xp: number } },
	breakdown: { travel: number, work: number, fight: number },
}

-- Climbing --------------------------------------------------------------------------------------

type Climb = { rate: number, shared: boolean, capacity: number }

-- Height per second a traversal tool climbs, whether teammates can use what it builds, and how
-- much height one load of charges covers.
local function climbOf(toolId: string, stats: any): Climb
	if toolId == "FoamProjector" then
		local rate = Assumptions.FOAM_RISE
			/ math.max(stats.cooldown, Assumptions.FOAM_STEP)
			* (1 + (stats.padDiameter - 5) * 0.05)
			* (stats.range / 45) ^ 0.2
		return {
			rate = rate,
			shared = true,
			capacity = stats.charges * Assumptions.FOAM_RISE + stats.regenPerSecond * 600,
		}
	elseif toolId == "GrappleLine" then
		local rate = stats.range / math.max(stats.cooldown, stats.range / stats.pullSpeed + 0.5)
		return { rate = rate, shared = false, capacity = math.huge }
	elseif toolId == "CableLauncher" then
		local rise = stats.range * math.sin(math.rad(math.min(stats.maxAngle, 80)))
		local rate = rise / (Assumptions.CABLE_SETUP + stats.range / stats.rideSpeed)
		return { rate = rate, shared = true, capacity = (stats.charges + stats.regenPerSecond * 600) * rise }
	elseif toolId == "PlasmaCutter" then
		local burst = math.min(1, stats.coolPerSecond * math.max(0, stats.overheatLockout - 0.3)) / stats.heatPerTick
		local fireTime = math.max(burst, 1) * stats.cooldown
		local duty = fireTime / (fireTime + stats.overheatLockout)
		local rate = stats.digRadius * Assumptions.CUTTER_RAMP * duty * (1 + (stats.range - 14) / 40)
		return { rate = rate, shared = true, capacity = math.huge }
	end
	return { rate = Assumptions.PICKAXE_CLIMB, shared = false, capacity = math.huge }
end

Mission.climbOf = climbOf

-- The crew climbs as fast as its slowest member: each uses their own tool or a teammate's shared
-- one, whichever is quicker.
local function crewClimb(crew: { Crew.Member }): (number, number)
	local sharedRate, sharedCapacity = 0, 0
	local climbs = {}
	for _, member in crew do
		local climb = climbOf(member.kit.traversal, member.traversal)
		climbs[member] = climb
		if climb.shared and climb.rate > sharedRate then
			sharedRate, sharedCapacity = climb.rate, climb.capacity
		end
	end
	local slowest = math.huge
	for _, member in crew do
		local own = climbs[member].rate
		slowest = math.min(slowest, math.max(own, sharedRate, Assumptions.PICKAXE_CLIMB))
	end
	return slowest, if sharedRate > 0 then sharedCapacity else math.huge
end

-- Lumen Darts shorten the search for veins.
local function seekFactor(crew: { Crew.Member }): number
	local best = 1
	for _, member in crew do
		if member.kit.support == "LumenDarts" then
			local stats = member.support
			local factor = 1
				- 0.12 * stats.revealRadius / 20
				- 0.06 * stats.revealSeconds / 8
				- 0.04 * stats.lightRange / 48
				- 0.03 * stats.lifetime / 60
				- 0.02 * (stats.charges / 8 + stats.regenPerSecond * 12) / 2
			best = math.min(best, factor)
		end
	end
	return best
end

Mission.seekFactor = seekFactor

-- The cave graph -------------------------------------------------------------------------------

type Edge = { to: number, length: number, climb: number }

local function insideCavern(cavern: any, point: Vector3): boolean
	local offset = point - cavern.center
	local r = cavern.radii
	return (offset.X / r.X) ^ 2 + (offset.Y / r.Y) ^ 2 + (offset.Z / r.Z) ^ 2 <= 1
end

local function buildGraph(layout: any): { [number]: { Edge } }
	local graph = {}
	for index in layout.caverns do
		graph[index] = {}
	end
	for _, tunnel in layout.tunnels do
		local points = tunnel.points
		local length = 0
		for index = 2, #points do
			length += (points[index] - points[index - 1]).Magnitude
		end
		-- The mouth is where the tunnel leaves each cavern; climbing into it is the hard part.
		local function mouthClimb(cavernIndex: number, forward: boolean): number
			local cavern = layout.caverns[cavernIndex]
			local first, last, step = 1, #points, 1
			if not forward then
				first, last, step = #points, 1, -1
			end
			for index = first, last, step do
				if not insideCavern(cavern, points[index]) then
					local floor = points[index].Y - tunnel.radius
					return math.max(0, floor - cavern.floorY - JUMP_HEIGHT)
				end
			end
			return 0
		end
		table.insert(graph[tunnel.from], { to = tunnel.to, length = length, climb = mouthClimb(tunnel.from, true) })
		table.insert(graph[tunnel.to], { to = tunnel.from, length = length, climb = mouthClimb(tunnel.to, false) })
	end
	return graph
end

-- Shortest travel (seconds and height climbed) from one cavern to every other.
local function travelFrom(
	graph: any,
	start: number,
	speed: number,
	climbRate: number
): ({ number }, { number }, { number })
	local time, climb, previous = {}, {}, {}
	local done = {}
	for index in graph do
		time[index] = math.huge
		climb[index] = 0
	end
	time[start] = 0
	while true do
		local current, best = nil, math.huge
		for index, value in time do
			if not done[index] and value < best then
				current, best = index, value
			end
		end
		if not current then
			break
		end
		done[current] = true
		for _, edge in graph[current] do
			local cost = edge.length / speed + edge.climb / climbRate
			if time[current] + cost < time[edge.to] then
				time[edge.to] = time[current] + cost
				climb[edge.to] = climb[current] + edge.climb
				previous[edge.to] = current
			end
		end
	end
	return time, climb, previous
end

local function pathLength(graph: any, previous: { number }, start: number, goal: number): number
	local length, current = 0, goal
	while current ~= start and previous[current] do
		local from = previous[current]
		for _, edge in graph[from] do
			if edge.to == current then
				length += edge.length
				break
			end
		end
		current = from
	end
	return length
end

-- The mission ----------------------------------------------------------------------------------

export type Options = {
	crew: { Crew.Member },
	missionType: string,
	seed: number,
	rng: Rng.Rng,
}

function Mission.run(options: Options): Result
	local crew = options.crew
	local rng = options.rng
	local partySize = #crew
	local missionType = options.missionType
	local layout = Layout.generate(options.seed)
	local graph = buildGraph(layout)
	local caverns = layout.caverns

	local pace = math.huge
	for _, member in crew do
		pace = math.min(pace, member.band.pace)
	end
	local speed = Game.Player.SPRINT_SPEED * Assumptions.TRAVEL_EFFICIENCY * pace
	local climbRate, climbCapacity = crewClimb(crew)
	local climbBudget = climbCapacity

	local clock = Assumptions.START_SECONDS
	-- The team's Ferrin pool, shared with fights so a pod can be called mid-swarm.
	local pool = { ferrin = 0, resupplies = 0 }
	-- Where the time goes: walking and climbing, mining and objective work, fighting.
	local breakdown = { travel = 0, work = 0, fight = 0 }
	local swarmDamage = {}
	local swarmCount = 0
	local nextSwarm = rng:range(EnemiesConfig.SWARM_INTERVAL[1], EnemiesConfig.SWARM_INTERVAL[2])
	local failed: string? = nil
	local delivered = 0

	-- Sleeping Vrill per cavern, from the generation rules (Spawner.placeAmbient).
	local ambient = {}
	for index in caverns do
		local present = {}
		if index ~= layout.startCavern then
			local groups = EnemiesConfig.AMBIENT_PER_CAVERN
			for _ = 1, rng:int(groups[1], groups[2]) do
				local enemyType = if rng:next() < 0.65 then "Drone" else "Warrior"
				for _ = 1, rng:int(2, 3) do
					table.insert(present, { type = enemyType, distance = rng:range(25, 45) })
				end
			end
			local spitters = EnemiesConfig.SPITTERS_PER_CAVERN
			for _ = 1, rng:int(spitters[1], spitters[2]) do
				table.insert(present, { type = "Spitter", distance = Assumptions.TARGETS.Spitter.distance })
			end
		end
		ambient[index] = present
	end

	local function standing(): number
		local count = 0
		for _, member in crew do
			if Crew.alive(member) then
				count += 1
			end
		end
		return count
	end

	-- Calls a pod when the crew's average ammo or health is under `level` (or someone bled out).
	local function maybeResupply(level: number?)
		local ammo, health, kit, dead = 0, 0, 0, false
		for _, member in crew do
			ammo += Crew.ammo(member)
			health += member.health / Game.Player.MAX_HEALTH
			kit += Crew.kit(member)
			if member.state == "dead" then
				dead = true
			end
		end
		ammo /= #crew
		health /= #crew
		kit /= #crew
		local threshold = level or Assumptions.RESUPPLY_AT
		local needed = dead or ammo < threshold or health < threshold + 0.1 or kit < threshold
		if needed and pool.ferrin >= Resources.RESUPPLY_COST then
			pool.ferrin -= Resources.RESUPPLY_COST
			pool.resupplies += 1
			clock += Assumptions.RESUPPLY_SECONDS
			for _, member in crew do
				Crew.refill(member)
			end
			climbBudget = climbCapacity
		end
	end

	-- Downed crew left after a fight get back up if anyone can reach them; otherwise they are lost.
	local function afterFight()
		for _, member in crew do
			if member.state == "downed" then
				if standing() > 0 then
					member.state = "up"
					member.health = Game.Player.MAX_HEALTH * Game.Player.REVIVE_HEALTH_FRACTION
					clock += Game.Player.REVIVE_SECONDS
				else
					member.state = "dead"
				end
			end
		end
		maybeResupply()
	end

	local function fight(arena: Arena.Options, isSwarm: boolean): Arena.Result
		arena.pool = pool
		local result = Arena.run(arena)
		clock += result.seconds
		breakdown.fight += result.seconds
		if isSwarm then
			swarmCount += 1
			table.insert(swarmDamage, result.damageTaken / partySize)
		end
		if result.wiped then
			return result
		end
		afterFight()
		return result
	end

	-- Spends `seconds` on an activity, breaking off for any timed swarm that falls due.
	local function spend(seconds: number, phase: string, kind: string?)
		breakdown[kind or "work"] += seconds
		local finish = clock + seconds
		while not failed and nextSwarm <= finish do
			clock = math.max(clock, nextSwarm)
			nextSwarm = clock + rng:range(EnemiesConfig.SWARM_INTERVAL[1], EnemiesConfig.SWARM_INTERVAL[2])
			local result = fight({
				crew = crew,
				partySize = partySize,
				rng = rng,
				swarms = { { at = 0, size = 1 } },
			}, true)
			if result.wiped then
				failed = phase
				return
			end
			finish += result.seconds
		end
		clock = math.max(clock, finish)
	end

	local function climbTime(height: number): number
		if height <= 0 then
			return 0
		end
		local covered = math.min(height, climbBudget)
		climbBudget -= covered
		return covered / climbRate + (height - covered) / Assumptions.PICKAXE_CLIMB
	end

	-- `route` scales the walked distance: exploring blind, following a marker, or retracing steps.
	local function travel(from: number, to: number, phase: string, route: number)
		if from == to then
			return
		end
		local time, climb, previous = travelFrom(graph, from, speed, climbRate)
		local length = pathLength(graph, previous, from, to) * route
		local seconds = length / speed + climbTime(climb[to])
		if time[to] == math.huge then
			seconds = 120
		end
		spend(seconds, phase, "travel")
	end

	-- Entering a cavern wakes what sleeps there.
	local function enter(index: number, phase: string)
		if failed then
			return
		end
		local present = ambient[index]
		if #present > 0 then
			ambient[index] = {}
			local result = fight({ crew = crew, partySize = partySize, rng = rng, present = present }, false)
			if result.wiped then
				failed = phase
				return
			end
		end
		-- Ferrin and health crystals along the way.
		local nodes = rng:int(Resources.FERRIN_NODES_PER_CAVERN[1], Resources.FERRIN_NODES_PER_CAVERN[2])
		local mined = math.floor(nodes * Assumptions.FERRIN_MINED + rng:next())
		pool.ferrin += mined * Resources.FERRIN_PER_NODE
		local crystals = rng:int(Resources.HEALTH_CRYSTALS_PER_CAVERN[1], Resources.HEALTH_CRYSTALS_PER_CAVERN[2])
		local healed = math.floor(crystals * Assumptions.CRYSTALS_MINED + rng:next())
		for _ = 1, healed do
			local hurt, lowest = nil, math.huge
			for _, member in crew do
				if member.state == "up" and member.health < lowest then
					hurt, lowest = member, member.health
				end
			end
			if hurt then
				Crew.heal(hurt, Resources.HEALTH_PER_CRYSTAL)
			end
		end
		local miners = 1 + Assumptions.MINER_EFFICIENCY * (partySize - 1)
		spend((mined + healed) * Assumptions.NODE_SECONDS / miners, phase)
		maybeResupply()
	end

	local function walkCavern(index: number, phase: string)
		local radii = caverns[index].radii
		spend(Assumptions.CAVERN_WALK * math.max(radii.X, radii.Z) / speed, phase, "travel")
	end

	local position = layout.startCavern
	local extractionFrom = position
	local siteCavern = position

	if missionType == "Mining" then
		local target = Missions.MINING_TARGET[partySize]
		local total = math.ceil(target * Missions.MINING_SURPLUS)
		local weights, weightTotal = {}, 0
		for index, cavern in caverns do
			local volume = cavern.radii.X * cavern.radii.Y * cavern.radii.Z
			weights[index] = if index == layout.startCavern then volume * LANDING_WEIGHT else volume
			weightTotal += weights[index]
		end
		local remaining = {}
		for index in caverns do
			remaining[index] = total * weights[index] / weightTotal
		end
		local reachShare = Assumptions.VEIN_REACH * (0.85 + 0.15 * math.min(1, climbRate / 6))
		local seek = Assumptions.VEIN_SEEK * seekFactor(crew)
		local miners = 1 + Assumptions.MINER_EFFICIENCY * (partySize - 1)
		local collected = 0
		local visited = { [position] = true }
		local function mine(index: number)
			local available = remaining[index] * reachShare
			local take = math.min(available, target - collected)
			if take <= 0 then
				return
			end
			remaining[index] -= take
			local veins = take / Resources.VOLTICITE_PER_VEIN
			local perVein = seek
				+ Resources.VOLTICITE_PER_VEIN / Resources.VOLTICITE_PER_HIT * Game.Pickaxe.SWING_INTERVAL
			spend(veins * perVein / miners, "Mining")
			collected += take
		end
		mine(position)
		while collected < target and not failed do
			local time = travelFrom(graph, position, speed, climbRate)
			local best, bestScore = nil, -math.huge
			for index in caverns do
				if not visited[index] and remaining[index] > 0 and time[index] < math.huge then
					local score = remaining[index] / (time[index] + 30)
					if score > bestScore then
						best, bestScore = index, score
					end
				end
			end
			if not best then
				-- Everything visited: scrape the leftovers where the most remains.
				for index in caverns do
					if remaining[index] > 0 and (not best or remaining[index] > remaining[best :: number]) then
						best = index
					end
				end
				if not best then
					break
				end
				reachShare = 1
			end
			local nextCavern = best :: number
			travel(position, nextCavern, "Mining", Assumptions.ROUTE_EXPLORE)
			position = nextCavern
			if not visited[position] then
				visited[position] = true
				enter(position, "Mining")
				walkCavern(position, "Mining")
			end
			mine(position)
		end
		if not failed then
			travel(position, layout.startCavern, "Mining", Assumptions.ROUTE_KNOWN)
			position = layout.startCavern
			-- The last vein rarely lands exactly on the target.
			delivered = target + 3 * rng:int(0, 3)
		end
		extractionFrom = position
	else
		-- Refinery: site and wells as the server chooses them.
		local centroid = Vector3.zero
		for _, cavern in caverns do
			centroid += cavern.center
		end
		centroid /= #caverns
		local bestScore = -math.huge
		for index, cavern in caverns do
			local score = math.min(cavern.radii.X, cavern.radii.Z) * 2 - (cavern.center - centroid).Magnitude * 0.25
			if index ~= layout.startCavern and score > bestScore then
				siteCavern, bestScore = index, score
			end
		end
		travel(position, siteCavern, "Pipes", Assumptions.ROUTE_MARKED)
		position = siteCavern
		enter(position, "Pipes")
		spend(Assumptions.REFINERY_SETUP + Server.refineryDropSeconds, "Pipes")
		local ranked = {}
		for index in caverns do
			if index ~= siteCavern then
				table.insert(ranked, index)
			end
		end
		local site = caverns[siteCavern].center
		table.sort(ranked, function(a, b)
			return (caverns[a].center - site).Magnitude > (caverns[b].center - site).Magnitude
		end)
		local wells = {}
		for index = 1, math.min(Missions.REFINERY_WELLS, #ranked) do
			table.insert(wells, ranked[index])
		end
		-- Small crews lay pipe together; crews of 3 or 4 split into two teams.
		local teams = if partySize >= 3 then 2 else 1
		local pipeLength = 0
		local tripTimes = {}
		for _, well in wells do
			local _, climb, previous = travelFrom(graph, siteCavern, speed, climbRate)
			local length = pathLength(graph, previous, siteCavern, well)
			pipeLength += length
			local out = length * Assumptions.ROUTE_MARKED / speed + climb[well] / climbRate
			local back = length / (speed * Assumptions.PIPE_PACE)
			table.insert(tripTimes, { well = well, out = out, back = back, climb = climb[well] })
		end
		table.sort(tripTimes, function(a, b)
			return a.out + a.back > b.out + b.back
		end)
		local teamTime = table.create(teams, 0)
		for _, trip in tripTimes do
			local slot = 1
			for index = 2, teams do
				if teamTime[index] < teamTime[slot] then
					slot = index
				end
			end
			teamTime[slot] += trip.out + trip.back
		end
		local longest = 0
		for _, value in teamTime do
			longest = math.max(longest, value)
		end
		-- The wells' caverns (and their sleepers) are met on the way.
		for _, trip in tripTimes do
			enter(trip.well, "Pipes")
			if failed then
				break
			end
		end
		if not failed then
			spend(longest, "Pipes", "travel")
		end
		-- The crew decides when the last pipe connects, so it banks Ferrin for pods first, mining
		-- the nearest unvisited caverns, and tops up before the pump starts.
		local visited = { [siteCavern] = true }
		for _, trip in tripTimes do
			visited[trip.well] = true
		end
		while not failed and pool.ferrin < Resources.RESUPPLY_COST * Assumptions.PUMP_FERRIN_BANK do
			local time = travelFrom(graph, siteCavern, speed, climbRate)
			local nearest, best = nil, math.huge
			for index in caverns do
				if not visited[index] and time[index] < best then
					nearest, best = index, time[index]
				end
			end
			if not nearest then
				break
			end
			visited[nearest] = true
			travel(siteCavern, nearest, "Pipes", Assumptions.ROUTE_EXPLORE)
			enter(nearest, "Pipes")
			travel(nearest, siteCavern, "Pipes", Assumptions.ROUTE_KNOWN)
		end
		if not failed and pool.ferrin >= Resources.RESUPPLY_COST * Assumptions.PUMP_FERRIN_BANK then
			maybeResupply(0.75)
		end
		if not failed then
			-- Pumping: three minutes under constant swarms, stalled by broken pipe.
			local swarms = { { at = 0, size = Server.refineryFirstSwarm } }
			local pumpEnd = Missions.REFINERY_PUMP_SECONDS * 1.5
			while nextSwarm < clock + pumpEnd do
				table.insert(swarms, { at = nextSwarm - clock, size = 1 })
				nextSwarm += rng:range(EnemiesConfig.SWARM_INTERVAL[1], EnemiesConfig.SWARM_INTERVAL[2])
			end
			local result = fight({
				crew = crew,
				partySize = partySize,
				rng = rng,
				swarms = swarms,
				pump = {
					seconds = Missions.REFINERY_PUMP_SECONDS,
					segments = math.max(1, math.floor(pipeLength / Assumptions.PIPE_SEGMENT_LENGTH)),
				},
			}, true)
			if result.wiped then
				failed = "Pumping"
			else
				-- The rocket launch sequence before the Lift Pod is called.
				spend(7, "Pumping")
			end
		end
		extractionFrom = siteCavern
	end

	-- Extraction ---------------------------------------------------------------------------------
	local leftBehind = {}
	if not failed then
		local from = caverns[extractionFrom].center
		local landing, farthest = extractionFrom, -1
		for index, cavern in caverns do
			local floor = Vector3.new(cavern.center.X, cavern.floorY, cavern.center.Z)
			local distance = (floor - from).Magnitude
			if distance > farthest then
				landing, farthest = index, distance
			end
		end
		local time, climb, previous = travelFrom(graph, extractionFrom, speed, climbRate)
		local length = pathLength(graph, previous, extractionFrom, landing)
		local trip = length * Assumptions.ROUTE_MARKED / speed + climbTime(climb[landing])
		if time[landing] == math.huge then
			trip = math.huge
		end
		local window = Server.liftDescent + Missions.LIFT_POD_COUNTDOWN
		local swarms = { { at = 0, size = Server.liftSwarm } }
		if nextSwarm < clock + window then
			table.insert(swarms, { at = nextSwarm - clock, size = 1 })
		end
		local result = Arena.run({
			crew = crew,
			partySize = partySize,
			rng = rng,
			swarms = swarms,
			duration = Missions.LIFT_POD_COUNTDOWN,
			pool = pool,
		})
		swarmCount += 1
		table.insert(swarmDamage, result.damageTaken / partySize)
		clock += window
		local aboard = 0
		for _, member in crew do
			local made = Crew.alive(member) and trip <= window
			leftBehind[member.index] = not made
			if made then
				aboard += 1
			end
		end
		if aboard == 0 then
			failed = "Extraction"
		end
	end

	local outcome: "Success" | "Failure" = if failed then "Failure" else "Success"
	local rewards = {}
	local downs = 0
	for _, member in crew do
		downs += member.downs
		local credits, xp = Game.Progression.reward(
			missionType,
			outcome,
			delivered,
			outcome == "Success" and leftBehind[member.index] == true
		)
		rewards[member.index] = { credits = credits, xp = xp }
	end
	return {
		outcome = outcome,
		phase = failed or "Success",
		delivered = delivered,
		seconds = clock,
		leftBehind = leftBehind,
		swarmDamage = swarmDamage,
		swarms = swarmCount,
		downs = downs,
		resupplies = pool.resupplies,
		breakdown = breakdown,
		rewards = rewards,
	}
end

return Mission
