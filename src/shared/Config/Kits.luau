--!strict
-- What each class carries in each slot.

local Classes = require(script.Parent.Classes)
local Weapons = require(script.Parent.Weapons)

export type ToolId =
	"FoamProjector"
	| "ArcPylons"
	| "GrappleLine"
	| "LumenDarts"
	| "CableLauncher"
	| "AegisDome"
	| "PlasmaCutter"
	| "SatchelCharge"

export type GrenadeId = "DecoyBeacon" | "CryoBomb" | "ClusterBomb" | "SeismicGrenade"

export type Kit = {
	primary: Weapons.WeaponId,
	secondary: Weapons.WeaponId,
	traversal: ToolId,
	support: ToolId,
	grenade: GrenadeId,
}

local Kits = {}

Kits.BY_CLASS = {
	Mechanic = {
		primary = "RivetDriver",
		secondary = "ArcMortar",
		traversal = "FoamProjector",
		support = "ArcPylons",
		grenade = "DecoyBeacon",
	},
	Scout = {
		primary = "BurstCarbine",
		secondary = "BoltPistol",
		traversal = "GrappleLine",
		support = "LumenDarts",
		grenade = "CryoBomb",
	},
	HeavyWeapons = {
		primary = "RotaryCannon",
		secondary = "HandCannon",
		traversal = "CableLauncher",
		support = "AegisDome",
		grenade = "ClusterBomb",
	},
	Demolition = {
		primary = "FlameProjector",
		secondary = "AutoPistol",
		traversal = "PlasmaCutter",
		support = "SatchelCharge",
		grenade = "SeismicGrenade",
	},
} :: { [Classes.ClassId]: Kit }

return Kits
