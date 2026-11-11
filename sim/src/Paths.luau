--!strict
-- Upgrade paths: the order a player buys upgrades in, and which choice they take at each tier.
-- Purchases go through the game's own Progress rules (unlock by level, price by tier).

local Game = require("./Game")

local Paths = {}

-- Tier unlock order: what each level opens, item by item, in slot order.
function Paths.schedule(classId: string): { { level: number, item: string, tier: number } }
	local items = Game.items(classId)
	local list = {}
	local opened = { weapons = 0, tools = 0 }
	for level = 1, Game.Progression.MAX_LEVEL do
		local unlocks = Game.Progression.TIER_UNLOCKS[level]
		for _, itemId in items do
			local kind = if Game.isWeapon(itemId) then "weapons" else "tools"
			for tier = opened[kind] + 1, unlocks[kind] do
				table.insert(list, { level = level, item = itemId, tier = tier })
			end
		end
		opened.weapons = unlocks.weapons
		opened.tools = unlocks.tools
	end
	return list
end

-- A path picks "A" or "B" for every (item, tier). `chooser` gets the item and tier.
export type Path = { name: string, pick: (itemId: string, tier: number) -> string }

function Paths.uniform(choice: string): Path
	return {
		name = "all " .. choice,
		pick = function()
			return choice
		end,
	}
end

function Paths.fromTable(name: string, picks: { [string]: string }): Path
	return {
		name = name,
		pick = function(itemId: string, tier: number)
			return picks[`{itemId}.{tier}`] or "A"
		end,
	}
end

-- Upgrade ids a class has once every tier opened by `level` is bought along `path`.
function Paths.upgradesAt(classId: string, level: number, path: Path): { string }
	local list = {}
	for _, entry in Paths.schedule(classId) do
		if entry.level <= level then
			table.insert(list, Game.Upgrades.id(entry.item, entry.tier, path.pick(entry.item, entry.tier)))
		end
	end
	return list
end

-- Buys whatever the player can afford along the path, in unlock order. Returns how many were bought.
function Paths.buyAll(data: any, classId: string, path: Path): number
	local bought = 0
	for _, entry in Paths.schedule(classId) do
		local id = Game.Upgrades.id(entry.item, entry.tier, path.pick(entry.item, entry.tier))
		if not data.classes[classId].owned[id] then
			if Game.Progress.buy(data, classId, id) then
				bought += 1
			else
				-- Buy in order: stop at the first upgrade that is locked or unaffordable.
				break
			end
		end
	end
	return bought
end

-- Credits needed for every tier a level opens (one choice per item).
function Paths.costOfLevel(classId: string, level: number): number
	local cost = 0
	for _, entry in Paths.schedule(classId) do
		if entry.level == level then
			cost += Game.Progression.UPGRADE_COST[entry.tier]
		end
	end
	return cost
end

return Paths
