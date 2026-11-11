--!strict
-- The audit's report sections. Each returns Markdown; run.luau prints and saves them.

local Arena = require("./Arena")
local Assumptions = require("./Assumptions")
local Bands = require("./Bands")
local Career = require("./Career")
local Crew = require("./Crew")
local Duel = require("./Duel")
local Game = require("./Game")
local Mission = require("./Mission")
local Paths = require("./Paths")
local Power = require("./Power")
local Rng = require("./Rng")

local Report = {}

local ENEMY_TYPES = { "Drone", "Warrior", "Bulwark", "Spitter", "Wasp", "Ravager" }
local WEAPONS = {
	"RivetDriver",
	"ArcMortar",
	"BurstCarbine",
	"BoltPistol",
	"RotaryCannon",
	"HandCannon",
	"FlameProjector",
	"AutoPistol",
}
local PATHS = { Paths.uniform("A"), Paths.uniform("B") }

export type Settings = { quick: boolean }

local function fmt(value: number, digits: number?): string
	if value ~= value then
		return "-"
	end
	return string.format(`%.{digits or 1}f`, value)
end

local function table_(header: { string }, rows: { { string } }): string
	local lines = { "| " .. table.concat(header, " | ") .. " |" }
	local rule = {}
	for _ in header do
		table.insert(rule, "---")
	end
	table.insert(lines, "| " .. table.concat(rule, " | ") .. " |")
	for _, row in rows do
		table.insert(lines, "| " .. table.concat(row, " | ") .. " |")
	end
	return table.concat(lines, "\n")
end

-- Every class composition of a party size (classes may repeat), in a stable order.
function Report.compositions(size: number): { { string } }
	local list = {}
	local order = Game.Classes.ORDER
	local function build(start: number, current: { string })
		if #current == size then
			table.insert(list, table.clone(current))
			return
		end
		for index = start, #order do
			table.insert(current, order[index])
			build(index, current)
			table.remove(current)
		end
	end
	build(1, {})
	return list
end

-- A handful of representative compositions for quick runs: mono-class and rotated mixes.
local function quickCompositions(size: number): { { string } }
	local order = Game.Classes.ORDER
	local list = {}
	for shift = 0, 3 do
		local crew = {}
		for slot = 1, size do
			table.insert(crew, order[(slot + shift - 1) % 4 + 1])
		end
		table.insert(list, crew)
	end
	return list
end

-- Time to kill ------------------------------------------------------------------------------------

