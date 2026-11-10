--!strict
-- Finds points on cave surfaces by raycasting against terrain.
-- Results depend only on the terrain and the supplied Random, so a seed reproduces them.

local Workspace = game:GetService("Workspace")

local Layout = require(game:GetService("ReplicatedStorage").Shared.Cave.Layout)

local Surface = {}

export type Kind = "Floor" | "Wall" | "Ceiling"

export type Hit = {
	position: Vector3,
	normal: Vector3,
	kind: Kind,
}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }

local function classify(normal: Vector3): Kind
	if normal.Y > 0.7 then
		return "Floor"
	elseif normal.Y < -0.5 then
		return "Ceiling"
	end
	return "Wall"
end

function Surface.raycast(origin: Vector3, direction: Vector3): Hit?
	local result = Workspace:Raycast(origin, direction, terrainOnly)
	if not result then
		return nil
	end
	return { position = result.Position, normal = result.Normal, kind = classify(result.Normal) }
end

-- The floor directly under a point, if any within `depth` studs.
function Surface.floorBelow(position: Vector3, depth: number): Vector3?
	local hit = Surface.raycast(position, Vector3.new(0, -depth, 0))
	return if hit then hit.position else nil
end

-- A point a little above a cavern's floor, used as the origin for scattering.
function Surface.cavernOrigin(cavern: Layout.Cavern): Vector3
	return Vector3.new(cavern.center.X, cavern.floorY + cavern.radii.Y * 0.5, cavern.center.Z)
end

-- Up to `count` surface hits of the wanted kinds, cast from a cavern's interior in random directions.
function Surface.scatter(rng: Random, cavern: Layout.Cavern, count: number, kinds: { [Kind]: boolean }): { Hit }
	local hits = {}
	local origin = Surface.cavernOrigin(cavern)
	local reach = math.max(cavern.radii.X, cavern.radii.Y, cavern.radii.Z) * 2
	for _ = 1, count * 6 do
		if #hits >= count then
			break
		end
		local direction = rng:NextUnitVector() * reach
		local hit = Surface.raycast(origin, direction)
		if hit and kinds[hit.kind] then
			table.insert(hits, hit)
		end
	end
	return hits
end

return Surface
