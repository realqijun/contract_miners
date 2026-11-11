--!strict
-- One fight: Vrill emerging from a spawn queue (Spawner rules: the live cap, emergence delay),
-- closing on the crew and attacking (Hive rules: melee reach and cooldowns, spit, the Ravager's
-- charge, slow, burn, freeze and stun), against a crew that shoots, throws grenades, places
-- fences and domes, revives the downed and repairs Refinery pipes.
--
-- Space is abstracted: each Vrill tracks only its distance to the crew member it chases.
-- Area effects hit the "crowd" chasing the same crew member, spread over CROWD_RADIUS.

local Assumptions = require("./Assumptions")
local Crew = require("./Crew")
local Game = require("./Game")
local Rng = require("./Rng")
local Weapon = require("./Weapon")

local Server = Game.Server
local EnemiesConfig = Game.Enemies
local STEP = Assumptions.STEP

local Arena = {}

export type Enemy = {
	type: string,
	stats: any,
	health: number,
	target: number,
	distance: number,
	readyAt: number,
	nextAttack: number,
	slow: number,
	burn: number,
	burnUntil: number,
	frozenUntil: number,
	stunnedUntil: number,
	lured: boolean,
	fenced: boolean,
	hunter: boolean,
	dead: boolean,
}

export type Options = {
	crew: { Crew.Member },
	partySize: number,
	rng: Rng.Rng,
	-- Vrill already in the cave, as { type, distance } (ambient groups and Spitters).
	present: { { type: string, distance: number } }?,
	-- Swarms as { at = seconds into the fight, size = Spawner.swarm size }.
	swarms: { { at: number, size: number } }?,
	-- Stop at this many seconds even if Vrill remain (Lift Pod countdown).
	duration: number?,
	-- Refinery pumping: seconds of pumping needed, pipe segments, and the repeat swarm cadence.
	pump: { seconds: number, segments: number }?,
	-- The team's Ferrin pool: a resupply pod is called mid-fight when the crew runs low.
	pool: { ferrin: number, resupplies: number }?,
}

export type Result = {
	seconds: number,
	wiped: boolean,
	cleared: boolean,
	damageTaken: number,
	spawned: number,
	killed: number,
	pumpStalls: number,
}

local function queueSwarm(queue: { string }, size: number, partySize: number, rng: Rng.Rng)
	local countScale = EnemiesConfig.COUNT_SCALE[partySize]
	for enemyType, base in EnemiesConfig.SWARM do
		for _ = 1, math.max(0, math.floor(base * size * countScale + 0.5)) do
			table.insert(queue, enemyType)
		end
	end
	if rng:next() < EnemiesConfig.RAVAGER_SWARM_CHANCE * size then
		table.insert(queue, "Ravager")
	end
	for index = #queue, 2, -1 do
		local other = rng:int(1, index)
		queue[index], queue[other] = queue[other], queue[index]
	end
end

-- Expected size of a swarm before the Ravager roll, for reporting.
function Arena.swarmCount(size: number, partySize: number): number
	local count = 0
	for _, base in EnemiesConfig.SWARM do
		count += math.max(0, math.floor(base * size * EnemiesConfig.COUNT_SCALE[partySize] + 0.5))
	end
	return count + EnemiesConfig.RAVAGER_SWARM_CHANCE * size
end

local function reach(enemy: Enemy): number
	return enemy.stats.attackRange + enemy.stats.size * 0.5
end

