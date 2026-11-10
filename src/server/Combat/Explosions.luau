--!strict
-- Area damage with falloff, optional terrain carving, and the effect broadcast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Damage = require(script.Parent.Damage)
local Digging = require(script.Parent.Parent.Cave.Digging)

local Explosions = {}

export type Options = {
	position: Vector3,
	radius: number,
	damage: number,
	attacker: Player?,
	-- Terrain carved, if any.
	digRadius: number?,
	kind: Damage.Kind?,
	friendlyFire: boolean?,
	freeze: number?,
	stun: number?,
	-- Visual style for clients.
	style: string?,
}

-- Damages every damageable thing whose parts lie within the radius, once each, with linear falloff
-- down to 40% at the edge.
function Explosions.detonate(options: Options)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local seen: { [Instance]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInRadius(options.position, options.radius, params) do
		local target = Damage.targetOf(part)
		if target and not seen[target] then
			seen[target] = true
			local distance = (part.Position - options.position).Magnitude
			local falloff = 1 - 0.6 * math.clamp(distance / options.radius, 0, 1)
			Damage.apply(part, {
				amount = options.damage * falloff,
				kind = options.kind or "Explosion",
				attacker = options.attacker,
				position = options.position,
				piercesArmor = true,
				friendlyFire = options.friendlyFire,
				freeze = options.freeze,
				stun = options.stun,
			})
		end
	end
	if options.digRadius and options.digRadius > 0 then
		Digging.sphere(options.position, options.digRadius)
	end
	Net.unreliable("Explosion"):FireAllClients(options.position, options.radius, options.style or "Blast")
end

return Explosions
