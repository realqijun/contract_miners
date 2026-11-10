--!strict
-- Every upgrade choice: 20 items (8 weapons, 8 tools, 4 grenades) × 3 tiers × 2 choices.
-- Upgrades are pure data, a list of stat changes, so the game and the balance simulation apply
-- them identically. An upgrade's id is "<ItemId>.<tier><choice>", for example "RivetDriver.2B".

export type Op = "add" | "mul" | "set"
export type Change = { stat: string, op: Op, value: any }
export type Upgrade = { name: string, description: string, changes: { Change } }
export type Choice = "A" | "B"
-- Indexed by tier 1..3, then choice.
export type ItemUpgrades = { { A: Upgrade, B: Upgrade } }

local Upgrades = {}

local function up(name: string, description: string, changes: { { any } }): Upgrade
	local list = {}
	for _, change in changes do
		table.insert(list, { stat = change[1], op = change[2], value = change[3] })
	end
	return { name = name, description = description, changes = list }
end

Upgrades.ITEMS = {
	-- Weapons -----------------------------------------------------------------------------------
	RivetDriver = {
		{
			A = up("Hardened Rivets", "+15% damage", { { "damage", "mul", 1.15 } }),
			B = up("Deep Hopper", "+15 magazine, +80 reserve", { { "magazine", "add", 15 }, { "reserve", "add", 80 } }),
		},
		{
			A = up("Barbed Rivets", "Hits slow Vrill 60% more", { { "slowPerHit", "mul", 1.6 } }),
			B = up("Fast Feed", "+20% fire rate", { { "rpm", "mul", 1.2 } }),
		},
		{
			A = up(
				"Tungsten Tips",
				"+10% damage, much stronger weakspot hits",
				{ { "damage", "mul", 1.1 }, { "weakspotMultiplier", "add", 0.6 } }
			),
			B = up(
				"Pressure Drive",
				"Tighter spread, less recoil, longer range",
				{ { "spread", "mul", 0.6 }, { "recoil", "mul", 0.7 }, { "range", "add", 40 } }
			),
		},
	},
	ArcMortar = {
		{
			A = up("Heavy Shell", "+20% damage", { { "damage", "mul", 1.2 } }),
			B = up("Spare Shells", "+6 reserve shells", { { "reserve", "add", 6 } }),
		},
		{
			A = up("Wide Burst", "+2.5 blast radius", { { "splashRadius", "add", 2.5 } }),
			B = up("Quick Breech", "25% faster reload", { { "reloadTime", "mul", 0.75 } }),
		},
		{
			A = up("Twin Chamber", "Two shells per load", { { "magazine", "add", 1 } }),
			B = up(
				"Hot Arc",
				"Faster, flatter shells with +10% damage",
				{ { "projectileSpeed", "mul", 1.3 }, { "gravity", "mul", 0.7 }, { "damage", "mul", 1.1 } }
			),
		},
	},
	BurstCarbine = {
		{
			A = up("Match Barrel", "+15% damage", { { "damage", "mul", 1.15 } }),
			B = up(
				"Extended Mag",
				"+12 magazine, +60 reserve",
				{ { "magazine", "add", 12 }, { "reserve", "add", 60 } }
			),
		},
		{
			A = up("Quick Bursts", "40% shorter pause between bursts", { { "burstDelay", "mul", 0.6 } }),
			B = up("Four-Round Burst", "One more round per burst", { { "burstCount", "add", 1 } }),
		},
		{
			A = up("Hollow Points", "Much stronger weakspot hits", { { "weakspotMultiplier", "add", 0.8 } }),
			B = up(
				"Stabilizer",
				"Far tighter spread and half the recoil",
				{ { "spread", "mul", 0.4 }, { "recoil", "mul", 0.5 } }
			),
		},
	},
	BoltPistol = {
		{
			A = up("Heavy Bolts", "+20% damage", { { "damage", "mul", 1.2 } }),
			B = up("Bolt Pouch", "+24 reserve bolts", { { "reserve", "add", 24 } }),
		},
		{
			A = up("Fast Action", "+30% fire rate", { { "rpm", "mul", 1.3 } }),
			B = up("Speed Loader", "30% faster reload", { { "reloadTime", "mul", 0.7 } }),
		},
		{
			A = up(
				"Splitting Bolts",
				"Fires two bolts at 75% damage each",
				{ { "pellets", "add", 1 }, { "damage", "mul", 0.75 } }
			),
			B = up("Marksman Rail", "Much stronger weakspot hits", { { "weakspotMultiplier", "add", 1 } }),
		},
	},
	RotaryCannon = {
		{
			A = up("Heavier Rounds", "+15% damage", { { "damage", "mul", 1.15 } }),
			B = up("Quick Spin", "Spins up twice as fast", { { "spinUp", "mul", 0.5 } }),
		},
		{
			A = up("Heat Sinks", "30% less heat per shot", { { "heatPerShot", "mul", 0.7 } }),
			B = up(
				"Fast Cooling",
				"Cools 60% faster and recovers sooner from overheating",
				{ { "coolPerSecond", "mul", 1.6 }, { "overheatLockout", "mul", 0.6 } }
			),
		},
		{
			A = up(
				"Overdrive Motor",
				"+25% fire rate, a little more heat",
				{ { "rpm", "mul", 1.25 }, { "heatPerShot", "mul", 1.1 } }
			),
			B = up(
				"Armor Shredder",
				"Rounds ignore armour, +5% damage",
				{ { "piercesArmor", "set", true }, { "damage", "mul", 1.05 } }
			),
		},
	},
	HandCannon = {
		{
			A = up("Magnum Load", "+15% damage", { { "damage", "mul", 1.15 } }),
			B = up("Ammo Belt", "+18 reserve rounds", { { "reserve", "add", 18 } }),
		},
		{
			A = up("Quick Loader", "35% faster reload", { { "reloadTime", "mul", 0.65 } }),
			B = up("Steady Grip", "Half the recoil and spread", { { "recoil", "mul", 0.5 }, { "spread", "mul", 0.5 } }),
		},
		{
			A = up("Punch-Through", "Rounds ignore armour", { { "piercesArmor", "set", true } }),
			B = up("Hair Trigger", "+35% fire rate", { { "rpm", "mul", 1.35 } }),
		},
	},
	FlameProjector = {
		{
			A = up("Hotter Mix", "+20% damage", { { "damage", "mul", 1.2 } }),
			B = up("Bigger Tank", "+60 fuel, +200 reserve", { { "magazine", "add", 60 }, { "reserve", "add", 200 } }),
		},
		{
			A = up("Long Nozzle", "+6 stud reach", { { "range", "add", 6 } }),
			B = up("Sticky Fire", "Burning lasts hotter", { { "burnPerSecond", "mul", 1.6 } }),
		},
		{
			A = up("Wide Cone", "A broader cone of fire", { { "spread", "add", 6 } }),
			B = up("Efficient Pump", "25% less fuel per second", { { "rpm", "mul", 0.75 } }),
		},
	},
	AutoPistol = {
		{
			A = up("Hot Loads", "+15% damage", { { "damage", "mul", 1.15 } }),
			B = up("Drum Mag", "+18 magazine", { { "magazine", "add", 18 } }),
		},
		{
			A = up("Rapid Feed", "+20% fire rate", { { "rpm", "mul", 1.2 } }),
			B = up("Quick Mags", "30% faster reload", { { "reloadTime", "mul", 0.7 } }),
		},
		{
			A = up("Incendiary Rounds", "Hits set Vrill alight", { { "burnPerSecond", "set", 3 } }),
			B = up(
				"Tight Choke",
				"Half the spread, stronger weakspot hits",
				{ { "spread", "mul", 0.5 }, { "weakspotMultiplier", "add", 0.5 } }
			),
		},
	},

	-- Tools -------------------------------------------------------------------------------------
	FoamProjector = {
		{
			A = up("Big Tank", "+15 foam charges", { { "charges", "add", 15 } }),
			B = up("Quick Set", "Fires 40% faster", { { "cooldown", "mul", 0.6 } }),
		},
		{
			A = up("Wide Pads", "+2 stud pad width", { { "padDiameter", "add", 2 } }),
			B = up("Long Throw", "+20 stud range", { { "range", "add", 20 } }),
		},
		{
			A = up("Foam Synthesizer", "Regains a charge every 2 seconds", { { "regenPerSecond", "set", 0.5 } }),
			B = up("Bulk Tank", "+25 foam charges", { { "charges", "add", 25 } }),
		},
	},
	ArcPylons = {
		{
			A = up("Spare Pylons", "+1 fence", { { "charges", "add", 1 } }),
			B = up("Long Span", "+7 studs between pylons", { { "maxGap", "add", 7 } }),
		},
		{
			A = up("High Voltage", "+50% fence damage", { { "damagePerSecond", "mul", 1.5 } }),
			B = up("Long Life", "Fences last 30 seconds longer", { { "lifetime", "add", 30 } }),
		},
		{
			A = up("Overcharge", "+40% fence damage", { { "damagePerSecond", "mul", 1.4 } }),
			B = up("Field Recharger", "Regains a fence every minute", { { "regenPerSecond", "set", 1 / 60 } }),
		},
	},
	GrappleLine = {
		{
			A = up("Long Line", "+12 stud reach", { { "range", "add", 12 } }),
			B = up("Quick Reel", "40% shorter cooldown", { { "cooldown", "mul", 0.6 } }),
		},
		{
			A = up("Strong Motor", "Pulls 30% faster", { { "pullSpeed", "mul", 1.3 } }),
			B = up("Light Frame", "20% shorter cooldown", { { "cooldown", "mul", 0.8 } }),
		},
		{
			A = up("Extended Line", "+12 stud reach", { { "range", "add", 12 } }),
			B = up(
				"Snap Reel",
				"Pulls 25% faster with a shorter cooldown",
				{ { "pullSpeed", "mul", 1.25 }, { "cooldown", "mul", 0.85 } }
			),
		},
	},
	LumenDarts = {
		{
			A = up("Dart Pouch", "+4 darts", { { "charges", "add", 4 } }),
			B = up("Bright Darts", "+16 stud light radius", { { "lightRange", "add", 16 } }),
		},
		{
			A = up("Long Burn", "Darts glow a minute longer", { { "lifetime", "add", 60 } }),
			B = up("Quick Regen", "Darts regenerate twice as fast", { { "regenPerSecond", "mul", 2 } }),
		},
		{
			A = up("Mineral Sense", "+15 stud reveal radius", { { "revealRadius", "add", 15 } }),
			B = up("Lingering Reveal", "Minerals stay outlined 10 seconds longer", { { "revealSeconds", "add", 10 } }),
		},
	},
	CableLauncher = {
		{
			A = up("Extra Spools", "+2 cables", { { "charges", "add", 2 } }),
			B = up("Long Cable", "+20 stud cable length", { { "range", "add", 20 } }),
		},
		{
			A = up("Steep Rig", "Cables up to 60° steep", { { "maxAngle", "add", 15 } }),
			B = up("Fast Trolley", "Ride 40% faster", { { "rideSpeed", "mul", 1.4 } }),
		},
		{
			A = up("Spool Maker", "Regains a cable every 30 seconds", { { "regenPerSecond", "set", 1 / 30 } }),
			B = up("Mega Spool", "+3 cables", { { "charges", "add", 3 } }),
		},
	},
	AegisDome = {
		{
			A = up("Extra Emitter", "+1 dome", { { "charges", "add", 1 } }),
			B = up("Wide Field", "+3 stud radius", { { "radius", "add", 3 } }),
		},
		{
			A = up("Long Field", "Domes last 7 seconds longer", { { "lifetime", "add", 7 } }),
			B = up("Hardened Field", "Melee inside is reduced by 75%", { { "meleeReduction", "add", 0.25 } }),
		},
		{
			A = up("Field Recharger", "Regains a dome every 90 seconds", { { "regenPerSecond", "set", 1 / 90 } }),
			B = up(
				"Bastion Field",
				"+3 radius and 5 seconds longer",
				{ { "radius", "add", 3 }, { "lifetime", "add", 5 } }
			),
		},
	},
	PlasmaCutter = {
		{
			A = up("Wide Beam", "Cuts a wider tunnel", { { "digRadius", "add", 0.8 } }),
			B = up("Long Beam", "+6 stud reach", { { "range", "add", 6 } }),
		},
		{
			A = up("Cool Running", "30% less heat", { { "heatPerTick", "mul", 0.7 } }),
			B = up(
				"Fast Vent",
				"Cools 60% faster and recovers sooner",
				{ { "coolPerSecond", "mul", 1.6 }, { "overheatLockout", "mul", 0.6 } }
			),
		},
		{
			A = up("Searing Beam", "Double damage to Vrill", { { "damagePerTick", "mul", 2 } }),
			B = up("Deep Cut", "Wider and longer beam", { { "digRadius", "add", 0.8 }, { "range", "add", 4 } }),
		},
	},
	SatchelCharge = {
		{
			A = up("Extra Satchel", "+1 satchel", { { "charges", "add", 1 } }),
			B = up("Bigger Bang", "+30% damage", { { "damage", "mul", 1.3 } }),
		},
		{
			A = up("Wide Blast", "+3 stud blast radius", { { "radius", "add", 3 } }),
			B = up("Excavator", "Removes far more rock", { { "digRadius", "add", 2.5 } }),
		},
		{
			A = up("Satchel Pack", "+2 satchels", { { "charges", "add", 2 } }),
			B = up("Shaped Charge", "+50% damage", { { "damage", "mul", 1.5 } }),
		},
	},

	-- Grenades ----------------------------------------------------------------------------------
	DecoyBeacon = {
		{
			A = up("Spare Beacon", "+1 beacon", { { "charges", "add", 1 } }),
			B = up("Loud Beacon", "Lures 4 seconds longer", { { "lure", "add", 4 } }),
		},
		{
			A = up("Big Payload", "+50% blast damage", { { "damage", "mul", 1.5 } }),
			B = up("Wide Payload", "+3 stud blast radius", { { "radius", "add", 3 } }),
		},
		{
			A = up("Beacon Belt", "+1 beacon", { { "charges", "add", 1 } }),
			B = up("Endless Song", "Lures 6 seconds longer", { { "lure", "add", 6 } }),
		},
	},
	CryoBomb = {
		{
			A = up("Spare Bomb", "+1 bomb", { { "charges", "add", 1 } }),
			B = up("Deep Freeze", "Freezes 2 seconds longer", { { "freeze", "add", 2 } }),
		},
		{
			A = up("Wide Chill", "+3 stud radius", { { "radius", "add", 3 } }),
			B = up("Frostbite", "Triple the blast damage", { { "damage", "mul", 3 } }),
		},
		{
			A = up("Bomb Belt", "+1 bomb", { { "charges", "add", 1 } }),
			B = up("Glacier", "Freezes longer over a wider area", { { "freeze", "add", 2 }, { "radius", "add", 2 } }),
		},
	},
	ClusterBomb = {
		{
			A = up("Spare Bomb", "+1 bomb", { { "charges", "add", 1 } }),
			B = up("Heavy Core", "+30% core damage", { { "damage", "mul", 1.3 } }),
		},
		{
			A = up("More Bomblets", "+3 bomblets", { { "bomblets", "add", 3 } }),
			B = up("Big Bomblets", "+50% bomblet damage", { { "bombletDamage", "mul", 1.5 } }),
		},
		{
			A = up("Bomb Belt", "+1 bomb", { { "charges", "add", 1 } }),
			B = up(
				"Carpet",
				"+4 bomblets with wider blasts",
				{ { "bomblets", "add", 4 }, { "bombletRadius", "add", 1 } }
			),
		},
	},
	SeismicGrenade = {
		{
			A = up("Spare Grenade", "+1 grenade", { { "charges", "add", 1 } }),
			B = up("Aftershock", "Stuns 1.5 seconds longer", { { "stun", "add", 1.5 } }),
		},
		{
			A = up("Quake", "+3 stud radius", { { "radius", "add", 3 } }),
			B = up("Crater", "Digs a much bigger crater", { { "digRadius", "add", 3 } }),
		},
		{
			A = up("Grenade Belt", "+1 grenade", { { "charges", "add", 1 } }),
			B = up("Tremor", "+50% damage", { { "damage", "mul", 1.5 } }),
		},
	},
} :: { [string]: ItemUpgrades }

