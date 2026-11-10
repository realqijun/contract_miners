--!strict
-- Pings: a crew member marks what they are aiming at for everyone. Holding ping calls a resupply
-- pod to the marked spot when the team has the Ferrin for it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EnemiesConfig = require(Shared.Config.Enemies)
local Net = require(Shared.Net)
local Resources = require(Shared.Config.Resources)

local Server = script.Parent.Parent
local Vitals = require(Server.Character.Vitals)
local Aim = require(Server.Equipment.Aim)
local Resupply = require(script.Parent.Resupply)

local Pings = {}

local RANGE = 250
local COOLDOWN = 0.4

local lastPing: { [Player]: number } = {}

-- What a hit instance is, in words for the marker.
local function describe(instance: Instance): string
	local current: Instance? = instance
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, "Enemy") then
			local enemyType = current:GetAttribute("EnemyType")
			return if type(enemyType) == "string"
				then EnemiesConfig.STATS[enemyType :: EnemiesConfig.EnemyType].displayName
				else "Vrill"
		end
		local kind = current:GetAttribute("Kind")
		if type(kind) == "string" and (Resources.DISPLAY_NAME :: any)[kind] then
			return (Resources.DISPLAY_NAME :: any)[kind]
		end
		current = current.Parent
	end
	return "Here"
end

local function onPing(player: Player, origin: unknown, direction: unknown, callResupply: unknown)
	local now = os.clock()
	if now - (lastPing[player] or 0) < COOLDOWN or not Vitals.isAlive(player) then
		return
	end
	local ray = Aim.validate(player, origin, direction)
	if not ray then
		return
	end
	lastPing[player] = now
	local result = Aim.cast(player, ray, RANGE)
	if not result then
		return
	end
	if callResupply == true then
		if Resupply.call(result.Position) then
			Net.event("PingShown"):FireAllClients(player, result.Position, "Resupply inbound")
		end
		return
	end
	Net.event("PingShown"):FireAllClients(player, result.Position, describe(result.Instance))
end

function Pings.start()
	Net.event("Ping").OnServerEvent:Connect(onPing)
	Players.PlayerRemoving:Connect(function(player)
		lastPing[player] = nil
	end)
end

return Pings
