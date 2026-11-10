--!strict
-- Named remotes shared by server and client.
-- The server creates each remote on first use; clients wait for it to replicate.
-- Every remote name used anywhere in the game is listed here so the protocol is visible in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

export type Kind = "Event" | "Unreliable" | "Function"

local REMOTES: { [string]: Kind } = {
	-- Client asks to swing the pickaxe along its aim: (origin: Vector3, direction: Vector3, heavy: boolean).
	PickaxeSwing = "Event",
	-- Server tells clients an impact happened for effects: (position: Vector3, normal: Vector3, surface: string, source: Player?).
	Impact = "Unreliable",
	-- Client tells the server which equipment slot it holds: (slot: string).
	EquipSlot = "Event",
	-- Client fires a weapon: (weaponId: string, origin: Vector3, shots: { { direction: Vector3, part: BasePart?, position: Vector3? } }).
	WeaponFire = "Event",
	-- Client starts a reload: (weaponId: string).
	WeaponReload = "Event",
	-- Server relays shots to other clients for tracers: (shooter: Player, weaponId: string, origin: Vector3, ends: { Vector3 }).
	WeaponShots = "Unreliable",
	-- Server announces a projectile: (id: number, origin: Vector3, velocity: Vector3, gravity: number, style: string).
	Projectile = "Unreliable",
	-- Server ends a projectile: (id: number, position: Vector3).
	ProjectileEnd = "Unreliable",
	-- Server announces an explosion: (position: Vector3, radius: number, style: string).
	Explosion = "Unreliable",
	-- A Vrill bursts out of or dives into the ground here: (position: Vector3).
	Burrow = "Unreliable",
	-- A Vrill attacks, for animation and sound: (model: Model, kind: "Melee" | "Spit" | "Charge").
	EnemyAttack = "Unreliable",
	-- A Vrill died here: (position: Vector3, size: number).
	EnemyDied = "Unreliable",
	-- Client pings along its aim: (origin: Vector3, direction: Vector3, callResupply: boolean).
	Ping = "Event",
	-- Server shows a ping to everyone: (pinger: Player, position: Vector3, label: string).
	PingShown = "Event",
	-- Client uses its traversal or support tool: (toolId: string, action: string, origin: Vector3, direction: Vector3).
	ToolUse = "Event",
	-- Client throws a grenade or flare: (kind: "Grenade" | "Flare", origin: Vector3, direction: Vector3).
	Throw = "Event",
	-- Server shows a grapple line or a cutter beam: (player: Player, kind: string, from: Vector3, to: Vector3).
	ToolEffect = "Unreliable",
	-- Progression requests from the hub terminals; each returns (ok: boolean, reason: string?).
	BuyUpgrade = "Function",
	EquipUpgrade = "Function",
	SelectClass = "Function",
	-- Client saves its settings: (settings: { [string]: any }).
	SaveSettings = "Event",
	-- Pad leader picks the mission: (missionType: string, seed: number?) -> (ok: boolean, reason: string?).
	ChooseMission = "Function",
	-- Client starts the walkthrough, or declines the first-join offer: (play: boolean).
	Walkthrough = "Event",
	-- Server tells a player something brief: (text: string).
	Notice = "Event",
}

local CLASS_FOR_KIND: { [Kind]: string } = {
	Event = "RemoteEvent",
	Unreliable = "UnreliableRemoteEvent",
	Function = "RemoteFunction",
}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string): Instance
	local kind = REMOTES[name]
	assert(kind, `Unknown remote "{name}"`)
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(CLASS_FOR_KIND[kind])
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	assert(REMOTES[name] == "Event", `"{name}" is not a RemoteEvent`)
	return get(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	assert(REMOTES[name] == "Unreliable", `"{name}" is not an UnreliableRemoteEvent`)
	return get(name) :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(REMOTES[name] == "Function", `"{name}" is not a RemoteFunction`)
	return get(name) :: RemoteFunction
end

-- Creates every remote up front so clients never wait on one the server has not touched yet.
function Net.createAll()
	assert(RunService:IsServer(), "Net.createAll runs on the server")
	for name in REMOTES do
		get(name)
	end
end

return Net
