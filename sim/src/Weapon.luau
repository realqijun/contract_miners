--!strict
-- One class weapon in a player's hands: when it fires, and what each shot does to a Vrill.
--
-- Cadence follows the client firing loop (src/client/Equipment/WeaponItem.luau) and the server's
-- validation (src/server/Equipment/Weapons.luau): magazines and reloads, bursts and their pause,
-- the rotary cannon's spin-up, heat and the client's 0.99 heat guard, the stream's 0.1 s ticks
-- gated by the server's fire-rate tokens, and the Arc Mortar's reload 0.25 s after the last shell.
-- Server heat cools at the *base* config rate, as the server does today.
--
-- Shot resolution turns the skill band and target geometry into hit chances: aim error, tracking
-- lag, residual recoil and the weapon's spread combine into one Gaussian error, which is compared
-- with the angular size of the body and of the weakspot at the engagement distance.

local Assumptions = require("./Assumptions")
local Bands = require("./Bands")
local Game = require("./Game")
local Rng = require("./Rng")

local Server = Game.Server

local Weapon = {}
Weapon.__index = Weapon

-- RATE_BURST in the server: shots the fire-rate bucket may bank.
local RATE_BURST = 4
-- The client stops a spin weapon at this heat.
local HEAT_GUARD = 0.99

export type Gun = {
	id: string,
	stats: any,
	band: Bands.Band,
	baseCool: number,
	mag: number,
	reserve: number,
	reloading: boolean,
	reloadUntil: number,
	heat: number,
	lockedUntil: number,
	lastFire: number,
	nextShot: number,
	burstShot: number,
	spinning: boolean,
	venting: boolean,
	tokens: number,
	tokenTime: number,
	profiles: { [string]: any },
}

function Weapon.new(id: string, stats: any, band: Bands.Band): Gun
	local base = Game.Weapons.STATS[id]
	local self = {
		id = id,
		stats = stats,
		band = band,
		baseCool = base.coolPerSecond or 0.5,
		mag = stats.magazine,
		reserve = stats.reserve,
		reloading = false,
		reloadUntil = 0,
		heat = 0,
		lockedUntil = 0,
		lastFire = -math.huge,
		nextShot = 0,
		burstShot = 0,
		spinning = false,
		venting = false,
		tokens = RATE_BURST,
		tokenTime = 0,
		profiles = {},
	}
	return setmetatable(self, Weapon) :: any
end

function Weapon.interval(self: Gun): number
	local interval = 60 / self.stats.rpm
	if self.stats.mode == "Semi" then
		interval = math.max(interval, Assumptions.CLICK_INTERVAL)
	end
	return interval
end

function Weapon.refill(self: Gun)
	self.mag = self.stats.magazine
	self.reserve = self.stats.reserve
	self.reloading = false
	self.heat = 0
end

-- Share of a full load (magazine and reserve) left.
function Weapon.ammoShare(self: Gun): number
	if self.stats.mode == "Spin" then
		return 1
	end
	return (self.mag + self.reserve) / (self.stats.magazine + self.stats.reserve)
end

function Weapon.empty(self: Gun): boolean
	return self.stats.mode ~= "Spin" and self.mag <= 0 and self.reserve <= 0 and not self.reloading
end

local function startReload(self: Gun, at: number)
	if self.reloading or self.reserve <= 0 or self.mag >= self.stats.magazine then
		return
	end
	self.reloading = true
	local delay = if self.stats.mode == "Lobbed" then 0.25 else 0
	self.reloadUntil = at + delay + self.stats.reloadTime
end

local function finishReload(self: Gun, now: number)
	if self.reloading and now >= self.reloadUntil then
		local moved = math.min(self.stats.magazine - self.mag, self.reserve)
		self.mag += moved
		self.reserve -= moved
		self.reloading = false
	end
end

