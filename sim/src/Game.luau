--!strict
-- The game's own config and math modules, loaded from `src/`, plus the handful of tuning numbers
-- the server keeps as local constants (read straight from the server source).

local Loader = require("./Loader")

local Game = {}

Game.Weapons = Loader.require("src/shared/Config/Weapons")
Game.Tools = Loader.require("src/shared/Config/Tools")
Game.Upgrades = Loader.require("src/shared/Config/Upgrades")
Game.Enemies = Loader.require("src/shared/Config/Enemies")
Game.Missions = Loader.require("src/shared/Config/Missions")
Game.Progression = Loader.require("src/shared/Config/Progression")
Game.Resources = Loader.require("src/shared/Config/Resources")
Game.Player = Loader.require("src/shared/Config/Player")
Game.Pickaxe = Loader.require("src/shared/Config/Pickaxe")
Game.Kits = Loader.require("src/shared/Config/Kits")
Game.Classes = Loader.require("src/shared/Config/Classes")
Game.Stats = Loader.require("src/shared/Stats")
Game.Progress = Loader.require("src/shared/Progress")

local HIVE = "src/server/Enemies/Hive.luau"
local WEAPONS = "src/server/Equipment/Weapons.luau"
local EXPLOSIONS = "src/server/Combat/Explosions.luau"
local TOOLS = "src/server/Equipment/Tools.luau"
local REFINERY = "src/server/Mission/RefineryMission.luau"
local EXTRACTION = "src/server/Mission/Extraction.luau"

-- Server-side constants the simulation must mirror. Each is read from the server script.
Game.Server = {
	-- Enemies
	freezeDamageBonus = Loader.literal(HIVE, "local FREEZE_DAMAGE_BONUS = ([%d%.]+)"),
	burnSeconds = Loader.literal(HIVE, "enemy%.burnUntil = now %+ ([%d%.]+)"),
	slowCap = Loader.literal(HIVE, "enemy%.slow = math%.min%(([%d%.]+), enemy%.slow %+ info%.slow%)"),
	slowDecayPerSecond = Loader.literal(HIVE, "enemy%.slow %- dt %* ([%d%.]+)"),
	minSpeedFraction = Loader.literal(HIVE, "math%.max%(([%d%.]+), 1 %- enemy%.slow%)"),
	chargeSeconds = Loader.literal(HIVE, "enemy%.charging = now %+ ([%d%.]+)"),
	chargeCooldown = Loader.literal(HIVE, "enemy%.nextAttack = now %+ ([%d%.]+)\n"),
	chargeOvershoot = Loader.literal(HIVE, "%(distance %+ ([%d%.]+)%)"),
	firstAttackDelay = Loader.literal(HIVE, "nextAttack = os%.clock%(%) %+ ([%d%.]+)"),
	structureHunterChance = Loader.literal(HIVE, "local STRUCTURE_HUNTER_CHANCE = ([%d%.]+)"),
	decoyReach = Loader.literal(HIVE, "%(decoy%.position %- position%)%.Magnitude < ([%d%.]+)"),
	spitSplash = Loader.literal(HIVE, "%(root%.Position %- position%)%.Magnitude <= ([%d%.]+)"),
	-- Weapons and explosions
	streamTick = Loader.literal(WEAPONS, "local STREAM_TICK = ([%d%.]+)"),
	explosionEdge = Loader.literal(EXPLOSIONS, "local falloff = 1 %- ([%d%.]+) %*"),
	mortarDig = Loader.literal(WEAPONS, 'digRadius = ([%d%.]+),\n%s*style = "Mortar"'),
	-- Tools
	pylonTick = Loader.literal(TOOLS, "if accumulated < ([%d%.]+) then"),
	pylonReach = Loader.literal(TOOLS, "Vector3%.new%(offset%.X, 0, offset%.Z%)%.Magnitude < ([%d%.]+)"),
	pylonStun = Loader.literal(TOOLS, "stun = ([%d%.]+),\n%s*}%)"),
	satchelCrewFactor = Loader.literal(TOOLS, "Vitals%.damage%(player, info%.amount %* ([%d%.]+)%)"),
	-- Missions
	refinerySwarmEvery = Loader.literal(REFINERY, "local SWARM_EVERY = ([%d%.]+)"),
	refineryFirstSwarm = Loader.literal(REFINERY, 'setStage%("Pumping"%)\n.-Spawner%.swarm%(([%d%.]+)%)'),
	refineryRepeatSwarm = Loader.literal(REFINERY, "sinceSwarm = 0\n%s*Spawner%.swarm%(([%d%.]+)%)"),
	pipeHealth = Loader.literal(REFINERY, "local PIPE_HEALTH = ([%d%.]+)"),
	refineryDropSeconds = Loader.literal(REFINERY, "local DROP_SECONDS = ([%d%.]+)"),
	liftSwarm = Loader.literal(EXTRACTION, "Spawner%.swarm%(([%d%.]+)%)"),
	liftDescent = Loader.literal(EXTRACTION, "local DESCENT_SECONDS = ([%d%.]+)"),
}

-- Every item a class can upgrade, in slot order, and which unlock track it follows.
function Game.items(classId: string): { string }
	return Game.Progress.items(classId)
end

function Game.isWeapon(itemId: string): boolean
	return Game.Upgrades.WEAPON_ITEMS[itemId] == true
end

return Game
