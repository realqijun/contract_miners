--!strict
-- Vrill types, their stats, and how the hive scales with the crew.

export type EnemyType = "Drone" | "Warrior" | "Bulwark" | "Spitter" | "Wasp" | "Ravager"

export type Stats = {
	displayName: string,
	health: number,
	-- Studs per second.
	speed: number,
	-- Melee or projectile damage per attack.
	damage: number,
	-- Reach for melee, firing range for ranged attackers.
	attackRange: number,
	attackCooldown: number,
	-- Ranged attackers fire projectiles; Rooted never move; Flying hover.
	ranged: boolean,
	rooted: boolean,
	flying: boolean,
	-- Damage taken on armoured parts by non-piercing hits.
	armorFactor: number,
	-- Extra multiplier for weakspot hits, on top of the weapon's own.
	weakspotBonus: number,
	-- Radius used for spawning clearance and melee contact.
	size: number,
	-- Charge attack (Ravager): speed and the distance band it charges from.
	chargeSpeed: number?,
	chargeRange: { number }?,
	chargeDamage: number?,
}

local Enemies = {}

Enemies.STATS = {
	Drone = {
		displayName = "Drone",
		health = 32,
		speed = 21,
		damage = 6,
		attackRange = 4.5,
		attackCooldown = 0.9,
		ranged = false,
		rooted = false,
		flying = false,
		armorFactor = 1,
		weakspotBonus = 1,
		size = 1.6,
	},
	Warrior = {
		displayName = "Warrior",
		health = 95,
		speed = 16,
		damage = 12,
		attackRange = 6,
		attackCooldown = 1.3,
		ranged = false,
		rooted = false,
		flying = false,
		armorFactor = 0.6,
		weakspotBonus = 1,
		size = 2.6,
	},
	Bulwark = {
		displayName = "Bulwark",
		health = 280,
		speed = 10,
		damage = 22,
		attackRange = 7,
		attackCooldown = 1.8,
		ranged = false,
		rooted = false,
		flying = false,
		armorFactor = 0.1,
		weakspotBonus = 1.5,
		size = 4,
	},
	Spitter = {
		displayName = "Spitter",
		health = 130,
		speed = 0,
		damage = 14,
		attackRange = 75,
		attackCooldown = 3.2,
		ranged = true,
		rooted = true,
		flying = false,
		armorFactor = 1,
		weakspotBonus = 1.5,
		size = 3,
	},
	Wasp = {
		displayName = "Wasp",
		health = 48,
		speed = 20,
		damage = 8,
		attackRange = 55,
		attackCooldown = 2.2,
		ranged = true,
		rooted = false,
		flying = true,
		armorFactor = 1,
		weakspotBonus = 1,
		size = 2,
	},
	Ravager = {
		displayName = "Ravager",
		health = 950,
		speed = 13,
		damage = 30,
		attackRange = 8,
		attackCooldown = 1.6,
		ranged = false,
		rooted = false,
		flying = false,
		armorFactor = 0.5,
		weakspotBonus = 2,
		size = 5.5,
		chargeSpeed = 42,
		chargeRange = { 16, 45 },
		chargeDamage = 35,
	},
} :: { [EnemyType]: Stats }

Enemies.MAX_ALIVE = 30

-- Indexed by party size at launch.
Enemies.HEALTH_SCALE = { 0.7, 0.85, 1, 1.15 }
Enemies.COUNT_SCALE = { 0.55, 0.75, 1, 1.2 }

-- Seconds between timed swarms.
Enemies.SWARM_INTERVAL = { 240, 360 }

-- Base swarm makeup for a full crew; counts are multiplied by COUNT_SCALE.
Enemies.SWARM = {
	Drone = 14,
	Warrior = 7,
	Bulwark = 1,
	Wasp = 3,
} :: { [EnemyType]: number }

-- A Ravager joins one swarm in this many.
Enemies.RAVAGER_SWARM_CHANCE = 0.35

-- Enemies placed in the cave at generation, per cavern other than the landing one.
Enemies.AMBIENT_PER_CAVERN = { 0, 1 }
Enemies.SPITTERS_PER_CAVERN = { 0, 1 }

-- Distance at which idle ambient enemies notice the crew.
Enemies.AGGRO_RANGE = 45

-- Spawn distance band from the target player for burrowing in.
Enemies.EMERGE_DISTANCE = { 22, 45 }
Enemies.EMERGE_SECONDS = 1.1

return Enemies
