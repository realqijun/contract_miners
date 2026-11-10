--!strict
-- Validates aim rays sent by clients and casts them against the world on the server.
-- Clients aim from their camera, which in third person sits behind the shoulder, so the origin
-- may be some way from the head; anything further is rejected.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Aim = {}

export type Ray = { origin: Vector3, direction: Vector3 }

local MAX_ORIGIN_OFFSET = 14

function Aim.head(player: Player): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else nil
end

function Aim.validate(player: Player, origin: unknown, direction: unknown): Ray?
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	local o = origin :: Vector3
	local d = direction :: Vector3
	if d.Magnitude < 0.9 or d.Magnitude > 1.1 or o.Magnitude ~= o.Magnitude then
		return nil
	end
	local head = Aim.head(player)
	if not head or (o - head).Magnitude > MAX_ORIGIN_OFFSET then
		return nil
	end
	return { origin = o, direction = d.Unit }
end

-- Everything aimed rays pass through: every crew member, effects, and the crew's own domes.
function Aim.ignoreList(): { Instance }
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "Effects", "Shields" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	return ignore
end

-- Casts the ray and returns a hit only if it lies within `range` studs of the player's head.
function Aim.cast(player: Player, ray: Ray, range: number): RaycastResult?
	local head = Aim.head(player)
	if not head then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = Aim.ignoreList()
	local reach = range + (ray.origin - head).Magnitude
	local result = Workspace:Raycast(ray.origin, ray.direction * reach, params)
	if result and (result.Position - head).Magnitude <= range + 1.5 then
		return result
	end
	return nil
end

return Aim