-- Advances the gun by `dt` seconds from `now`, with the trigger held if `firing`.
-- Returns the number of shots (or stream ticks) the server accepted in that time.
function Weapon.advance(self: Gun, now: number, dt: number, firing: boolean): number
	local stats = self.stats
	local finish = now + dt
	finishReload(self, now)
	local shots = 0
	local mode = stats.mode
	if mode == "Spin" then
		if self.venting and self.heat <= Assumptions.SPIN_RESUME_HEAT then
			self.venting = false
		end
		if firing and not self.venting and now >= self.lockedUntil then
			if not self.spinning then
				self.spinning = true
				self.nextShot = now + (stats.spinUp or 0.5)
			end
			local interval = 60 / stats.rpm
			while self.nextShot < finish and self.heat < HEAT_GUARD do
				self.heat = math.min(1, self.heat + (stats.heatPerShot or 0))
				if self.heat >= 1 then
					self.lockedUntil = self.nextShot + (stats.overheatLockout or 2)
				end
				self.lastFire = self.nextShot
				self.nextShot += interval
				shots += 1
			end
			if self.heat >= HEAT_GUARD then
				self.venting = true
				self.spinning = false
			end
		else
			self.spinning = false
		end
		-- The server cools only after a quarter second without a fire request.
		if finish - self.lastFire > 0.25 then
			self.heat = math.max(0, self.heat - self.baseCool * dt)
		end
		return shots
	end

	if mode == "Stream" then
		local perTick = math.max(1, math.floor(stats.rpm / 60 * Server.streamTick + 0.5))
		if firing and not self.reloading and self.mag > 0 then
			if self.nextShot < now then
				self.nextShot = now
			end
			while self.nextShot < finish and self.mag > 0 do
				local at = self.nextShot
				self.tokens = math.min(RATE_BURST, self.tokens + (at - self.tokenTime) * stats.rpm / 60)
				self.tokenTime = at
				if self.tokens >= perTick * 0.8 then
					self.tokens -= perTick
					self.mag = math.max(0, self.mag - perTick)
					shots += 1
				end
				self.nextShot += Server.streamTick
			end
			if self.mag <= 0 then
				startReload(self, now)
			end
		end
		self.tokens = math.min(RATE_BURST, self.tokens + (finish - self.tokenTime) * stats.rpm / 60)
		self.tokenTime = finish
		return shots
	end

	if firing and not self.reloading and self.mag > 0 then
		local interval = Weapon.interval(self)
		if self.nextShot < now then
			self.nextShot = now
			self.burstShot = 0
		end
		while self.nextShot < finish and self.mag > 0 do
			self.mag -= 1
			self.lastFire = self.nextShot
			shots += 1
			if mode == "Burst" then
				self.burstShot += 1
				if self.burstShot >= (stats.burstCount or 3) then
					self.burstShot = 0
					self.nextShot += interval + (stats.burstDelay or 0.25) + Assumptions.REPRESS
				else
					self.nextShot += interval
				end
			else
				self.nextShot += interval
			end
		end
		if self.mag <= 0 then
			self.burstShot = 0
			startReload(self, self.lastFire)
		end
	end
	return shots
end

-- Between fights, or while not firing: top up a part-empty magazine.
function Weapon.idle(self: Gun, now: number)
	finishReload(self, now)
	if self.stats.mode ~= "Spin" and self.mag < self.stats.magazine * Assumptions.TACTICAL_RELOAD then
		startReload(self, now)
	end
end

-- Between fights: any reload finishes, heat vents, and the fight clock starts again at zero.
function Weapon.rest(self: Gun)
	if self.reloading then
		self.reloadUntil = -math.huge
		finishReload(self, 0)
	end
	self.heat = 0
	self.venting = false
	self.spinning = false
	self.lockedUntil = 0
	self.lastFire = -math.huge
	self.nextShot = 0
	self.burstShot = 0
	self.tokenTime = 0
	self.tokens = RATE_BURST
	Weapon.idle(self, 0)
end

-- Shot resolution -----------------------------------------------------------------------------

export type Profile = {
	inRange: boolean,
	weak: number,
	armor: number,
	flesh: number,
}

