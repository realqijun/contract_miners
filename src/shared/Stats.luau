--!strict
-- Effective stats for a player's equipment: base config with their chosen upgrades applied.
-- The single place both server and client (and the balance simulation) compute weapon numbers.

local Weapons = require(script.Parent.Config.Weapons)

local Stats = {}

-- Upgrade modifiers are applied by Config/Upgrades once progression is in; until a player has
-- chosen upgrades this returns the base stats unchanged.
export type Modifier = (stats: { [string]: any }) -> ()

local modifiers: { [string]: Modifier } = {}

function Stats.registerModifier(upgradeId: string, modifier: Modifier)
	modifiers[upgradeId] = modifier
end

function Stats.weapon(id: Weapons.WeaponId, upgrades: { string }?): Weapons.Stats
	local stats = table.clone(Weapons.STATS[id]) :: any
	for _, upgradeId in upgrades or {} do
		local modifier = modifiers[upgradeId]
		if modifier then
			modifier(stats)
		end
	end
	return stats
end

-- The upgrade ids a player has active, replicated as a comma-separated attribute.
function Stats.activeUpgrades(player: Player): { string }
	local raw = player:GetAttribute("Upgrades")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

function Stats.weaponFor(player: Player, id: Weapons.WeaponId): Weapons.Stats
	return Stats.weapon(id, Stats.activeUpgrades(player))
end

return Stats
