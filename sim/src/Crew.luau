--!strict
-- A crew member for the mission simulation: class kit with upgraded stats (through the game's own
-- Stats module), vitals, ammo, tool and grenade charges. Members persist across a mission's fights.

local Bands = require("./Bands")
local Duel = require("./Duel")
local Game = require("./Game")
local Weapon = require("./Weapon")

local Crew = {}

export type Member = {
	index: number,
	classId: string,
	band: Bands.Band,
	upgrades: { string },
	kit: any,
	primary: Weapon.Gun,
	secondary: Weapon.Gun,
	traversal: any,
	support: any,
	grenade: any,
	charges: { [string]: number },
	regen: { [string]: number },
	-- Secondary time-to-kill over primary time-to-kill, per enemy type.
	choice: { [string]: number },
	health: number,
	shield: number,
	lastDamaged: number,
	state: "up" | "downed" | "dead",
	bleedUntil: number,
	damageTaken: number,
	downs: number,
	left: boolean,
}

local ENEMY_TYPES = { "Drone", "Warrior", "Bulwark", "Spitter", "Wasp", "Ravager" }
local choiceCache: { [string]: { [string]: number } } = {}

-- How much faster the secondary kills each Vrill type than the primary (secondary / primary time).
-- A spinning primary is compared without its spin-up, since in a fight it keeps spinning.
local function choices(kit: any, upgrades: { string }, band: Bands.Band, partySize: number): { [string]: number }
	local key = `{kit.primary}|{kit.secondary}|{table.concat(upgrades, ",")}|{band.name}|{partySize}`
	local cached = choiceCache[key]
	if cached then
		return cached
	end
	local result = {}
	local spinUp = Game.Stats.weapon(kit.primary, upgrades).spinUp or 0
	for _, enemyType in ENEMY_TYPES do
		local primary = Duel.ttk(kit.primary, upgrades, enemyType, partySize, band, 40, 11).mean
		local secondary = Duel.ttk(kit.secondary, upgrades, enemyType, partySize, band, 40, 11).mean
		result[enemyType] = secondary / math.max(0.05, primary - spinUp)
	end
	choiceCache[key] = result
	return result
end

function Crew.new(index: number, classId: string, upgrades: { string }, band: Bands.Band, partySize: number): Member
	local kit = Game.Kits.BY_CLASS[classId]
	local member = {
		index = index,
		classId = classId,
		band = band,
		upgrades = upgrades,
		kit = kit,
		primary = Weapon.new(kit.primary, Game.Stats.weapon(kit.primary, upgrades), band),
		secondary = Weapon.new(kit.secondary, Game.Stats.weapon(kit.secondary, upgrades), band),
		traversal = Game.Stats.tool(kit.traversal, upgrades),
		support = Game.Stats.tool(kit.support, upgrades),
		grenade = Game.Stats.tool(kit.grenade, upgrades),
		charges = {},
		regen = {},
		choice = choices(kit, upgrades, band, partySize),
		health = Game.Player.MAX_HEALTH,
		shield = Game.Player.MAX_SHIELD,
		lastDamaged = -math.huge,
		state = "up",
		bleedUntil = 0,
		damageTaken = 0,
		downs = 0,
		left = false,
	}
	Crew.refill(member :: any)
	return member :: any
end

-- A resupply pod: full ammo, health, shield, tool and grenade charges; the fallen stand up again.
function Crew.refill(member: Member)
	member.primary:refill()
	member.secondary:refill()
	for _, slot in { "traversal", "support", "grenade" } do
		local stats = (member :: any)[slot]
		member.charges[slot] = stats.charges
		member.regen[slot] = 0
	end
	if member.state == "dead" or member.state == "up" then
		member.state = "up"
		member.health = Game.Player.MAX_HEALTH
		member.shield = Game.Player.MAX_SHIELD
	end
end

function Crew.alive(member: Member): boolean
	return member.state == "up" and not member.left
end

-- Applies damage like Vitals.damage: shield first, downed at zero.
function Crew.damage(member: Member, amount: number, now: number)
	if member.state ~= "up" or amount <= 0 then
		return
	end
	member.lastDamaged = now
	member.damageTaken += amount
	local absorbed = math.min(member.shield, amount)
	member.shield -= absorbed
	local health = member.health - (amount - absorbed)
	if health <= 0 then
		member.health = 1
		member.shield = 0
		member.state = "downed"
		member.bleedUntil = now + Game.Player.BLEED_OUT_SECONDS
		member.downs += 1
	else
		member.health = health
	end
end

function Crew.heal(member: Member, amount: number)
	if member.state == "up" then
		member.health = math.min(Game.Player.MAX_HEALTH, member.health + amount)
	end
end

-- Shield recharge after the quiet spell, and tool charges regenerating over time.
function Crew.tick(member: Member, now: number, dt: number)
	if
		member.state == "up"
		and member.shield < Game.Player.MAX_SHIELD
		and now - member.lastDamaged >= Game.Player.SHIELD_REGEN_DELAY
	then
		member.shield = math.min(Game.Player.MAX_SHIELD, member.shield + Game.Player.SHIELD_REGEN_PER_SECOND * dt)
	end
	for _, slot in { "traversal", "support", "grenade" } do
		local stats = (member :: any)[slot]
		if stats.regenPerSecond > 0 and member.charges[slot] < stats.charges then
			member.regen[slot] += stats.regenPerSecond * dt
			if member.regen[slot] >= 1 then
				member.regen[slot] -= 1
				member.charges[slot] += 1
			end
		end
	end
end

-- Share of grenade and support charges left.
function Crew.kit(member: Member): number
	local grenade = member.charges.grenade / math.max(1, member.grenade.charges)
	local support = member.charges.support / math.max(1, member.support.charges)
	return (grenade + support) / 2
end

-- Average share of ammo left across both weapons.
function Crew.ammo(member: Member): number
	return (member.primary:ammoShare() + member.secondary:ammoShare()) / 2
end

return Crew