-- Chances that one bullet lands on the weakspot, an armour plate or plain flesh.
function Weapon.profile(self: Gun, enemyType: string, distance: number): Profile
	local key = enemyType .. "@" .. math.floor(distance + 0.5)
	local cached = self.profiles[key]
	if cached then
		return cached
	end
	local stats, band = self.stats, self.band
	local target = Assumptions.TARGETS[enemyType]
	local d = math.max(2, distance)
	local profile: Profile
	if d > stats.range then
		profile = { inRange = false, weak = 0, armor = 0, flesh = 0 }
	else
		local recoil = stats.recoil
			* band.recoilResidual
			* math.min(1, Assumptions.RECOIL_RECOVERY / Weapon.interval(self))
		local track = math.deg(target.lateral / d) * band.trackLag
		local sigma2 = band.aim ^ 2 + track ^ 2 + recoil ^ 2 + (stats.spread / 2) ^ 2
		local body = math.deg(math.atan(target.radius / d))
		local weakspot = math.deg(math.atan(target.weakRadius / d))
		local pBody = 1 - math.exp(-body ^ 2 / (2 * sigma2))
		local pWeak = 1 - math.exp(-weakspot ^ 2 / (2 * sigma2))
		local intent = band.weakspotIntent * target.exposure
		local incidental = (target.weakRadius / target.radius) ^ 2 * target.exposure
		local weak = intent * pWeak + (1 - intent) * pBody * incidental
		local bodyHits = math.max(0, intent * (pBody - pWeak) + (1 - intent) * pBody * (1 - incidental))
		profile = {
			inRange = true,
			weak = weak,
			armor = bodyHits * target.armorShare,
			flesh = bodyHits * (1 - target.armorShare),
		}
	end
	self.profiles[key] = profile
	return profile
end

-- Typical distance to a Vrill of this type; Wasps sometimes dip close.
function Weapon.distanceFor(enemyType: string, rng: Rng.Rng): number
	local target = Assumptions.TARGETS[enemyType]
	if target.nearShare and rng:chance(target.nearShare) then
		return target.nearDistance :: number
	end
	return target.distance
end

-- Damage one hitscan shot (all its pellets) deals to its target; 0 on a miss. The freeze bonus is
-- applied by whoever applies the damage.
function Weapon.bullet(self: Gun, enemyType: string, distance: number, rng: Rng.Rng): number
	local stats = self.stats
	local enemy = Game.Enemies.STATS[enemyType]
	local profile = Weapon.profile(self, enemyType, distance)
	local total = 0
	for _ = 1, stats.pellets do
		local roll = rng:next()
		local amount = 0
		if roll < profile.weak then
			amount = stats.damage * stats.weakspotMultiplier * enemy.weakspotBonus
		elseif roll < profile.weak + profile.armor then
			amount = stats.damage * (if stats.piercesArmor then 1 else enemy.armorFactor)
		elseif roll < profile.weak + profile.armor + profile.flesh then
			amount = stats.damage
		end
		total += amount
	end
	return total
end

-- Splash falloff for the main target of a lobbed shell or thrown grenade (0 = missed entirely).
function Weapon.lobbedFalloff(
	band: Bands.Band,
	enemyType: string,
	distance: number,
	speed: number,
	gravity: number,
	radius: number,
	rng: Rng.Rng
): number
	local target = Assumptions.TARGETS[enemyType]
	local flight = distance / speed
	local lead = target.lateral * flight * band.leadError
	local drop = 0.5 * gravity * flight ^ 2 * 0.15
	local sigma = math.sqrt(band.lobError ^ 2 + lead ^ 2 + drop ^ 2)
	local miss = math.sqrt(rng:normal() ^ 2 + rng:normal() ^ 2) * sigma
	local reach = math.max(0, miss - target.radius * 0.5)
	if reach > radius then
		return 0
	end
	return 1 - Server.explosionEdge * math.clamp(reach / radius, 0, 1)
end

-- Average falloff for Vrill scattered evenly inside a blast: 1 - edge x 2/3.
function Weapon.crowdFalloff(): number
	return 1 - Server.explosionEdge * 2 / 3
end

return Weapon
