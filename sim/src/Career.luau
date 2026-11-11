--!strict
-- Progression: a crew playing mission after mission from a fresh save, banking rewards and buying
-- upgrades through the game's Progress module (real level, unlock and price rules).
--
-- Missions are expensive, so they are sampled once per "kit state" (every tier opened by level L
-- bought along the path, L = 0..5) and careers then draw from those samples. A crew plays the
-- state its least-upgraded member has completed.

local Assumptions = require("./Assumptions")
local Bands = require("./Bands")
local Crew = require("./Crew")
local Game = require("./Game")
local Mission = require("./Mission")
local Paths = require("./Paths")
local Rng = require("./Rng")

local Career = {}

-- Samples per crew, band, mission type and exact upgrade set, so paths share their bare-kit state.
local sampleCache: { [string]: { Sample } } = {}

export type Sample = {
	outcome: string,
	phase: string,
	seconds: number,
	rewards: { { credits: number, xp: number } },
	leftBehind: { [number]: boolean },
	swarmDamage: number,
}

-- Mission samples for every kit state of a crew.
function Career.sample(
	classes: { string },
	band: Bands.Band,
	missionType: string,
	path: Paths.Path,
	samples: number,
	seed: number
): { [number]: { Sample } }
	local states = {}
	local size = #classes
	for level = 0, Game.Progression.MAX_LEVEL do
		local signature = {}
		for _, classId in classes do
			table.insert(signature, classId)
			if level > 0 then
				table.insert(signature, table.concat(Paths.upgradesAt(classId, level, path), ","))
			end
		end
		local key = `{table.concat(signature, "|")}|{band.name}|{missionType}|{samples}|{seed}`
		local cached = sampleCache[key]
		if cached then
			states[level] = cached
			continue
		end
		local list = {}
		for index = 1, samples do
			local crew = {}
			for slot, classId in classes do
				local upgrades = if level == 0 then {} else Paths.upgradesAt(classId, level, path)
				crew[slot] = Crew.new(slot, classId, upgrades, band, size)
			end
			local missionSeed = seed + index * 7907 + level * 104729
			local result = Mission.run({
				crew = crew,
				missionType = missionType,
				seed = missionSeed,
				rng = Rng.new(missionSeed),
			})
			local damage, count = 0, 0
			for _, value in result.swarmDamage do
				damage += value
				count += 1
			end
			table.insert(list, {
				outcome = result.outcome,
				phase = result.phase,
				seconds = result.seconds,
				rewards = result.rewards,
				leftBehind = result.leftBehind,
				swarmDamage = if count > 0 then damage / count else 0,
			})
		end
		states[level] = list
		sampleCache[key] = list
	end
	return states
end

export type Track = {
	-- Missions played (and successes) when each level was reached.
	missionsAt: { [number]: number },
	successesAt: { [number]: number },
	-- Credits in hand the moment a level opened its tiers, before buying, and that tier set's cost.
	creditsAt: { [number]: number },
	costAt: { [number]: number },
	-- Missions until everything level 1 opens was bought.
	tierOneBoughtAt: number?,
}

-- Plays careers for every crew member from a fresh save until all reach the top level.
function Career.run(
	classes: { string },
	path: Paths.Path,
	states: { [number]: { Sample } },
	careers: number,
	seed: number
): { Track }
	local tracks = {}
	local maxLevel = Game.Progression.MAX_LEVEL
	local tierOneCount = #Paths.upgradesAt(classes[1], 1, path)
	for career = 1, careers do
		local rng = Rng.new(seed + career * 613)
		local saves, member = {}, {}
		for slot, classId in classes do
			local data = Game.Progress.template()
			data.selectedClass = classId
			saves[slot] = data
			member[slot] = {
				missionsAt = { [1] = 0 },
				successesAt = { [1] = 0 },
				creditsAt = { [1] = 0 },
				costAt = { [1] = Paths.costOfLevel(classId, 1) },
				tierOneBoughtAt = nil,
			}
		end
		local played, successes = 0, 0
		while played < Assumptions.MAX_MISSIONS do
			-- The kit state the crew plays at: the lowest fully bought level among its members.
			local state = maxLevel
			for slot, classId in classes do
				local owned = 0
				for level = 1, maxLevel do
					local all = true
					for _, id in Paths.upgradesAt(classId, level, path) do
						if not saves[slot].classes[classId].owned[id] then
							all = false
							break
						end
					end
					if all then
						owned = level
					else
						break
					end
				end
				state = math.min(state, owned)
			end
			local pool = states[state]
			local sample = pool[rng:int(1, #pool)]
			played += 1
			if sample.outcome == "Success" then
				successes += 1
			end
			local done = true
			for slot, classId in classes do
				local data = saves[slot]
				local before = Game.Progress.level(data, classId)
				local reward = sample.rewards[slot]
				Game.Progress.grant(data, classId, reward.credits, reward.xp)
				local after = Game.Progress.level(data, classId)
				local track = member[slot]
				for level = before + 1, after do
					track.missionsAt[level] = played
					track.successesAt[level] = successes
					track.creditsAt[level] = data.credits
					track.costAt[level] = Paths.costOfLevel(classId, level)
				end
				Paths.buyAll(data, classId, path)
				if not track.tierOneBoughtAt then
					local count = 0
					for id in data.classes[classId].owned do
						if string.match(id, "%.1[AB]$") then
							count += 1
						end
					end
					if count >= tierOneCount then
						track.tierOneBoughtAt = played
					end
				end
				if after < maxLevel then
					done = false
				end
			end
			if done then
				break
			end
		end
		for _, track in member do
			table.insert(tracks, track)
		end
	end
	return tracks
end

return Career