function Arena.run(options: Options): Result
	local rng = options.rng
	local crew = options.crew
	local partySize = options.partySize
	local healthScale = EnemiesConfig.HEALTH_SCALE[partySize]
	local enemies: { Enemy } = {}
	local queue: { string } = {}
	local swarms = table.clone(options.swarms or {})
	table.sort(swarms, function(a, b)
		return a.at < b.at
	end)
	local now = 0
	local spawned, killed = 0, 0
	local damageBefore = 0
	for _, member in crew do
		damageBefore += member.damageTaken
	end

	-- Per-fight crew state.
	type Act = {
		target: Enemy?,
		weapon: string,
		busyUntil: number,
		firingUntil: number,
		restUntil: number,
		nextThrow: number,
		reviving: Crew.Member?,
		repairing: boolean,
	}
	local acts: { [Crew.Member]: Act } = {}
	for _, member in crew do
		-- Fights are separated by quiet travel: shields are back and the fight clock restarts.
		member.primary:rest()
		member.secondary:rest()
		member.lastDamaged = -math.huge
		if member.state == "up" then
			member.shield = Game.Player.MAX_SHIELD
		end
		acts[member] = {
			target = nil,
			weapon = "primary",
			busyUntil = 0,
			firingUntil = rng:exponential(Assumptions.FIRING_SPELL),
			restUntil = 0,
			nextThrow = 0,
			reviving = nil,
			repairing = false,
		}
	end

	-- Tools in play.
	local fence: { untilTime: number, damage: number, cross: number }? = nil
	local domes: { { untilTime: number, inside: { [Crew.Member]: boolean }, reduction: number } } = {}
	local decoy: { untilTime: number, radius: number, damage: number, owner: Crew.Member }? = nil
	local fenceTick = 0

	-- Pumping.
	local pump = options.pump
	local progress = 0
	local brokenSegments = 0
	local segmentDamage = 0
	local pumpStalls = 0
	local sinceSwarm = 0
	local hunterPresent = pump ~= nil
	local pool = options.pool
	local podAt: number? = nil

	local function aliveCrew(): { Crew.Member }
		local list = {}
		for _, member in crew do
			if Crew.alive(member) then
				table.insert(list, member)
			end
		end
		return list
	end

	local function spawn(enemyType: string, distance: number?, delay: number)
		local stats = EnemiesConfig.STATS[enemyType]
		local standing = aliveCrew()
		local target = if #standing > 0 then standing[rng:int(1, #standing)].index else 1
		local band = EnemiesConfig.EMERGE_DISTANCE
		local enemy: Enemy = {
			type = enemyType,
			stats = stats,
			health = stats.health * healthScale,
			target = target,
			distance = distance or rng:range(band[1], band[2]) * (if stats.flying then 1 else Assumptions.PATH_FACTOR),
			readyAt = now + delay,
			nextAttack = now + Server.firstAttackDelay,
			slow = 0,
			burn = 0,
			burnUntil = -1,
			frozenUntil = -1,
			stunnedUntil = -1,
			lured = false,
			fenced = false,
			hunter = hunterPresent and not stats.ranged and enemyType ~= "Ravager" and rng:chance(
				Server.structureHunterChance
			),
			dead = false,
		}
		table.insert(enemies, enemy)
		spawned += 1
	end

	for _, entry in options.present or {} do
		spawn(entry.type, entry.distance, 0)
	end

	local function memberAt(index: number): Crew.Member
		return crew[index]
	end

	local function hurt(enemy: Enemy, amount: number, kind: string?, effects: { [string]: any }?)
		if enemy.dead or amount < 0 then
			return
		end
		if enemy.frozenUntil > now and kind ~= "Cold" then
			amount *= Server.freezeDamageBonus
		end
		if effects then
			if effects.slow then
				enemy.slow = math.min(Server.slowCap, enemy.slow + effects.slow)
			end
			if effects.burn then
				enemy.burn = math.max(enemy.burn, effects.burn)
				enemy.burnUntil = now + Server.burnSeconds
			end
			if effects.freeze then
				enemy.frozenUntil = now + effects.freeze
			end
			if effects.stun then
				enemy.stunnedUntil = now + effects.stun
			end
		end
		enemy.health -= amount
		if enemy.health <= 0 then
			enemy.dead = true
			killed += 1
		end
	end

	-- Vrill chasing a crew member and close to them: what area attacks can catch.
	local function crowdOf(index: number): { Enemy }
		local list = {}
		for _, enemy in enemies do
			if
				not enemy.dead
				and enemy.readyAt <= now
				and enemy.target == index
				and not enemy.stats.flying
				and not enemy.lured
				and enemy.distance <= Assumptions.CROWD_RADIUS + 3
			then
				table.insert(list, enemy)
			end
		end
		return list
	end

	-- Hits the crowd around a centre Vrill with a blast; the centre takes `falloff`.
	local function blast(
		crowd: { Enemy },
		centre: Enemy?,
		radius: number,
		damage: number,
		falloff: number,
		effects: any,
		kind: string?
	)
		local area = math.pi * Assumptions.CROWD_RADIUS ^ 2
		local others = {}
		for _, enemy in crowd do
			if enemy ~= centre then
				table.insert(others, enemy)
			end
		end
		local expected = math.min(#others, #crowd / area * math.pi * radius ^ 2)
		local count = math.floor(expected) + (if rng:next() < expected % 1 then 1 else 0)
		if centre and falloff > 0 then
			hurt(centre, damage * falloff, kind, effects)
		end
		for _ = 1, math.min(count, #others) do
			local pick = table.remove(others, rng:int(1, #others)) :: Enemy
			hurt(pick, damage * Weapon.crowdFalloff(), kind, effects)
		end
	end

	local function domeMultiplier(member: Crew.Member): number
		local multiplier = 1
		for _, dome in domes do
			if dome.untilTime > now and dome.inside[member] then
				multiplier = math.min(multiplier, 1 - dome.reduction)
			end
		end
		return multiplier
	end

	local function shielded(member: Crew.Member): boolean
		return domeMultiplier(member) < 1
	end

	-- Crew actions ------------------------------------------------------------------------------

	local function priority(member: Crew.Member, enemy: Enemy): number
		if enemy.dead or enemy.readyAt > now then
			return math.huge
		end
		local stats = enemy.stats
		local key
		if stats.ranged then
			key = if stats.rooted then 3 else 4
		else
			local speed = math.max(1, stats.speed)
			key = math.max(0, enemy.distance - reach(enemy)) / speed
			if enemy.lured or enemy.fenced then
				key += 6
			end
			if enemy.hunter then
				key += 2
			end
		end
		if enemy.target ~= member.index then
			key += 1
		end
		return key + rng:next() * 0.3
	end

	local function pickTarget(member: Crew.Member): Enemy?
		local best, bestKey = nil, math.huge
		for _, enemy in enemies do
			local key = priority(member, enemy)
			if key < bestKey then
				best, bestKey = enemy, key
			end
		end
		return best
	end

	local function distanceTo(member: Crew.Member, enemy: Enemy): number
		if enemy.target == member.index and not enemy.stats.flying then
			return math.max(3, enemy.distance)
		end
		return Weapon.distanceFor(enemy.type, rng)
	end

	local function shoot(member: Crew.Member, act: Act, gun: Weapon.Gun, enemy: Enemy, shots: number)
		local stats = gun.stats
		for _ = 1, shots do
			if enemy.dead then
				break
			end
			local distance = distanceTo(member, enemy)
			if stats.mode == "Stream" then
				if distance <= stats.range and rng:chance(member.band.streamAim) then
					hurt(enemy, stats.damage * Server.streamTick, "Fire", { burn = stats.burnPerSecond })
				end
				local share =
					math.clamp((2 * stats.spread + Assumptions.CONE_FRONT_BONUS) / Assumptions.CONE_FRONT, 0, 1)
				for _, other in crowdOf(member.index) do
					if
						other ~= enemy
						and other.distance <= stats.range
						and (other.distance < 3 or rng:chance(share))
					then
						hurt(other, stats.damage * Server.streamTick, "Fire", { burn = stats.burnPerSecond })
					end
				end
			elseif stats.mode == "Lobbed" then
				local falloff = Weapon.lobbedFalloff(
					member.band,
					enemy.type,
					distance,
					stats.projectileSpeed or 100,
					stats.gravity or 60,
					stats.splashRadius or 8,
					rng
				)
				local crowd = if enemy.stats.flying then { enemy } else crowdOf(enemy.target)
				if falloff > 0 then
					blast(crowd, enemy, stats.splashRadius or 8, stats.damage, falloff, nil, "Explosion")
				end
			else
				local amount = Weapon.bullet(gun, enemy.type, distance, rng)
				if amount > 0 then
					hurt(enemy, amount, "Bullet", if stats.slowPerHit then { slow = stats.slowPerHit } else nil)
				end
			end
		end
		if enemy.dead then
			act.target = nil
			act.busyUntil = math.max(act.busyUntil, now + member.band.reaction)
		end
	end

	local function throwGrenade(member: Crew.Member, act: Act)
		local stats = member.grenade
		local id = member.kit.grenade
		if member.charges.grenade < 1 or now < act.nextThrow then
			return
		end
		-- The biggest crowd on the crew.
		local bestCrowd, bestIndex = {}, member.index
		for _, other in crew do
			local crowd = crowdOf(other.index)
			if #crowd > #bestCrowd then
				bestCrowd, bestIndex = crowd, other.index
			end
		end
		if id == "DecoyBeacon" then
			local approaching = 0
			for _, enemy in enemies do
				if not enemy.dead and not enemy.stats.ranged and not enemy.fenced and enemy.readyAt <= now then
					approaching += 1
				end
			end
			if approaching < member.band.grenadeCrowd or decoy then
				return
			end
			member.charges.grenade -= 1
			act.nextThrow = now + 6
			decoy = { untilTime = now + stats.lure, radius = stats.radius, damage = stats.damage, owner = member }
			for _, enemy in enemies do
				if not enemy.dead and not enemy.stats.ranged and not enemy.fenced then
					enemy.lured = true
				end
			end
			return
		end
		if #bestCrowd < member.band.grenadeCrowd then
			return
		end
		member.charges.grenade -= 1
		act.nextThrow = now + 6
		local centre = bestCrowd[rng:int(1, #bestCrowd)]
		local falloff = Weapon.lobbedFalloff(
			member.band,
			centre.type,
			15,
			Game.Tools.THROW_SPEED,
			Game.Tools.THROW_GRAVITY,
			stats.radius,
			rng
		)
		if id == "CryoBomb" then
			blast(bestCrowd, centre, stats.radius, stats.damage, falloff, { freeze = stats.freeze }, "Cold")
		elseif id == "SeismicGrenade" then
			blast(bestCrowd, centre, stats.radius, stats.damage, falloff, { stun = stats.stun }, "Explosion")
		elseif id == "ClusterBomb" then
			blast(bestCrowd, centre, stats.radius, stats.damage, falloff, nil, "Explosion")
			-- Bomblets land 5 to 12 studs out, where the crowd is thinner (half density).
			for _ = 1, stats.bomblets do
				local thinned = {}
				for _, enemy in crowdOf(bestIndex) do
					if rng:chance(0.5) then
						table.insert(thinned, enemy)
					end
				end
				blast(thinned, nil, stats.bombletRadius, stats.bombletDamage, 0, nil, "Explosion")
			end
		end
	end

	local function useSupport(member: Crew.Member, act: Act)
		local stats = member.support
		local id = member.kit.support
		if member.charges.support < 1 then
			return
		end
		if id == "ArcPylons" then
			if fence and fence.untilTime > now then
				return
			end
			local approaching = 0
			for _, enemy in enemies do
				if
					not enemy.dead
					and not enemy.stats.flying
					and not enemy.stats.rooted
					and enemy.distance > Assumptions.FENCE_DISTANCE
				then
					approaching += 1
				end
			end
			if approaching < 4 then
				return
			end
			member.charges.support -= 1
			fence = {
				untilTime = now + stats.lifetime,
				damage = stats.damagePerSecond,
				cross = member.band.placement * math.min(1, stats.maxGap / Assumptions.FENCE_FRONT),
			}
		elseif id == "AegisDome" then
			for _, dome in domes do
				if dome.untilTime > now then
					return
				end
			end
			local threat = 0
			for _, enemy in enemies do
				if not enemy.dead and enemy.readyAt <= now then
					if enemy.type == "Ravager" or enemy.stats.ranged then
						threat += 2
					elseif enemy.distance <= Assumptions.CROWD_RADIUS + 3 then
						threat += 1
					end
				end
			end
			if threat < 5 then
				return
			end
			member.charges.support -= 1
			local inside = {}
			local share = math.min(1, Assumptions.DOME_INSIDE * (stats.radius / 10) ^ 2)
			for _, other in crew do
				inside[other] = other == member or rng:chance(share)
			end
			table.insert(domes, { untilTime = now + stats.lifetime, inside = inside, reduction = stats.meleeReduction })
		elseif id == "SatchelCharge" then
			if now < act.nextThrow then
				return
			end
			local bestCrowd, owner = {}, member
			for _, other in crew do
				local crowd = crowdOf(other.index)
				if #crowd > #bestCrowd then
					bestCrowd, owner = crowd, other
				end
			end
			if #bestCrowd < member.band.grenadeCrowd + 1 then
				return
			end
			member.charges.support -= 1
			act.nextThrow = now + 6
			local centre = bestCrowd[rng:int(1, #bestCrowd)]
			blast(bestCrowd, centre, stats.radius, stats.damage, Weapon.crowdFalloff() + 0.2, nil, "Explosion")
			-- Satchels hurt the crew; careless throws catch the crew member the crowd is on.
			if rng:chance((1 - member.band.placement) * 0.4) then
				Crew.damage(owner, stats.damage * Weapon.crowdFalloff() * Server.satchelCrewFactor, now)
			end
		end
	end

	local function act(member: Crew.Member, dt: number)
		local state = acts[member]
		-- Uptime: alternate firing spells and gaps.
		if now >= state.firingUntil and now >= state.restUntil then
			local uptime = member.band.uptime
			local rest = Assumptions.FIRING_SPELL * (1 - uptime) / uptime
			state.restUntil = now + math.min(rng:exponential(rest), 3 * rest)
			state.firingUntil = state.restUntil + rng:exponential(Assumptions.FIRING_SPELL)
		end
		-- Nobody stops shooting with a Vrill on them.
		local pressed = false
		for _, enemy in enemies do
			if not enemy.dead and enemy.target == member.index and enemy.readyAt <= now and not enemy.stats.ranged then
				if enemy.distance <= reach(enemy) + 1 and not enemy.lured and not enemy.fenced then
					pressed = true
					break
				end
			end
		end
		local firing = (pressed or (now >= state.restUntil and now < state.firingUntil)) and now >= state.busyUntil

		if firing then
			useSupport(member, state)
			throwGrenade(member, state)
		end

		local target = state.target
		if target and target.dead then
			target = nil
			state.target = nil
		end
		if not target and now >= state.busyUntil then
			target = pickTarget(member)
			state.target = target
		end
		-- The secondary comes out when it kills this type much faster and still has ammo.
		-- With no target the weapon in hand stays in hand.
		local wantGun = state.weapon
		if target then
			wantGun = if (member.choice[target.type] or 1) < Assumptions.SECONDARY_ADVANTAGE
					and member.secondary:ammoShare() > Assumptions.SECONDARY_RESERVE
				then "secondary"
				else "primary"
		end
		local primary, secondary = member.primary, member.secondary
		-- Area weapons (flame cone, mortar) come out for a crowd, whatever single-target speed says.
		if target and not target.stats.flying then
			local crowd = #crowdOf(target.target)
			local function area(gun: Weapon.Gun): boolean
				return gun.stats.mode == "Stream" or gun.stats.mode == "Lobbed"
			end
			if crowd >= Assumptions.AREA_CROWD then
				if area(primary) and not primary:empty() then
					wantGun = "primary"
				elseif area(secondary) and secondary:ammoShare() > Assumptions.SECONDARY_RESERVE then
					wantGun = "secondary"
				end
			end
		end
		if wantGun == "primary" and primary:empty() then
			wantGun = "secondary"
		elseif wantGun == "secondary" and secondary:empty() then
			wantGun = "primary"
		end
		if wantGun ~= state.weapon then
			state.weapon = wantGun
			state.busyUntil = math.max(state.busyUntil, now + Assumptions.SWAP)
			firing = false
		end
		local gun = if state.weapon == "primary" then primary else secondary
		local other = if state.weapon == "primary" then secondary else primary
		other:idle(now)
		if target and firing and not gun:empty() then
			local shots = gun:advance(now, dt, true)
			shoot(member, state, gun, target, shots)
		elseif target and firing and target.distance <= reach(target) + 2 and target.target == member.index then
			-- Out of ammo: the pickaxe.
			local swings = dt / Game.Pickaxe.SWING_INTERVAL
			hurt(target, Game.Pickaxe.DAMAGE * swings * 0.8, "Melee")
			if target.dead then
				state.target = nil
			end
		else
			gun:advance(now, dt, false)
			gun:idle(now)
		end
	end

	-- Main loop -------------------------------------------------------------------------------

	local spawnClock = 0
	local result: Result = {
		seconds = 0,
		wiped = false,
		cleared = false,
		damageTaken = 0,
		spawned = 0,
		killed = 0,
		pumpStalls = 0,
	}
	local limit = options.duration or 900
	while now < limit do
		-- Swarms due, and the pump's own cadence.
		while #swarms > 0 and swarms[1].at <= now do
			local swarm = table.remove(swarms, 1) :: any
			queueSwarm(queue, swarm.size, partySize, rng)
		end
		if pump then
			sinceSwarm += STEP
			if sinceSwarm >= Server.refinerySwarmEvery then
				sinceSwarm = 0
				queueSwarm(queue, Server.refineryRepeatSwarm, partySize, rng)
			end
		end

		-- A resupply pod when ammo or health runs low (or someone bled out), if Ferrin allows.
		if pool then
			if podAt and now >= podAt then
				podAt = nil
				for _, member in crew do
					Crew.refill(member)
				end
			elseif not podAt and pool.ferrin >= Game.Resources.RESUPPLY_COST then
				local ammo, health, kit, dead = 0, 0, 0, false
				for _, member in crew do
					ammo += Crew.ammo(member)
					health += member.health / Game.Player.MAX_HEALTH
					kit += Crew.kit(member)
					dead = dead or member.state == "dead"
				end
				local low = Assumptions.RESUPPLY_AT
				if dead or ammo / #crew < low or health / #crew < low or kit / #crew < low then
					pool.ferrin -= Game.Resources.RESUPPLY_COST
					pool.resupplies += 1
					podAt = now + Assumptions.RESUPPLY_SECONDS
				end
			end
		end

		-- Spawner drains twice a second while anyone stands.
		spawnClock += STEP
		local standing = aliveCrew()
		if spawnClock >= 0.5 and #standing > 0 then
			spawnClock = 0
			local alive = 0
			for _, enemy in enemies do
				if not enemy.dead then
					alive += 1
				end
			end
			while #queue > 0 and alive < EnemiesConfig.MAX_ALIVE do
				spawn(table.remove(queue, 1) :: string, nil, EnemiesConfig.EMERGE_SECONDS * 0.5)
				alive += 1
			end
		end

		-- Vrill think.
		local decoyActive = decoy ~= nil and decoy.untilTime > now
		if decoy and not decoyActive then
			local lured = {}
			for _, enemy in enemies do
				if enemy.lured and not enemy.dead then
					table.insert(lured, enemy)
					enemy.lured = false
					enemy.distance = math.max(enemy.distance, 15)
				end
			end
			local share = Assumptions.DECOY_PACK * math.min(1, (decoy.radius / 7) ^ 2)
			for _, enemy in lured do
				if rng:chance(share) then
					hurt(enemy, decoy.damage * Weapon.crowdFalloff(), "Explosion")
				end
			end
			decoy = nil
		end
		fenceTick += STEP
		local fenceDamage = fence ~= nil and fence.untilTime > now and fenceTick >= Server.pylonTick
		if fenceDamage then
			fenceTick = 0
		end
		for _, enemy in enemies do
			if enemy.dead or enemy.readyAt > now then
				continue
			end
			if enemy.burnUntil > now then
				hurt(enemy, enemy.burn * STEP, "Fire")
				if enemy.dead then
					continue
				end
			end
			enemy.slow = math.max(0, enemy.slow - STEP * Server.slowDecayPerSecond)
			if enemy.fenced then
				if fence and fence.untilTime > now then
					if fenceDamage then
						hurt(enemy, fence.damage * Server.pylonTick, "Electric", { stun = Server.pylonStun })
					end
					continue
				end
				enemy.fenced = false
			end
			if enemy.frozenUntil > now or enemy.stunnedUntil > now then
				continue
			end
			local target = memberAt(enemy.target)
			if not Crew.alive(target) then
				local standingNow = aliveCrew()
				if #standingNow == 0 then
					continue
				end
				enemy.target = standingNow[rng:int(1, #standingNow)].index
				enemy.distance = math.max(enemy.distance, 8)
				target = memberAt(enemy.target)
			end
			local stats = enemy.stats
			local speed = stats.speed * math.max(Server.minSpeedFraction, 1 - enemy.slow)
			if stats.ranged then
				if stats.flying and enemy.distance > Assumptions.TARGETS.Wasp.distance then
					enemy.distance = math.max(Assumptions.TARGETS.Wasp.distance, enemy.distance - speed * STEP)
				end
				if enemy.distance <= stats.attackRange and now >= enemy.nextAttack then
					enemy.nextAttack = now + stats.attackCooldown
					if not shielded(target) and rng:chance(target.band.spitTaken) then
						Crew.damage(target, stats.damage, now)
					end
				end
				continue
			end
			if enemy.lured then
				continue
			end
			if enemy.hunter and pump then
				-- Structure hunters break pipe instead of chasing the crew.
				if enemy.distance > reach(enemy) then
					enemy.distance -= speed * STEP
				elseif now >= enemy.nextAttack then
					enemy.nextAttack = now + stats.attackCooldown
					segmentDamage += stats.damage
					if segmentDamage >= Server.pipeHealth then
						segmentDamage = 0
						brokenSegments += 1
						pumpStalls += 1
					end
				end
				continue
			end
			-- Ravager charge.
			local band = stats.chargeRange
			if band and now >= enemy.nextAttack and enemy.distance >= band[1] and enemy.distance <= band[2] then
				enemy.nextAttack = now + Server.chargeCooldown
				if rng:chance(target.band.chargeTaken) then
					Crew.damage(target, (stats.chargeDamage or stats.damage) * domeMultiplier(target), now)
				end
				enemy.distance = Server.chargeOvershoot
				continue
			end
			local before = enemy.distance
			if enemy.distance > reach(enemy) then
				enemy.distance = math.max(reach(enemy), enemy.distance - speed * STEP)
			elseif now >= enemy.nextAttack then
				enemy.nextAttack = now + stats.attackCooldown
				if rng:chance(target.band.meleeTaken) then
					Crew.damage(target, stats.damage * domeMultiplier(target), now)
				end
			end
			-- Walking into a live fence.
			if
				fence
				and fence.untilTime > now
				and before > Assumptions.FENCE_DISTANCE
				and enemy.distance <= Assumptions.FENCE_DISTANCE
				and rng:chance(fence.cross)
			then
				enemy.fenced = true
			end
		end

		-- Crew.
		for _, member in crew do
			Crew.tick(member, now, STEP)
			if member.left then
				continue
			end
			local state = acts[member]
			if member.state == "downed" then
				if now >= member.bleedUntil then
					member.state = "dead"
				end
				continue
			end
			if member.state ~= "up" then
				continue
			end
			if state.reviving then
				if now >= state.busyUntil then
					local patient = state.reviving :: Crew.Member
					if patient.state == "downed" then
						patient.state = "up"
						patient.health = math.max(1, Game.Player.MAX_HEALTH * Game.Player.REVIVE_HEALTH_FRACTION)
						patient.lastDamaged = now
					end
					state.reviving = nil
				end
				continue
			end
			if state.repairing then
				if now >= state.busyUntil then
					state.repairing = false
					brokenSegments = math.max(0, brokenSegments - 1)
				end
				continue
			end
			-- Revive a downed teammate nobody is helping yet.
			local patient = nil
			for _, other in crew do
				if other.state == "downed" and not other.left then
					local taken = false
					for _, helper in crew do
						if acts[helper].reviving == other then
							taken = true
						end
					end
					if not taken then
						patient = other
					end
				end
			end
			if patient then
				state.reviving = patient
				state.busyUntil = now + Assumptions.REVIVE_TRAVEL + Game.Player.REVIVE_SECONDS
				state.target = nil
				continue
			end
			-- Fix the pump.
			if pump and brokenSegments > 0 then
				local fixing = 0
				for _, helper in crew do
					if acts[helper].repairing then
						fixing += 1
					end
				end
				if fixing < brokenSegments then
					state.repairing = true
					state.busyUntil = now + Assumptions.REPAIR_TRAVEL + Assumptions.REPAIR_HOLD
					continue
				end
			end
			act(member, STEP)
		end

		-- Pumping progress pauses while any segment is broken.
		if pump and brokenSegments == 0 then
			progress += STEP / pump.seconds
		end

		now += STEP
		-- End of fight checks.
		local standingNow = aliveCrew()
		local anyAlive = false
		for _, member in crew do
			if member.state ~= "dead" and not member.left then
				anyAlive = true
			end
		end
		-- The mission fails the moment nobody is standing (Revive.luau).
		if #standingNow == 0 or not anyAlive then
			result.wiped = true
			break
		end
		if pump then
			if progress >= 1 then
				result.cleared = true
				break
			end
		elseif not options.duration then
			local remaining = #queue + #swarms
			for _, enemy in enemies do
				if not enemy.dead then
					remaining += 1
				end
			end
			if remaining == 0 then
				result.cleared = true
				break
			end
		end
		-- Drop the dead now and then to keep the scan short.
		if #enemies > 60 then
			local live = {}
			for _, enemy in enemies do
				if not enemy.dead then
					table.insert(live, enemy)
				end
			end
			enemies = live
		end
	end

	-- Leftover Vrill keep their grudge into the next phase only through `present`; the caller
	-- reads them from the result.
	local remaining = {}
	for _, enemy in enemies do
		if not enemy.dead and enemy.readyAt <= now then
			table.insert(remaining, { type = enemy.type, distance = math.max(enemy.distance, 20) })
		end
	end
	for _, enemyType in queue do
		table.insert(remaining, { type = enemyType, distance = 35 })
	end
	local damageAfter = 0
	for _, member in crew do
		damageAfter += member.damageTaken
	end
	result.seconds = now
	result.damageTaken = damageAfter - damageBefore
	result.spawned = spawned
	result.killed = killed
	result.pumpStalls = pumpStalls;
	(result :: any).remaining = remaining;
	(result :: any).progress = progress
	return result
end

return Arena
