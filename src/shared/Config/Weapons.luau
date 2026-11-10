--!strict
-- Base stats for every class weapon. Upgrades modify these through Config/Upgrades.
-- Damage is per bullet (or per pellet, or per second for streams).

export type WeaponId =
	"RivetDriver"
	| "ArcMortar"
	| "BurstCarbine"
	| "BoltPistol"
	| "RotaryCannon"
	| "HandCannon"
	| "FlameProjector"
	| "AutoPistol"

-- Auto: fires while held. Semi: one shot per press. Burst: a fixed burst per press.
-- Spin: spins up before firing and builds heat. Stream: a continuous short-range cone.
-- Lobbed: an arcing explosive projectile.
export type FireMode = "Auto" | "Semi" | "Burst" | "Spin" | "Stream" | "Lobbed"

export type Stats = {
	id: WeaponId,
	displayName: string,
	description: string,
	mode: FireMode,
	damage: number,
	-- Shots per minute (for Burst: within a burst).
	rpm: number,
	magazine: number,
	reserve: number,
	reloadTime: number,
	-- Cone half-angle in degrees.
	spread: number,
	pellets: number,
	range: number,
	weakspotMultiplier: number,
	-- Ignores armour plates.
	piercesArmor: boolean,
	-- Burst
	burstCount: number?,
	burstDelay: number?,
	-- Spin
	spinUp: number?,
	heatPerShot: number?,
	coolPerSecond: number?,
	overheatLockout: number?,
	-- Lobbed
	projectileSpeed: number?,
	gravity: number?,
	splashRadius: number?,
	-- Status effects applied on hit.
	slowPerHit: number?,
	burnPerSecond: number?,
	-- Recoil kick in degrees.
	recoil: number,
}

local Weapons = {}

Weapons.STATS = {
	RivetDriver = {
		id = "RivetDriver",
		displayName = "Rivet Driver",
		description = "Fast-firing nail gun. Hits briefly slow small Vrill.",
		mode = "Auto",
		damage = 9,
		rpm = 600,
		magazine = 40,
		reserve = 320,
		reloadTime = 1.8,
		spread = 1.4,
		pellets = 1,
		range = 160,
		weakspotMultiplier = 2,
		piercesArmor = false,
		slowPerHit = 0.06,
		recoil = 0.35,
	},
	ArcMortar = {
		id = "ArcMortar",
		displayName = "Arc Mortar",
		description = "Single-shot lobbed explosive with heavy splash damage.",
		mode = "Lobbed",
		damage = 90,
		rpm = 60,
		magazine = 1,
		reserve = 14,
		reloadTime = 2.1,
		spread = 0,
		pellets = 1,
		range = 200,
		weakspotMultiplier = 1,
		piercesArmor = true,
		projectileSpeed = 115,
		gravity = 70,
		splashRadius = 9,
		recoil = 4,
	},
	BurstCarbine = {
		id = "BurstCarbine",
		displayName = "Burst Carbine",
		description = "Accurate three-round bursts with bonus weakspot damage.",
		mode = "Burst",
		damage = 15,
		rpm = 900,
		magazine = 30,
		reserve = 300,
		reloadTime = 1.6,
		spread = 0.5,
		pellets = 1,
		range = 220,
		weakspotMultiplier = 2.6,
		piercesArmor = false,
		burstCount = 3,
		burstDelay = 0.28,
		recoil = 0.6,
	},
	BoltPistol = {
		id = "BoltPistol",
		displayName = "Bolt Pistol",
		description = "Slow, heavy bolts that punch through Bulwark armour.",
		mode = "Semi",
		damage = 48,
		rpm = 150,
		magazine = 8,
		reserve = 72,
		reloadTime = 1.7,
		spread = 0.3,
		pellets = 1,
		range = 220,
		weakspotMultiplier = 2,
		piercesArmor = true,
		recoil = 3,
	},
	RotaryCannon = {
		id = "RotaryCannon",
		displayName = "Rotary Cannon",
		description = "Spins up, then pours out fire. Builds heat instead of reloading.",
		mode = "Spin",
		damage = 10,
		rpm = 1100,
		magazine = 1600,
		reserve = 0,
		reloadTime = 0,
		spread = 2.2,
		pellets = 1,
		range = 180,
		weakspotMultiplier = 1.5,
		piercesArmor = false,
		spinUp = 0.6,
		heatPerShot = 0.006,
		coolPerSecond = 0.45,
		overheatLockout = 2.5,
		recoil = 0.2,
	},
	HandCannon = {
		id = "HandCannon",
		displayName = "Hand Cannon",
		description = "Six-shot revolver with huge damage and a big kick.",
		mode = "Semi",
		damage = 62,
		rpm = 140,
		magazine = 6,
		reserve = 60,
		reloadTime = 2.2,
		spread = 0.4,
		pellets = 1,
		range = 200,
		weakspotMultiplier = 2,
		piercesArmor = false,
		recoil = 6,
	},
	FlameProjector = {
		id = "FlameProjector",
		displayName = "Flame Projector",
		description = "Short-range cone of fire that ignites Vrill and scorches the ground.",
		mode = "Stream",
		damage = 26,
		rpm = 600,
		magazine = 200,
		reserve = 800,
		reloadTime = 2.4,
		spread = 14,
		pellets = 1,
		range = 20,
		weakspotMultiplier = 1,
		piercesArmor = true,
		burnPerSecond = 9,
		recoil = 0,
	},
	AutoPistol = {
		id = "AutoPistol",
		displayName = "Auto Pistol",
		description = "Fast-firing sidearm with a large magazine.",
		mode = "Auto",
		damage = 8,
		rpm = 840,
		magazine = 36,
		reserve = 288,
		reloadTime = 1.5,
		spread = 1.8,
		pellets = 1,
		range = 140,
		weakspotMultiplier = 1.8,
		piercesArmor = false,
		recoil = 0.4,
	},
} :: { [WeaponId]: Stats }

-- Seconds between shots.
function Weapons.interval(stats: Stats): number
	return 60 / stats.rpm
end

return Weapons
