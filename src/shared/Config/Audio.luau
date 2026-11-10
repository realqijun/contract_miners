--!strict
-- Every sound the game plays. All of it is from Roblox's licensed library: music and stingers
-- from APM Music, effects from Pro Sound Effects, and a few sounds built into the Roblox client.

local Audio = {}

export type Group = "Music" | "Effects"

export type Sound = {
	id: string,
	group: Group,
	volume: number,
	-- Playback speed; also shifts the pitch.
	speed: number?,
	-- Random speed variation either way, so repeats do not sound identical.
	vary: number?,
	-- The same sound will not start again sooner than this many seconds.
	gap: number?,
	-- Positional sounds fade out by this distance.
	reach: number?,
}

local function asset(id: number): string
	return `rbxassetid://{id}`
end

Audio.SOUNDS = {
	-- Ambience and music.
	CaveBed = { id = asset(9112795463), group = "Effects", volume = 0.35 }, -- Hollow Rumble 1
	CaveDrips = { id = asset(9126190860), group = "Effects", volume = 0.25 }, -- Water Drips Into Filled Bowl Cave 8
	CombatMusic = { id = asset(9045720406), group = "Music", volume = 0.55 }, -- Path Of Destruction (APM)
	HiveChitter = { id = asset(9113976170), group = "Effects", volume = 0.5, vary = 0.15, reach = 140 },
	HiveChitterLong = { id = asset(9113977489), group = "Effects", volume = 0.45, vary = 0.15, reach = 140 },

	-- Stingers.
	SwarmStinger = { id = asset(1837950656), group = "Music", volume = 0.7 }, -- Brute Force Sting 3 (APM)
	ObjectiveStinger = { id = asset(9047103106), group = "Music", volume = 0.7 }, -- All It Takes Sting 2 (APM)
	LiftPodStinger = { id = asset(9047101692), group = "Music", volume = 0.7 }, -- Bring The Heat Sting 2 (APM)
	CountdownBeep = { id = "rbxasset://sounds/electronicpingshort.wav", group = "Effects", volume = 0.5 },
	LiftOff = { id = "rbxasset://sounds/Launching rocket.wav", group = "Effects", volume = 0.8 },

	-- Weapons, by weapon id.
	RivetDriver = { id = asset(9117052716), group = "Effects", volume = 0.45, speed = 1.3, vary = 0.06, gap = 0.05 },
	ArcMortar = { id = "rbxasset://sounds/Shoulder fired rocket.wav", group = "Effects", volume = 0.6, vary = 0.05 },
	BurstCarbine = { id = asset(9118173739), group = "Effects", volume = 0.35, speed = 1.35, vary = 0.05, gap = 0.04 },
	BoltPistol = { id = asset(9117402631), group = "Effects", volume = 0.5, speed = 0.85, vary = 0.04 },
	RotaryCannon = { id = asset(9116361236), group = "Effects", volume = 0.35, speed = 1.1, gap = 0.18 },
	HandCannon = { id = asset(9118174539), group = "Effects", volume = 0.6, speed = 0.8, vary = 0.04 },
	FlameProjector = {
		id = "rbxasset://sounds/Rocket whoosh 01.wav",
		group = "Effects",
		volume = 0.4,
		speed = 1.6,
		gap = 0.45,
	},
	AutoPistol = { id = asset(9117399569), group = "Effects", volume = 0.4, speed = 1.15, vary = 0.06, gap = 0.04 },

	-- Impacts and the world.
	RockImpact = { id = asset(9118598279), group = "Effects", volume = 0.35, vary = 0.15, gap = 0.05, reach = 90 },
	FleshImpact = {
		id = asset(9118598470),
		group = "Effects",
		volume = 0.3,
		speed = 1.6,
		vary = 0.15,
		gap = 0.05,
		reach = 90,
	},
	PickaxeHit = { id = asset(9118617342), group = "Effects", volume = 0.5, vary = 0.1, reach = 80 },
	Explosion = {
		id = "rbxasset://sounds/impact_explosion_03.mp3",
		group = "Effects",
		volume = 0.8,
		vary = 0.08,
		reach = 300,
	},
	Burrow = { id = asset(9114083746), group = "Effects", volume = 0.6, vary = 0.1, gap = 0.1, reach = 120 },
	EnemyAttack = { id = asset(9113977066), group = "Effects", volume = 0.5, vary = 0.2, gap = 0.08, reach = 100 },
	EnemyDeath = {
		id = asset(9113977177),
		group = "Effects",
		volume = 0.45,
		speed = 0.8,
		vary = 0.2,
		gap = 0.05,
		reach = 110,
	},
} :: { [string]: Sound }

-- Combat music comes in while Vrill are close, and fades once they have been gone this long.
Audio.COMBAT_NEAR = 60
Audio.COMBAT_COUNT = 3
Audio.COMBAT_LINGER = 8
Audio.COMBAT_FADE = 2.5
-- Seconds between distant hive chitters.
Audio.CHITTER_INTERVAL = { 12, 26 }

return Audio
