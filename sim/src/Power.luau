--!strict
-- How much an upgrade is worth: measured axes per item (for spotting strictly dominant choices)
-- and a crew power index per class level (for checking that power grows in even steps).

local Arena = require("./Arena")
local Assumptions = require("./Assumptions")
local Bands = require("./Bands")
local Crew = require("./Crew")
local Duel = require("./Duel")
local Game = require("./Game")
local Mission = require("./Mission")
local Paths = require("./Paths")
local Rng = require("./Rng")
local Weapon = require("./Weapon")

local Power = {}

local ENEMY_TYPES = { "Drone", "Warrior", "Bulwark", "Spitter", "Wasp", "Ravager" }

export type Axis = { name: string, value: number, higherIsBetter: boolean }

-- Damage per second over 30 seconds of holding the trigger on an endless Warrior, with reloads,
-- heat and spin-up, times how many Vrill in a crowd of six each shot reaches.
local function sustained(weaponId: string, upgrades: { string }, band: Bands.Band): (number, number)
	local stats = Game.Stats.weapon(weaponId, upgrades)
	local total, trials, seconds = 0, 40, 30
	for trial = 1, trials do
		local rng = Rng.new(trial * 977)
		local gun = Weapon.new(weaponId, stats, band)
		local now = 0
		while now < seconds do
			local shots = gun:advance(now, 0.05, true)
			for _ = 1, shots do
				local distance = Assumptions.TARGETS.Warrior.distance
				if stats.mode == "Stream" then
					if rng:chance(band.streamAim) then
						total += stats.damage * Game.Server.streamTick + (stats.burnPerSecond or 0) * Game.Server.streamTick
					end
				elseif stats.mode == "Lobbed" then
					total += stats.damage * Weapon.lobbedFalloff(
						band,
						"Warrior",
						distance,
						stats.projectileSpeed,
						stats.gravity,
						stats.splashRadius,
						rng
					)
				else
					total += Weapon.bullet(gun, "Warrior", distance, rng)
				end
			end
			now += 0.05
		end
	end
	local dps = total / trials / seconds
	-- Reach into a crowd of six packed within CROWD_RADIUS.
	local reach = 1
	if stats.mode == "Lobbed" then
		reach = 1 + math.min(5, 6 * (stats.splashRadius / Assumptions.CROWD_RADIUS) ^ 2) * Weapon.crowdFalloff()
	elseif stats.mode == "Stream" then
		local share = math.clamp((2 * stats.spread + Assumptions.CONE_FRONT_BONUS) / Assumptions.CONE_FRONT, 0, 1)
		reach = 1 + 5 * share * math.min(1, stats.range / Assumptions.CROWD_RADIUS)
	end
	return dps, dps * reach
end

