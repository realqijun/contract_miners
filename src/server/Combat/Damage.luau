--!strict
-- Routes damage to whatever was hit. Systems that own damageable things (enemies, pipes, players)
-- register a handler for a CollectionService tag; weapons and tools only ever call Damage.apply.

local CollectionService = game:GetService("CollectionService")

local Damage = {}

export type Kind = "Bullet" | "Melee" | "Explosion" | "Fire" | "Cold" | "Electric" | "Acid" | "Fall"

export type Info = {
	amount: number,
	kind: Kind,
	-- The player responsible, if any.
	attacker: Player?,
	-- Where the hit landed, for weakspots and effects.
	position: Vector3?,
	-- The exact part hit, for weakspot and armour checks.
	part: BasePart?,
	-- Multiplier when `part` is a weakspot.
	weakspotMultiplier: number?,
	-- Ignores armour plates.
	piercesArmor: boolean?,
	-- Status effects: fraction of speed removed per hit, burn added (damage per second), freeze seconds, stun seconds.
	slow: number?,
	burn: number?,
	freeze: number?,
	stun: number?,
	-- Hits crew members too (satchel charges only).
	friendlyFire: boolean?,
}

type Handler = (target: Instance, info: Info) -> ()

local handlers: { [string]: Handler } = {}

function Damage.register(tag: string, handler: Handler)
	assert(handlers[tag] == nil, `A damage handler for "{tag}" is already registered`)
	handlers[tag] = handler
end

-- The tagged ancestor of `instance` that can take damage, and its tag.
function Damage.targetOf(instance: Instance): (Instance?, string?)
	local current: Instance? = instance
	while current and current ~= game do
		for tag in handlers do
			if CollectionService:HasTag(current, tag) then
				return current, tag
			end
		end
		current = current.Parent
	end
	return nil, nil
end

-- Damages whatever `hit` belongs to. Returns true if something took the damage.
function Damage.apply(hit: Instance, info: Info): boolean
	local target, tag = Damage.targetOf(hit)
	if not (target and tag) then
		return false
	end
	handlers[tag](target, info)
	return true
end

return Damage
