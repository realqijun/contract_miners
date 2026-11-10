--!strict
-- Pure rules over a player's saved progress: levels, which upgrades they may buy or equip, and
-- which are active. Shared by the server (authority), the hub UI (display) and the simulation.

local Classes = require(script.Parent.Config.Classes)
local Kits = require(script.Parent.Config.Kits)
local Progression = require(script.Parent.Config.Progression)
local Upgrades = require(script.Parent.Config.Upgrades)

local Progress = {}

export type ClassProgress = {
	xp: number,
	-- Upgrade ids bought.
	owned: { [string]: boolean },
	-- The choice equipped per item tier, keyed "<ItemId>.<tier>".
	equipped: { [string]: Upgrades.Choice },
}

export type Data = {
	credits: number,
	classes: { [Classes.ClassId]: ClassProgress },
	selectedClass: Classes.ClassId,
	settings: { [string]: any },
	walkthroughOffered: boolean,
	stats: { missions: number, successes: number, volticite: number },
}

function Progress.template(): Data
	local classes = {}
	for _, classId in Classes.ORDER do
		classes[classId] = { xp = 0, owned = {}, equipped = {} }
	end
	return {
		credits = 0,
		classes = classes :: any,
		selectedClass = "Scout",
		settings = {},
		walkthroughOffered = false,
		stats = { missions = 0, successes = 0, volticite = 0 },
	}
end

-- The five items a class can upgrade, in slot order.
function Progress.items(classId: Classes.ClassId): { string }
	local kit = Kits.BY_CLASS[classId]
	return { kit.primary, kit.secondary, kit.traversal, kit.support, kit.grenade }
end

function Progress.level(data: Data, classId: Classes.ClassId): number
	return Progression.levelFor(data.classes[classId].xp)
end

-- The highest tier open for an item at the class's level.
function Progress.tierOpen(data: Data, classId: Classes.ClassId, itemId: string): number
	local kind = if Upgrades.WEAPON_ITEMS[itemId] then "weapons" else "tools"
	return Progression.tierOpen(Progress.level(data, classId), kind)
end

-- Can the player buy this upgrade now? Returns false and a short reason if not.
function Progress.canBuy(data: Data, classId: Classes.ClassId, upgradeId: string): (boolean, string?)
	local itemId, tier = Upgrades.parse(upgradeId)
	if not (itemId and tier) or not table.find(Progress.items(classId), itemId) then
		return false, "Not for this class"
	end
	local progress = data.classes[classId]
	if progress.owned[upgradeId] then
		return false, "Already owned"
	end
	if tier > Progress.tierOpen(data, classId, itemId) then
		return false, "Locked"
	end
	if data.credits < Progression.UPGRADE_COST[tier] then
		return false, "Not enough credits"
	end
	return true, nil
end

function Progress.buy(data: Data, classId: Classes.ClassId, upgradeId: string): boolean
	if not Progress.canBuy(data, classId, upgradeId) then
		return false
	end
	local itemId, tier, choice = Upgrades.parse(upgradeId)
	local progress = data.classes[classId]
	data.credits -= Progression.UPGRADE_COST[tier :: number]
	progress.owned[upgradeId] = true
	progress.equipped[`{itemId}.{tier}`] = choice :: Upgrades.Choice
	return true
end

-- Switches a tier to an already-bought choice. Free.
function Progress.equip(data: Data, classId: Classes.ClassId, upgradeId: string): boolean
	local itemId, tier, choice = Upgrades.parse(upgradeId)
	local progress = data.classes[classId]
	if not (itemId and tier and choice) or not progress.owned[upgradeId] then
		return false
	end
	progress.equipped[`{itemId}.{tier}`] = choice
	return true
end

-- Upgrade ids active for a class.
function Progress.equippedList(data: Data, classId: Classes.ClassId): { string }
	local list = {}
	for key, choice in data.classes[classId].equipped do
		local itemId, tier = string.match(key, "^(%w+)%.(%d)$")
		if itemId and tier then
			local id = Upgrades.id(itemId, tonumber(tier) :: number, choice)
			if data.classes[classId].owned[id] then
				table.insert(list, id)
			end
		end
	end
	table.sort(list)
	return list
end

-- Credits and XP after a mission.
function Progress.grant(data: Data, classId: Classes.ClassId, credits: number, xp: number)
	data.credits += credits
	data.classes[classId].xp += xp
end

return Progress