function Report.ttk(settings: Settings): string
	local trials = if settings.quick then 80 else 300
	local mid = Bands.BY_NAME.mid
	local out = { "## Time to kill (seconds, mid band, trigger held, full magazine)" }
	for _, size in { 1, 4 } do
		for _, path in
			{ { name = "bare", list = nil }, { name = "all A", path = PATHS[1] }, { name = "all B", path = PATHS[2] } }
		do
			local rows = {}
			for _, weaponId in WEAPONS do
				local upgrades = {}
				if path.path then
					for tier = 1, 3 do
						table.insert(upgrades, Game.Upgrades.id(weaponId, tier, path.path.pick(weaponId, tier)))
					end
				end
				local row = { weaponId }
				for _, enemyType in ENEMY_TYPES do
					local result = Duel.ttk(weaponId, upgrades, enemyType, size, mid, trials, 3)
					table.insert(row, if result.unkillable > 0.5 then "never" else fmt(result.mean, 2))
				end
				table.insert(rows, row)
			end
			local header = { `Weapon ({path.name}, party of {size})` }
			for _, enemyType in ENEMY_TYPES do
				table.insert(header, enemyType)
			end
			table.insert(out, table_(header, rows))
		end
	end
	-- Skill bands, bare weapons, party of four.
	local rows = {}
	for _, weaponId in WEAPONS do
		local row = { weaponId }
		for _, band in Bands.LIST do
			local sum = 0
			for _, enemyType in ENEMY_TYPES do
				sum += Duel.ttk(weaponId, {}, enemyType, 4, band, trials, 3).mean
			end
			table.insert(row, fmt(sum / #ENEMY_TYPES, 2))
		end
		table.insert(rows, row)
	end
	table.insert(out, table_({ "Weapon (bare, party of 4, mean over Vrill)", "low", "mid", "high" }, rows))
	return table.concat(out, "\n\n")
end

-- Swarms ---------------------------------------------------------------------------------------------

local function crewOf(classes: { string }, level: number, path: Paths.Path, band: Bands.Band): { Crew.Member }
	local crew = {}
	for slot, classId in classes do
		local upgrades = if level == 0 then {} else Paths.upgradesAt(classId, level, path)
		crew[slot] = Crew.new(slot, classId, upgrades, band, #classes)
	end
	return crew
end

function Report.swarms(settings: Settings): string
	local trials = if settings.quick then 60 else 200
	local rows = {}
	for size = 1, 4 do
		local comps = quickCompositions(size)
		for _, band in Bands.LIST do
			for _, level in { 0, 5 } do
				local clear, damage, wipes, spawned = 0, 0, 0, 0
				for trial = 1, trials do
					local classes = comps[(trial - 1) % #comps + 1]
					local crew = crewOf(classes, level, PATHS[(trial % 2) + 1], band)
					local result = Arena.run({
						crew = crew,
						partySize = size,
						rng = Rng.new(trial * 389 + size),
						swarms = { { at = 0, size = 1 } },
					})
					clear += result.seconds
					damage += result.damageTaken / size
					spawned += result.spawned
					if result.wiped then
						wipes += 1
					end
				end
				table.insert(rows, {
					tostring(size),
					band.name,
					if level == 0 then "bare" else "level 5",
					fmt(spawned / trials),
					fmt(clear / trials),
					fmt(damage / trials, 0),
					fmt(100 * wipes / trials, 0) .. "%",
				})
			end
		end
	end
	return "## Damage taken per timed swarm (fresh crew, mixed classes)\n\n"
		.. table_({ "Party", "Band", "Kit", "Vrill", "Clear s", "Damage per player", "Wipe" }, rows)
end

-- Missions --------------------------------------------------------------------------------------------

function Report.missions(settings: Settings): string
	local trials = if settings.quick then 24 else 80
	local rows = {}
	for _, missionType in Game.Missions.TYPES do
		for size = 1, 4 do
			local comps = quickCompositions(size)
			for _, band in Bands.LIST do
				for _, level in { 0, 5 } do
					local success, seconds, phases, left, swarmDamage, swarms = 0, 0, {}, 0, 0, 0
					for trial = 1, trials do
						local classes = comps[(trial - 1) % #comps + 1]
						local crew = crewOf(classes, level, PATHS[(trial % 2) + 1], band)
						local seed = trial * 7919 + size * 31
						local result =
							Mission.run({ crew = crew, missionType = missionType, seed = seed, rng = Rng.new(seed) })
						if result.outcome == "Success" then
							success += 1
							seconds += result.seconds
							for _, value in result.leftBehind do
								if value then
									left += 1
								end
							end
						else
							phases[result.phase] = (phases[result.phase] or 0) + 1
						end
						for _, value in result.swarmDamage do
							swarmDamage += value
							swarms += 1
						end
					end
					local failures = {}
					for _, phase in { "Mining", "Pipes", "Pumping", "Extraction" } do
						if phases[phase] then
							table.insert(failures, `{phase} {fmt(100 * phases[phase] / trials, 0)}%`)
						end
					end
					table.insert(rows, {
						missionType,
						tostring(size),
						band.name,
						if level == 0 then "bare" else "level 5",
						fmt(100 * success / trials, 0) .. "%",
						if success > 0 then fmt(seconds / success / 60) else "-",
						if swarms > 0 then fmt(swarmDamage / swarms, 0) else "-",
						fmt(100 * left / math.max(1, success * size), 0) .. "%",
						if #failures > 0 then table.concat(failures, ", ") else "-",
					})
				end
			end
		end
	end
	local rewards = {}
	for _, missionType in Game.Missions.TYPES do
		for size = 1, 4 do
			local delivered = if missionType == "Mining" then Game.Missions.MINING_TARGET[size] else 0
			local success = { Game.Progression.reward(missionType, "Success", delivered, false) }
			local left = { Game.Progression.reward(missionType, "Success", delivered, true) }
			local failure = { Game.Progression.reward(missionType, "Failure", 0, false) }
			table.insert(rewards, {
				missionType,
				tostring(size),
				`{success[1]} / {success[2]}`,
				`{left[1]} / {left[2]}`,
				`{failure[1]} / {failure[2]}`,
			})
		end
	end
	return "## Missions (success, duration of successes, damage per swarm per player, left behind)\n\n"
		.. table_(
			{ "Type", "Party", "Band", "Kit", "Success", "Minutes", "Swarm dmg", "Left behind", "Failures by phase" },
			rows
		)
		.. "\n\n## Rewards per player (credits / XP) at the target delivery\n\n"
		.. table_({ "Type", "Party", "Success", "Left behind", "Failure before delivery" }, rewards)
end

-- Progression ------------------------------------------------------------------------------------------

function Report.progression(settings: Settings): string
	local samples = if settings.quick then 8 else Assumptions.MISSION_SAMPLES
	local careers = if settings.quick then 4 else Assumptions.CAREERS
	local maxLevel = Game.Progression.MAX_LEVEL
	type Totals = {
		missions: { number },
		successes: { number },
		reached: { number },
		credits: { number },
		cost: { number },
		afford: { number },
		tierOne: number,
		tierOneCount: number,
		count: number,
	}
	local function totals(): Totals
		return {
			missions = table.create(maxLevel, 0),
			successes = table.create(maxLevel, 0),
			reached = table.create(maxLevel, 0),
			credits = table.create(maxLevel, 0),
			cost = table.create(maxLevel, 0),
			afford = table.create(maxLevel, 0),
			tierOne = 0,
			tierOneCount = 0,
			count = 0,
		}
	end
	local byGroup: { [string]: Totals } = {}
	local byClass: { [string]: Totals } = {}
	local byPath: { [string]: Totals } = {}
	-- Averages only count careers that got there; `reached` says how many did.
	local function add(group: { [string]: Totals }, key: string, track: Career.Track)
		local entry = group[key]
		if not entry then
			entry = totals()
			group[key] = entry
		end
		entry.count += 1
		if track.tierOneBoughtAt then
			entry.tierOne += track.tierOneBoughtAt
			entry.tierOneCount += 1
		end
		for level = 2, maxLevel do
			if track.missionsAt[level] then
				entry.reached[level] += 1
				entry.missions[level] += track.missionsAt[level]
				entry.successes[level] += track.successesAt[level]
				entry.credits[level] += track.creditsAt[level]
				entry.cost[level] += track.costAt[level]
				if track.creditsAt[level] >= track.costAt[level] then
					entry.afford[level] += 1
				end
			end
		end
	end
	local function mean(entry: Totals, field: string, level: number): number
		return (entry :: any)[field][level] / math.max(1, entry.reached[level])
	end
	local seed = 1
	for size = 1, 4 do
		local comps = if settings.quick then quickCompositions(size) else Report.compositions(size)
		for _, classes in comps do
			for _, band in Bands.LIST do
				for _, missionType in Game.Missions.TYPES do
					seed += 1
					for pathIndex, path in PATHS do
						-- Same mission seeds for both paths: the bare-kit samples are shared.
						local states = Career.sample(classes, band, missionType, path, samples, seed * 1009)
						local tracks = Career.run(classes, path, states, careers, seed * 7 + pathIndex)
						for index, track in tracks do
							local slot = (index - 1) % #classes + 1
							add(byGroup, `{size}|{band.name}|{missionType}`, track)
							add(byGroup, `{size}|{band.name}|all`, track)
							add(byClass, `{classes[slot]}|{band.name}`, track)
							add(byPath, path.name, track)
						end
					end
				end
			end
		end
	end
	local out = {}
	local rows = {}
	for size = 1, 4 do
		for _, band in Bands.LIST do
			for _, missionType in { "Mining", "Refinery", "all" } do
				local entry = byGroup[`{size}|{band.name}|{missionType}`]
				local row = { tostring(size), band.name, missionType }
				local previous, previousSuccess = 0, 0
				for level = 2, maxLevel do
					local missions = mean(entry, "missions", level)
					local successes = mean(entry, "successes", level)
					table.insert(row, `{fmt(missions - previous)} ({fmt(successes - previousSuccess)})`)
					previous, previousSuccess = missions, successes
				end
				table.insert(row, fmt(previous))
				table.insert(row, fmt(100 * entry.reached[maxLevel] / entry.count, 0) .. "%")
				table.insert(rows, row)
			end
		end
	end
	table.insert(out, "## Missions to reach each level: missions played (of which successful)")
	table.insert(
		out,
		table_({
			"Party",
			"Band",
			"Type",
			"L1->2",
			"L2->3",
			"L3->4",
			"L4->5",
			"Total to L5",
			`Reached L5 in {Assumptions.MAX_MISSIONS}`,
		}, rows)
	)

	rows = {}
	for size = 1, 4 do
		for _, band in Bands.LIST do
			local entry = byGroup[`{size}|{band.name}|all`]
			local row = { tostring(size), band.name, fmt(entry.tierOne / math.max(1, entry.tierOneCount)) }
			for level = 2, maxLevel do
				table.insert(
					row,
					`{fmt(mean(entry, "credits", level), 0)} / {fmt(mean(entry, "cost", level), 0)} ({fmt(
						100 * entry.afford[level] / math.max(1, entry.reached[level]),
						0
					)}%)`
				)
			end
			table.insert(rows, row)
		end
	end
	table.insert(
		out,
		"## Credits in hand when each level opens its tiers / cost of one choice per item (share who can afford it)"
	)
	table.insert(out, table_({ "Party", "Band", "Missions to buy all tier 1", "L2", "L3", "L4", "L5" }, rows))

	rows = {}
	for _, classId in Game.Classes.ORDER do
		for _, band in Bands.LIST do
			local entry = byClass[`{classId}|{band.name}`]
			if entry then
				table.insert(rows, { classId, band.name, fmt(mean(entry, "missions", maxLevel)) })
			end
		end
	end
	table.insert(out, "## Missions to level 5 by class (all party sizes and mission types)")
	table.insert(out, table_({ "Class", "Band", "Missions" }, rows))

	rows = {}
	for _, path in PATHS do
		local entry = byPath[path.name]
		table.insert(rows, { path.name, fmt(mean(entry, "missions", maxLevel)) })
	end
	table.insert(out, "## Missions to level 5 by upgrade path")
	table.insert(out, table_({ "Path", "Missions" }, rows))
	return table.concat(out, "\n\n")
end

-- Dominance and power -----------------------------------------------------------------------------------

function Report.dominance(_settings: Settings): string
	local findings = Power.dominance(0.02)
	local rows = {}
	for _, finding in findings do
		table.insert(rows, { finding.item, tostring(finding.tier), finding.winner, finding.context, finding.axes })
	end
	if #rows == 0 then
		return "## Strictly dominant upgrade choices\n\nNone."
	end
	return "## Strictly dominant upgrade choices (better or equal on every axis, 2% tolerance)\n\n"
		.. table_({ "Item", "Tier", "Dominant", "When", "Axes that differ (A vs B)" }, rows)
end

function Report.power(settings: Settings): string
	local trials = if settings.quick then 16 else 40
	local band = Bands.BY_NAME.mid
	local maxLevel = Game.Progression.MAX_LEVEL
	local rows = {}
	local function addRow(label: string, path: Paths.Path, levelsFor: (level: number) -> { number })
		local base = Power.level(levelsFor(0), path, band, trials)
		local row = { label, path.name, fmt(base.capacity, 2) }
		local previous = 1
		local steps = {}
		for level = 1, maxLevel do
			local index, combat, mobility = Power.index(base, Power.level(levelsFor(level), path, band, trials))
			table.insert(steps, index - previous)
			table.insert(row, `{fmt(index, 2)} (+{fmt(index - previous, 2)}; c {fmt(combat, 2)} m {fmt(mobility, 2)})`)
			previous = index
		end
		local mean = (previous - 1) / #steps
		local spread = 0
		for _, step in steps do
			spread = math.max(spread, math.abs(step - mean))
		end
		table.insert(row, fmt(spread / math.max(math.abs(mean), 1e-6), 2))
		table.insert(rows, row)
	end
	for _, path in PATHS do
		addRow("Whole crew", path, function(level)
			return { level, level, level, level }
		end)
		for slot, classId in Game.Classes.ORDER do
			addRow(classId .. " only", path, function(level)
				local levels = { 0, 0, 0, 0 }
				levels[slot] = level
				return levels
			end)
		end
	end
	return "## Power index by level (bare kit = 1.00, step in brackets, c = combat capacity, m = mobility)\n\n"
		.. "A mixed crew of four, one of each class, at mid skill.\n"
		.. "Combat capacity is the swarm size at which the crew takes "
		.. `{Assumptions.POWER_DAMAGE} damage per player; the bare-kit column gives it in swarms.\n`
		.. '"Only" rows upgrade just that class\'s member, showing what its own upgrades add.\n'
		.. "Unevenness is the largest deviation of a step from the mean step, over the mean step.\n\n"
		.. table_({ "Crew", "Path", "Bare capacity", "L1", "L2", "L3", "L4", "L5", "Unevenness" }, rows)
end

return Report
