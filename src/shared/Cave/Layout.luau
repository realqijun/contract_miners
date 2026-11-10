--!strict
-- Deterministic cave layout: caverns and the tunnels linking them, derived only from a seed.
-- The layout is pure data; Carver turns it into terrain.

local CaveConfig = require(script.Parent.Parent.Config.Cave)

local Layout = {}

export type Cavern = {
	index: number,
	center: Vector3,
	-- Ellipsoid half-extents.
	radii: Vector3,
	-- World Y of the flat floor.
	floorY: number,
}

export type Tunnel = {
	from: number,
	to: number,
	radius: number,
	-- Centre line sampled every TUNNEL_STEP studs.
	points: { Vector3 },
}

export type CaveLayout = {
	seed: number,
	caverns: { Cavern },
	tunnels: { Tunnel },
	-- Cavern the Dropcan lands in.
	startCavern: number,
}

local function horizontalRadius(cavern: Cavern): number
	return math.max(cavern.radii.X, cavern.radii.Z)
end

local function overlaps(a: Cavern, b: Cavern): boolean
	local delta = a.center - b.center
	local horizontal = Vector2.new(delta.X, delta.Z).Magnitude
	local gap = CaveConfig.CAVERN_GAP
	return horizontal < horizontalRadius(a) + horizontalRadius(b) + gap
		and math.abs(delta.Y) < a.radii.Y + b.radii.Y + gap
end

local function innerBounds(margin: Vector3): (Vector3, Vector3)
	local shell = Vector3.one * (CaveConfig.SHELL + CaveConfig.NOISE_AMPLITUDE + CaveConfig.DETAIL_NOISE_AMPLITUDE)
	local low = CaveConfig.MIN_CORNER + shell + margin
	local high = CaveConfig.MIN_CORNER + CaveConfig.SIZE - shell - margin
	return low, high
end

local function placeCaverns(rng: Random): { Cavern }
	local target = rng:NextInteger(CaveConfig.CAVERN_COUNT_MIN, CaveConfig.CAVERN_COUNT_MAX)
	local caverns: { Cavern } = {}
	-- Shrink caverns gradually if the box gets crowded, so every seed reaches the target count.
	local scale = 1
	local attempts = 0
	while #caverns < target do
		attempts += 1
		if attempts % 150 == 0 then
			scale *= 0.9
		end
		local radii = Vector3.new(
			rng:NextNumber(CaveConfig.CAVERN_RADIUS_XZ_MIN, CaveConfig.CAVERN_RADIUS_XZ_MAX) * scale,
			rng:NextNumber(CaveConfig.CAVERN_RADIUS_Y_MIN, CaveConfig.CAVERN_RADIUS_Y_MAX) * scale,
			rng:NextNumber(CaveConfig.CAVERN_RADIUS_XZ_MIN, CaveConfig.CAVERN_RADIUS_XZ_MAX) * scale
		)
		local low, high = innerBounds(radii)
		local center =
			Vector3.new(rng:NextNumber(low.X, high.X), rng:NextNumber(low.Y, high.Y), rng:NextNumber(low.Z, high.Z))
		local candidate: Cavern = {
			index = #caverns + 1,
			center = center,
			radii = radii,
			floorY = center.Y - radii.Y * CaveConfig.CAVERN_FLOOR_DEPTH,
		}
		local free = true
		for _, other in caverns do
			if overlaps(candidate, other) then
				free = false
				break
			end
		end
		if free then
			table.insert(caverns, candidate)
		end
	end
	return caverns
end

-- Prim's minimum spanning tree over cavern centres, so every cavern is connected.
local function spanningEdges(caverns: { Cavern }): { { number } }
	local inTree = { [1] = true }
	local edges = {}
	for _ = 2, #caverns do
		local bestFrom, bestTo, bestDistance = 0, 0, math.huge
		for from in inTree do
			for to, cavern in caverns do
				if not inTree[to] then
					local distance = (caverns[from].center - cavern.center).Magnitude
					if distance < bestDistance then
						bestFrom, bestTo, bestDistance = from, to, distance
					end
				end
			end
		end
		inTree[bestTo] = true
		table.insert(edges, { bestFrom, bestTo })
	end
	return edges
end

local function extraEdges(rng: Random, caverns: { Cavern }, existing: { { number } }): { { number } }
	local linked = {}
	for _, edge in existing do
		linked[edge[1] .. ":" .. edge[2]] = true
		linked[edge[2] .. ":" .. edge[1]] = true
	end
	local extras = {}
	for a = 1, #caverns do
		for b = a + 1, #caverns do
			if #extras >= CaveConfig.EXTRA_TUNNELS_MAX then
				return extras
			end
			local distance = (caverns[a].center - caverns[b].center).Magnitude
			if
				not linked[a .. ":" .. b]
				and distance <= CaveConfig.EXTRA_TUNNEL_MAX_LENGTH
				and rng:NextNumber() < CaveConfig.EXTRA_TUNNEL_CHANCE
			then
				table.insert(extras, { a, b })
			end
		end
	end
	return extras
end

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function clampInside(point: Vector3, radius: number): Vector3
	local low, high = innerBounds(Vector3.one * radius)
	return point:Max(low):Min(high)
end

local function buildTunnel(rng: Random, from: Cavern, to: Cavern): Tunnel
	local radius = rng:NextNumber(CaveConfig.TUNNEL_RADIUS_MIN, CaveConfig.TUNNEL_RADIUS_MAX)
	-- Enter each cavern at floor level so tunnels open onto walkable ground.
	local startPoint = Vector3.new(from.center.X, from.floorY + radius * 0.7, from.center.Z)
	local endPoint = Vector3.new(to.center.X, to.floorY + radius * 0.7, to.center.Z)
	local direction = endPoint - startPoint
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local side = if flat.Magnitude > 1e-3 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis

	local function wander(fraction: number): Vector3
		local point = startPoint
			+ direction * fraction
			+ side * rng:NextNumber(-CaveConfig.TUNNEL_WANDER_XZ, CaveConfig.TUNNEL_WANDER_XZ)
			+ Vector3.yAxis * rng:NextNumber(-CaveConfig.TUNNEL_WANDER_Y, CaveConfig.TUNNEL_WANDER_Y)
		return clampInside(point, radius)
	end

	local control = { startPoint, startPoint, wander(1 / 3), wander(2 / 3), endPoint, endPoint }
	local points = {}
	for segment = 2, #control - 2 do
		local p0, p1, p2, p3 = control[segment - 1], control[segment], control[segment + 1], control[segment + 2]
		local steps = math.max(1, math.ceil((p2 - p1).Magnitude / CaveConfig.TUNNEL_STEP))
		for step = 0, steps - 1 do
			table.insert(points, catmullRom(p0, p1, p2, p3, step / steps))
		end
	end
	table.insert(points, endPoint)

	return { from = from.index, to = to.index, radius = radius, points = points }
end

function Layout.generate(seed: number): CaveLayout
	local rng = Random.new(seed)
	local caverns = placeCaverns(rng)
	local edges = spanningEdges(caverns)
	for _, edge in extraEdges(rng, caverns, edges) do
		table.insert(edges, edge)
	end
	local tunnels = {}
	for _, edge in edges do
		table.insert(tunnels, buildTunnel(rng, caverns[edge[1]], caverns[edge[2]]))
	end
	return {
		seed = seed,
		caverns = caverns,
		tunnels = tunnels,
		startCavern = 1,
	}
end

return Layout