-- Measured axes for one weapon with a set of its upgrades. Common random numbers keep A/B fair.
function Power.weaponAxes(weaponId: string, upgrades: { string }): { Axis }
	local axes = {}
	local mid, low, high = Bands.BY_NAME.mid, Bands.BY_NAME.low, Bands.BY_NAME.high
	for _, enemyType in ENEMY_TYPES do
		local result = Duel.ttk(weaponId, upgrades, enemyType, 4, mid, 300, 5)
		table.insert(axes, { name = `ttk {enemyType}`, value = result.mean, higherIsBetter = false })
	end
	for _, band in { low, high } do
		local sum = 0
		for _, enemyType in ENEMY_TYPES do
			sum += Duel.ttk(weaponId, upgrades, enemyType, 4, band, 150, 5).mean
		end
		table.insert(axes, { name = `ttk {band.name} band`, value = sum / #ENEMY_TYPES, higherIsBetter = false })
	end
	local dps, crowd = sustained(weaponId, upgrades, mid)
	table.insert(axes, { name = "sustained dps", value = dps, higherIsBetter = true })
	table.insert(axes, { name = "crowd dps", value = crowd, higherIsBetter = true })
	table.insert(axes, {
		name = "damage per load",
		value = Duel.damagePerLoad(weaponId, upgrades, mid, 5),
		higherIsBetter = true,
	})
	local stats = Game.Stats.weapon(weaponId, upgrades)
	table.insert(axes, {
		name = "slow per second",
		value = (stats.slowPerHit or 0) * stats.rpm / 60,
		higherIsBetter = true,
	})
	return axes
end

-- Functional axes for tools and grenades: each distinct effect is its own axis (so trading one
-- effect for another never counts as dominance), plus the composites the mission model uses.
function Power.toolAxes(itemId: string, upgrades: { string }): { Axis }
	local stats = Game.Stats.tool(itemId, upgrades)
	local axes = {}
	local function add(name: string, value: number, higherIsBetter: boolean?)
		table.insert(axes, { name = name, value = value, higherIsBetter = higherIsBetter ~= false })
	end
	add("charges on hand", stats.charges)
	add("charges per 10 min", stats.charges + stats.regenPerSecond * 600)
	add("cooldown", stats.cooldown, false)
	add("range", stats.range)
	if
		itemId == "FoamProjector"
		or itemId == "GrappleLine"
		or itemId == "CableLauncher"
		or itemId == "PlasmaCutter"
	then
		local climb = Mission.climbOf(itemId, stats)
		add("climb rate", climb.rate)
		add("climb per load", math.min(climb.capacity, 10000))
	end
	if itemId == "PlasmaCutter" then
		local duty = Mission.climbOf(itemId, stats).rate / (stats.digRadius * Assumptions.CUTTER_RAMP)
		add("beam damage per second", stats.damagePerTick / stats.cooldown * duty)
	elseif itemId == "LumenDarts" then
		local crew = { { kit = { support = "LumenDarts" }, support = stats } }
		add("vein search saved", 1 - Mission.seekFactor(crew :: any))
	elseif itemId == "ClusterBomb" then
		add("bomblet damage per throw", stats.bomblets * stats.bombletDamage * stats.bombletRadius ^ 2)
	end
	-- Every other stat the item has, one axis each.
	local skip = {
		charges = true,
		regenPerSecond = true,
		cooldown = true,
		range = true,
		displayName = true,
		description = true,
		bomblets = true,
		bombletDamage = true,
		bombletRadius = true,
	}
	local lowerIsBetter = { heatPerTick = true, overheatLockout = true }
	local names = {}
	for stat, value in stats do
		if not skip[stat] and type(value) == "number" then
			table.insert(names, stat)
		end
	end
	table.sort(names)
	for _, stat in names do
		add(stat, stats[stat], not lowerIsBetter[stat])
	end
	return axes
end

function Power.axes(itemId: string, upgrades: { string }): { Axis }
	if Game.isWeapon(itemId) then
		return Power.weaponAxes(itemId, upgrades)
	end
	return Power.toolAxes(itemId, upgrades)
end

-- Is `a` at least as good as `b` everywhere and better somewhere (beyond a relative tolerance)?
-- Returns the comparison: 1 if a dominates, -1 if b dominates, 0 otherwise.
function Power.compare(a: { Axis }, b: { Axis }, tolerance: number): number
	local aBetter, bBetter = false, false
	for index, axis in a do
		local other = b[index].value
		local scale = math.max(math.abs(axis.value), math.abs(other), 1e-9)
		local delta = (axis.value - other) / scale
		if not axis.higherIsBetter then
			delta = -delta
		end
		if delta > tolerance then
			aBetter = true
		elseif delta < -tolerance then
			bBetter = true
		end
	end
	if aBetter and not bBetter then
		return 1
	elseif bBetter and not aBetter then
		return -1
	end
	return 0
end

export type Finding = { item: string, tier: number, winner: string, context: string, axes: string }

-- Every (item, tier) A vs B, under every combination of the item's other two tiers' choices.
-- `only` limits the check to one item.
function Power.dominance(tolerance: number, only: string?): { Finding }
	local findings = {}
	local items = {}
	for itemId in Game.Upgrades.ITEMS do
		if not only or itemId == only then
			table.insert(items, itemId)
		end
	end
	table.sort(items)
	for _, itemId in items do
		-- Axes for all eight combinations of the item's three tiers.
		local cache = {}
		local function axesFor(choices: { string }): { Axis }
			local key = table.concat(choices)
			if not cache[key] then
				local upgrades = {}
				for tier, choice in choices do
					table.insert(upgrades, Game.Upgrades.id(itemId, tier, choice))
				end
				cache[key] = Power.axes(itemId, upgrades)
			end
			return cache[key]
		end
		for tier = 1, 3 do
			local verdicts = {}
			for _, first in { "A", "B" } do
				for _, second in { "A", "B" } do
					local others = { first, second }
					local withA, withB = {}, {}
					local cursor = 1
					for t = 1, 3 do
						if t == tier then
							withA[t], withB[t] = "A", "B"
						else
							withA[t], withB[t] = others[cursor], others[cursor]
							cursor += 1
						end
					end
					local a, b = axesFor(withA), axesFor(withB)
					local verdict = Power.compare(a, b, tolerance)
					if verdict ~= 0 then
						local changed = {}
						for index, axis in a do
							if math.abs(axis.value - b[index].value) > 1e-9 then
								table.insert(
									changed,
									string.format("%s %.3g vs %.3g", axis.name, axis.value, b[index].value)
								)
							end
						end
						table.insert(verdicts, {
							winner = if verdict > 0 then "A" else "B",
							context = `others {table.concat(others)}`,
							axes = table.concat(changed, "; "),
						})
					end
				end
			end
			-- Report a tier when one choice wins under every context of the other tiers.
			if #verdicts == 4 then
				local same = true
				for _, verdict in verdicts do
					if verdict.winner ~= verdicts[1].winner then
						same = false
					end
				end
				if same then
					table.insert(findings, {
						item = itemId,
						tier = tier,
						winner = verdicts[1].winner,
						context = "every combination",
						axes = verdicts[1].axes,
					})
				end
			elseif #verdicts > 0 then
				for _, verdict in verdicts do
					table.insert(findings, {
						item = itemId,
						tier = tier,
						winner = verdict.winner,
						context = verdict.context,
						axes = verdict.axes,
					})
				end
			end
		end
	end
	return findings
end

-- Crew power for a mixed crew of four (one of each class), where member i is at `levels[i]`:
--   capacity: the swarm size (Spawner.swarm size) at which damage taken per player reaches
--             POWER_DAMAGE, found by bisection with common random numbers;
--   travel:   seconds for a reference route (500 studs, 60 studs of climbing, 17 veins to find).
export type Level = { capacity: number, travel: number }

local function crewAt(levels: { number }, path: Paths.Path, band: Bands.Band): { Crew.Member }
	local crew = {}
	for slot, classId in Game.Classes.ORDER do
		local level = levels[slot]
		local upgrades = if level == 0 then {} else Paths.upgradesAt(classId, level, path)
		crew[slot] = Crew.new(slot, classId, upgrades, band, 4)
	end
	return crew
end

local function damageAt(levels: { number }, path: Paths.Path, band: Bands.Band, size: number, trials: number): number
	local damage = 0
	for trial = 1, trials do
		local crew = crewAt(levels, path, band)
		local result = Arena.run({
			crew = crew,
			partySize = 4,
			rng = Rng.new(trial * 4241 + 7),
			swarms = { { at = 0, size = size } },
		})
		damage += result.damageTaken / 4
	end
	return damage / trials
end

function Power.level(levels: { number }, path: Paths.Path, band: Bands.Band, trials: number): Level
	local low, high = math.log(0.25), math.log(8)
	for _ = 1, 8 do
		local middle = (low + high) / 2
		if damageAt(levels, path, band, math.exp(middle), trials) < Assumptions.POWER_DAMAGE then
			low = middle
		else
			high = middle
		end
	end
	-- The crew climbs at its best shared tool's pace, or the slowest member's own.
	local crew = crewAt(levels, path, band)
	local shared, slowest = 0, math.huge
	for _, member in crew do
		local climb = Mission.climbOf(member.kit.traversal, member.traversal)
		if climb.shared then
			shared = math.max(shared, climb.rate)
		end
	end
	for _, member in crew do
		local own = Mission.climbOf(member.kit.traversal, member.traversal).rate
		slowest = math.min(slowest, math.max(own, shared, Assumptions.PICKAXE_CLIMB))
	end
	local speed = Game.Player.SPRINT_SPEED * Assumptions.TRAVEL_EFFICIENCY
	local travel = 500 / speed + 60 / slowest + 17 * Assumptions.VEIN_SEEK * Mission.seekFactor(crew) / 3.25
	return { capacity = math.exp((low + high) / 2), travel = travel }
end

-- Power index relative to the bare kit: geometric mean of combat capacity and mobility.
function Power.index(base: Level, current: Level): (number, number, number)
	local combat = current.capacity / base.capacity
	local mobility = base.travel / current.travel
	return math.sqrt(combat * mobility), combat, mobility
end

return Power
