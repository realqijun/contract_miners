--!strict
-- Effective stats for a player's equipment: base config with their equipped upgrades applied.
-- The single place the server, the client and the balance simulation compute equipment numbers.

local ToolsConfig = require(script.Parent.Config.Tools)
local Upgrades = require(script.Parent.Config.Upgrades)
local Weapons = require(script.Parent.Config.Weapons)

local Stats = {}

local function applyAll(stats: { [string]: any }, itemId: string, upgrades: { string }?)
	for _, upgradeId in upgrades or {} do
		local upgradeItem = Upgrades.parse(upgradeId)
		if upgradeItem == itemId then
			local upgrade = Upgrades.get(upgradeId)
			if upgrade then
				Upgrades.apply(stats, upgrade)
			end
		end
	end
end

function Stats.weapon(id: Weapons.WeaponId, upgrades: { string }?): Weapons.Stats
	local stats = table.clone(Weapons.STATS[id]) :: any
	applyAll(stats, id, upgrades)
	return stats
end

-- Traversal and support tools and grenades.
function Stats.tool(id: string, upgrades: { string }?): ToolsConfig.ToolStats
	local base = ToolsConfig.TOOLS[id] or ToolsConfig.GRENADES[id]
	assert(base, `Unknown tool "{id}"`)
	local stats = table.clone(base) :: any
	applyAll(stats, id, upgrades)
	return stats
end

-- The upgrade ids a player has equipped, replicated as a comma-separated attribute.
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

function Stats.toolFor(player: Player, id: string): ToolsConfig.ToolStats
	return Stats.tool(id, Stats.activeUpgrades(player))
end

return Stats
