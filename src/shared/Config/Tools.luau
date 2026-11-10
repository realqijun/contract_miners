--!strict
-- Traversal and support tools, grenades and flares. Upgrades modify these through Stats.

local Tools = {}

export type ToolStats = {
	displayName: string,
	description: string,
	charges: number,
	-- Seconds between uses.
	cooldown: number,
	range: number,
	-- Charges regained per second without a resupply (0 = only from resupply pods).
	regenPerSecond: number,
	[string]: any,
}

Tools.TOOLS = {
	FoamProjector = {
		displayName = "Foam Projector",
		description = "Fires hardfoam that sets into walkable pads on any surface.",
		charges = 30,
		cooldown = 0.35,
		range = 45,
		regenPerSecond = 0,
		padDiameter = 5,
		maxPads = 120,
	},
	ArcPylons = {
		displayName = "Arc Pylons",
		description = "Two pylons up to 15 studs apart; the fence between them shreds Vrill.",
		charges = 2,
		cooldown = 1,
		range = 30,
		regenPerSecond = 0,
		maxGap = 15,
		lifetime = 45,
		damagePerSecond = 60,
	},
	GrappleLine = {
		displayName = "Grapple Line",
		description = "Hooks a surface up to 30 studs away and reels you in.",
		-- Limited only by its cooldown.
		charges = 0,
		cooldown = 4,
		range = 30,
		regenPerSecond = 0,
		pullSpeed = 55,
	},
	LumenDarts = {
		displayName = "Lumen Darts",
		description = "Sticky darts that light a wide area and reveal nearby minerals.",
		charges = 8,
		cooldown = 0.6,
		range = 120,
		regenPerSecond = 1 / 12,
		lightRange = 48,
		lifetime = 60,
		revealRadius = 20,
		revealSeconds = 8,
	},
	CableLauncher = {
		displayName = "Cable Launcher",
		description = "Strings a cable up to 50 studs that anyone can ride either way.",
		charges = 4,
		cooldown = 1,
		range = 50,
		regenPerSecond = 0,
		maxAngle = 45,
		rideSpeed = 34,
	},
	AegisDome = {
		displayName = "Aegis Dome",
		description = "A dome that blocks Vrill spit and halves melee damage inside.",
		charges = 2,
		cooldown = 2,
		range = 0,
		regenPerSecond = 0,
		radius = 10,
		lifetime = 15,
		meleeReduction = 0.5,
	},
	PlasmaCutter = {
		displayName = "Plasma Cutter",
		description = "A beam that melts rock in any direction. Builds heat.",
		charges = 0,
		cooldown = 0.1,
		range = 14,
		regenPerSecond = 0,
		digRadius = 2.8,
		damagePerTick = 9,
		heatPerTick = 0.035,
		coolPerSecond = 0.35,
		overheatLockout = 2.5,
	},
	SatchelCharge = {
		displayName = "Satchel Charge",
		description = "Throw, then trigger again to blow a huge hole. Hurts the crew too.",
		charges = 3,
		cooldown = 0.6,
		range = 60,
		regenPerSecond = 0,
		radius = 9,
		damage = 260,
		digRadius = 7.5,
		throwSpeed = 55,
	},
} :: { [string]: ToolStats }

Tools.GRENADES = {
	DecoyBeacon = {
		displayName = "Decoy Beacon",
		description = "Pulls Vrill to it for 8 seconds, then explodes.",
		charges = 3,
		cooldown = 1,
		range = 0,
		regenPerSecond = 0,
		lure = 8,
		radius = 7,
		damage = 150,
	},
	CryoBomb = {
		displayName = "Cryo Bomb",
		description = "Freezes Vrill solid for 4 seconds. Frozen Vrill take extra damage.",
		charges = 3,
		cooldown = 1,
		range = 0,
		regenPerSecond = 0,
		radius = 8,
		damage = 20,
		freeze = 4,
	},
	ClusterBomb = {
		displayName = "Cluster Bomb",
		description = "A big blast that scatters smaller bomblets.",
		charges = 3,
		cooldown = 1,
		range = 0,
		regenPerSecond = 0,
		radius = 7,
		damage = 180,
		bomblets = 5,
		bombletRadius = 4,
		bombletDamage = 60,
	},
	SeismicGrenade = {
		displayName = "Seismic Grenade",
		description = "Blasts a crater in the rock and stuns Vrill.",
		charges = 3,
		cooldown = 1,
		range = 0,
		regenPerSecond = 0,
		radius = 8,
		damage = 120,
		digRadius = 6,
		stun = 2.5,
	},
} :: { [string]: ToolStats }

Tools.THROW_SPEED = 70
Tools.THROW_GRAVITY = 70

Tools.FLARES = {
	charges = 4,
	regenPerSecond = 1 / 15,
	lightRange = 38,
	lifetime = 40,
}

return Tools
