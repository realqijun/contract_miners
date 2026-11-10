--!strict
-- Class identities. Kits and stats live in their own config modules.

export type ClassId = "Mechanic" | "Scout" | "HeavyWeapons" | "Demolition"

export type ClassInfo = {
	id: ClassId,
	displayName: string,
	role: string,
	-- Suit and UI accent colour.
	color: Color3,
}

local Classes = {}

Classes.ORDER = { "Mechanic", "Scout", "HeavyWeapons", "Demolition" } :: { ClassId }

Classes.INFO = {
	Mechanic = {
		id = "Mechanic",
		displayName = "Mechanic",
		role = "Builder and support",
		color = Color3.fromRGB(232, 168, 46),
	},
	Scout = {
		id = "Scout",
		displayName = "Scout",
		role = "Mobility and recon",
		color = Color3.fromRGB(64, 196, 222),
	},
	HeavyWeapons = {
		id = "HeavyWeapons",
		displayName = "Heavy Weapons",
		role = "Anchor",
		color = Color3.fromRGB(214, 70, 58),
	},
	Demolition = {
		id = "Demolition",
		displayName = "Demolition",
		role = "Tunneler",
		color = Color3.fromRGB(122, 196, 72),
	},
} :: { [ClassId]: ClassInfo }

function Classes.isClassId(value: unknown): boolean
	return type(value) == "string" and Classes.INFO[value :: ClassId] ~= nil
end

return Classes
