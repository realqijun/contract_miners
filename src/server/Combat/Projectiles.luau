--!strict
-- Server-simulated ballistic projectiles. Clients draw the same arc from the spawn broadcast,
-- so only the spawn and the impact cross the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local Projectiles = {}

export type Spec = {
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	-- Seconds before it detonates in the air.
	lifetime: number,
	-- Things the projectile passes through (usually the crew).
	ignore: { Instance },
	-- Visual style for clients.
	style: string,
	-- Sticks to what it hits instead of detonating (satchels).
	sticky: boolean?,
	onImpact: (position: Vector3, normal: Vector3, hit: Instance?) -> (),
}

type Live = Spec & { position: Vector3, age: number, id: number }

local live: { [number]: Live } = {}
local nextId = 0

function Projectiles.launch(spec: Spec): number
	nextId += 1
	local projectile = table.clone(spec) :: any
	projectile.position = spec.origin
	projectile.age = 0
	projectile.id = nextId
	live[nextId] = projectile
	Net.unreliable("Projectile"):FireAllClients(nextId, spec.origin, spec.velocity, spec.gravity, spec.style)
	return nextId
end

local function step(dt: number)
	for id, projectile in live do
		projectile.age += dt
		local velocity = projectile.velocity - Vector3.yAxis * projectile.gravity * dt
		local nextPosition = projectile.position + (projectile.velocity + velocity) * 0.5 * dt
		projectile.velocity = velocity
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = projectile.ignore
		local result = Workspace:Raycast(projectile.position, nextPosition - projectile.position, params)
		if result then
			live[id] = nil
			Net.unreliable("ProjectileEnd"):FireAllClients(id, result.Position)
			task.spawn(projectile.onImpact, result.Position, result.Normal, result.Instance)
		elseif projectile.age >= projectile.lifetime then
			live[id] = nil
			Net.unreliable("ProjectileEnd"):FireAllClients(id, nextPosition)
			task.spawn(projectile.onImpact, nextPosition, Vector3.yAxis, nil)
		else
			projectile.position = nextPosition
		end
	end
end

function Projectiles.start()
	RunService.Heartbeat:Connect(step)
end

return Projectiles