-- Weapons follow the weapon unlock track; tools and grenades follow the tool track.
Upgrades.WEAPON_ITEMS = {
	RivetDriver = true,
	ArcMortar = true,
	BurstCarbine = true,
	BoltPistol = true,
	RotaryCannon = true,
	HandCannon = true,
	FlameProjector = true,
	AutoPistol = true,
}

function Upgrades.id(itemId: string, tier: number, choice: Choice): string
	return `{itemId}.{tier}{choice}`
end

-- Splits "RivetDriver.2B" into its parts. Returns nil for anything malformed.
function Upgrades.parse(id: string): (string?, number?, Choice?)
	local itemId, tier, choice = string.match(id, "^(%w+)%.(%d)([AB])$")
	if not (itemId and tier and choice) or not Upgrades.ITEMS[itemId] then
		return nil, nil, nil
	end
	local tierNumber = tonumber(tier) :: number
	if tierNumber < 1 or tierNumber > 3 then
		return nil, nil, nil
	end
	return itemId, tierNumber, choice :: Choice
end

function Upgrades.get(id: string): Upgrade?
	local itemId, tier, choice = Upgrades.parse(id)
	if not (itemId and tier and choice) then
		return nil
	end
	return Upgrades.ITEMS[itemId][tier][choice]
end

-- Applies an upgrade's changes to a stats table in place.
function Upgrades.apply(stats: { [string]: any }, upgrade: Upgrade)
	for _, change in upgrade.changes do
		local current = stats[change.stat]
		if change.op == "set" then
			stats[change.stat] = change.value
		elseif change.op == "add" then
			stats[change.stat] = (current or 0) + change.value
		elseif change.op == "mul" then
			stats[change.stat] = (current or 0) * change.value
		end
	end
end

return Upgrades
