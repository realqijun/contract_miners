--!strict
-- Time-to-kill: one player with one weapon against one Vrill at its usual engagement distance,
-- trigger held from the first moment (no reaction time or uptime gaps), starting with a full
-- magazine. Health uses the party size's HEALTH_SCALE. Monte Carlo over shot outcomes.

local Assumptions = require("./Assumptions")
local Bands = require("./Bands")
local Game = require("./Game")
local Rng = require("./Rng")
local Weapon = require("./Weapon")

local Server = Game.Server

local Duel = {}

local STEP = 0.02
local LIMIT = 60

export type Result = { mean: number, p90: number, unkillable: number }

-- Damage one accepted shot or tick deals to a lone target; updates burn through `state`.
local function shotDamage(gun: Weapon.Gun, enemyType: string, now: number, state: any, rng: Rng.Rng): number
	local stats = gun.stats
	local distance = state.distance or Weapon.distanceFor(enemyType, rng)
	if stats.mode == "Stream" then
		if distance > stats.range or not rng:chance(gun.band.streamAim) then
			return 0
		end
		if stats.burnPerSecond then
			state.burn = math.max(state.burn, stats.burnPerSecond)
			state.burnUntil = now + Server.burnSeconds
		end
		return stats.damage * Server.streamTick
	elseif stats.mode == "Lobbed" then
		local falloff = Weapon.lobbedFalloff(
			gun.band,
			enemyType,
			distance,
			stats.projectileSpeed or 100,
			stats.gravity or 60,
			stats.splashRadius or 8,
			rng
		)
		return stats.damage * falloff
	end
	return Weapon.bullet(gun, enemyType, distance, rng)
end

function Duel.ttk(
	weaponId: string,
	upgrades: { string },
	enemyType: string,
	partySize: number,
	band: Bands.Band,
	trials: number,
	seed: number
): Result
	local stats = Game.Stats.weapon(weaponId, upgrades)
	local enemy = Game.Enemies.STATS[enemyType]
	local health = enemy.health * Game.Enemies.HEALTH_SCALE[partySize]
	local target = Assumptions.TARGETS[enemyType]
	-- A rooted target out of reach has to be walked up to first.
	local approach, distance = 0, nil
	if enemy.rooted and target.distance > stats.range then
		distance = stats.range - 2
		approach = (target.distance - distance) / Game.Player.WALK_SPEED
	end
	local times = {}
	local unkillable = 0
	for trial = 1, trials do
		local rng = Rng.new(seed + trial * 7919)
		local gun = Weapon.new(weaponId, stats, band)
		local hp = health
		local state = { burn = 0, burnUntil = -1, distance = distance }
		local now = 0
		while now < LIMIT and hp > 0 do
			local shots = gun:advance(now, STEP, true)
			for _ = 1, shots do
				hp -= shotDamage(gun, enemyType, now, state, rng)
			end
			if state.burnUntil > now then
				hp -= state.burn * STEP
			end
			now += STEP
		end
		if hp > 0 then
			unkillable += 1
		end
		table.insert(times, math.min(now, LIMIT) + approach)
	end
	table.sort(times)
	local sum = 0
	for _, value in times do
		sum += value
	end
	return {
		mean = sum / #times,
		p90 = times[math.max(1, math.floor(#times * 0.9))],
		unkillable = unkillable / trials,
	}
end

-- Damage a weapon can deal from one full load (magazine plus reserve) on a Warrior, per shot fired.
function Duel.damagePerLoad(weaponId: string, upgrades: { string }, band: Bands.Band, seed: number): number
	local stats = Game.Stats.weapon(weaponId, upgrades)
	local gun = Weapon.new(weaponId, stats, band)
	local rng = Rng.new(seed)
	local samples = 2000
	local total = 0
	local state = { burn = 0, burnUntil = -1 }
	for _ = 1, samples do
		total += shotDamage(gun, "Warrior", 0, state, rng)
	end
	local perShot = total / samples
	if stats.mode == "Stream" and stats.burnPerSecond then
		-- Each tick keeps the target alight; count the burn a tick sustains.
		perShot += stats.burnPerSecond * Server.streamTick * gun.band.streamAim
	end
	if stats.mode == "Spin" then
		-- No reserve: one heat cycle's worth per vent, effectively unlimited. Report a full cycle.
		return perShot / (stats.heatPerShot or 0.01) * 10
	end
	local perTick = if stats.mode == "Stream"
		then math.max(1, math.floor(stats.rpm / 60 * Server.streamTick + 0.5))
		else 1
	return perShot * (stats.magazine + stats.reserve) / perTick
end

return Duel
