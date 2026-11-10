--!strict
-- Server authority for pickaxe swings: validates the aim, then mines, digs or hits what is in reach.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local PickaxeConfig = require(Shared.Config.Pickaxe)

local Server = script.Parent.Parent
local Damage = require(Server.Combat.Damage)
local Digging = require(Server.Cave.Digging)
local Vitals = require(Server.Character.Vitals)
local Deposits = require(Server.Mission.Deposits)
local Aim = require(script.Parent.Aim)

local Pickaxe = {}

local lastSwing: { [Player]: number } = {}
local lastHeavy: { [Player]: number } = {}

local function swing(player: Player, origin: unknown, direction: unknown, heavy: unknown)
	if not Vitals.isAlive(player) then
		return
	end
	local isHeavy = heavy == true
	local now = os.clock()
	-- A small tolerance absorbs network jitter between swings.
	if now - (lastSwing[player] or 0) < PickaxeConfig.SWING_INTERVAL * 0.85 then
		return
	end
	if isHeavy and now - (lastHeavy[player] or -math.huge) < PickaxeConfig.HEAVY_COOLDOWN * 0.95 then
		return
	end
	local ray = Aim.validate(player, origin, direction)
	if not ray then
		return
	end
	lastSwing[player] = now
	if isHeavy then
		lastHeavy[player] = now
		task.wait(PickaxeConfig.HEAVY_WINDUP)
		if not Vitals.isAlive(player) then
			return
		end
	end

	local result = Aim.cast(player, ray, PickaxeConfig.RANGE)
	if not result then
		return
	end
	local surface = "Rock"
	local mineral = Deposits.mineralOf(result.Instance)
	if mineral then
		local kind = Deposits.strike(player, mineral)
		surface = kind or "Rock"
	elseif
		not Damage.apply(result.Instance, {
			amount = if isHeavy then PickaxeConfig.HEAVY_DAMAGE else PickaxeConfig.DAMAGE,
			kind = "Melee",
			attacker = player,
			position = result.Position,
			part = result.Instance :: BasePart,
		})
	then
		if result.Instance == Workspace.Terrain then
			Digging.sphere(
				result.Position,
				if isHeavy then PickaxeConfig.HEAVY_DIG_RADIUS else PickaxeConfig.DIG_RADIUS
			)
		end
	else
		surface = "Flesh"
	end
	Net.unreliable("Impact"):FireAllClients(result.Position, result.Normal, surface, player)
end

function Pickaxe.start()
	Net.event("PickaxeSwing").OnServerEvent:Connect(swing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastHeavy[player] = nil
	end)
end

return Pickaxe
