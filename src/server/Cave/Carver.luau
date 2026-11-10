--!strict
--!native
-- Carves a cave layout into voxel terrain.
-- Builds a signed distance field (negative = air) from the caverns and tunnels, displaces it with noise,
-- then writes it to Terrain in chunks so the server never stalls on one huge write.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local CaveConfig = require(Shared.Config.Cave)
local Layout = require(Shared.Cave.Layout)

local Carver = {}

local VOXEL = CaveConfig.VOXEL
local MIN_CORNER = CaveConfig.MIN_CORNER
local NX = CaveConfig.SIZE.X // VOXEL
local NY = CaveConfig.SIZE.Y // VOXEL
local NZ = CaveConfig.SIZE.Z // VOXEL
local SOLID = 1e6

-- Voxel columns written per WriteVoxels call along X.
local CHUNK_X = 14

local function index(x: number, y: number, z: number): number
	-- Zero-based voxel coordinates to a float offset in the field buffer.
	return ((x * NY + y) * NZ + z) * 4
end

local function voxelCenter(x: number, y: number, z: number): Vector3
	return MIN_CORNER + Vector3.new(x + 0.5, y + 0.5, z + 0.5) * VOXEL
end

local function voxelRange(low: Vector3, high: Vector3): (number, number, number, number, number, number)
	local a = (low - MIN_CORNER) / VOXEL
	local b = (high - MIN_CORNER) / VOXEL
	return math.max(0, math.floor(a.X)),
		math.min(NX - 1, math.ceil(b.X)),
		math.max(0, math.floor(a.Y)),
		math.min(NY - 1, math.ceil(b.Y)),
		math.max(0, math.floor(a.Z)),
		math.min(NZ - 1, math.ceil(b.Z))
end

local function carveMin(field: buffer, x: number, y: number, z: number, distance: number)
	local offset = index(x, y, z)
	if distance < buffer.readf32(field, offset) then
		buffer.writef32(field, offset, distance)
	end
end

local function carveCavern(field: buffer, cavern: Layout.Cavern)
	local pad = Vector3.one * VOXEL
	local x0, x1, y0, y1, z0, z1 = voxelRange(cavern.center - cavern.radii - pad, cavern.center + cavern.radii + pad)
	local radii = cavern.radii
	local smallest = math.min(radii.X, radii.Y, radii.Z)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				local p = voxelCenter(x, y, z)
				local ellipsoid = (((p - cavern.center) / radii).Magnitude - 1) * smallest
				-- A flat floor plane cut through the lower part of the ellipsoid.
				local distance = math.max(ellipsoid, cavern.floorY - p.Y)
				carveMin(field, x, y, z, distance)
			end
		end
	end
end

local function carveSegment(field: buffer, a: Vector3, b: Vector3, radius: number)
	local pad = Vector3.one * (radius + VOXEL)
	local x0, x1, y0, y1, z0, z1 = voxelRange(a:Min(b) - pad, a:Max(b) + pad)
	local ab = b - a
	local lengthSquared = math.max(ab:Dot(ab), 1e-6)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				local p = voxelCenter(x, y, z)
				local t = math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1)
				carveMin(field, x, y, z, (p - (a + ab * t)).Magnitude - radius)
			end
		end
	end
end

local function displaceAndShell(field: buffer, seed: number)
	local offset = Vector3.new(seed % 997, seed % 613, seed % 409) * 1.37
	local reach = CaveConfig.NOISE_AMPLITUDE + CaveConfig.DETAIL_NOISE_AMPLITUDE + VOXEL
	local shell = CaveConfig.SHELL
	local size = CaveConfig.SIZE
	for x = 0, NX - 1 do
		for y = 0, NY - 1 do
			for z = 0, NZ - 1 do
				local at = index(x, y, z)
				local distance = buffer.readf32(field, at)
				if distance < reach then
					local p = voxelCenter(x, y, z)
					local n = p / CaveConfig.NOISE_SCALE + offset
					local d = p / CaveConfig.DETAIL_NOISE_SCALE + offset
					distance += math.noise(n.X, n.Y, n.Z) * CaveConfig.NOISE_AMPLITUDE + math.noise(d.X, d.Y, d.Z) * CaveConfig.DETAIL_NOISE_AMPLITUDE
					-- Keep a solid shell at the box faces regardless of what was carved.
					local relative = p - MIN_CORNER
					local toFace = math.min(
						relative.X,
						relative.Y,
						relative.Z,
						size.X - relative.X,
						size.Y - relative.Y,
						size.Z - relative.Z
					)
					distance = math.max(distance, shell - toFace)
					buffer.writef32(field, at, distance)
				end
			end
		end
	end
end

local function rockMaterial(p: Vector3, seed: number): Enum.Material
	local n = math.noise(p.X / 60 + seed % 101, p.Y / 45, p.Z / 60)
	if n > 0.22 then
		return Enum.Material.Basalt
	end
	return Enum.Material.Slate
end

local function writeTerrain(field: buffer, seed: number)
	local terrain = Workspace.Terrain
	for chunkStart = 0, NX - 1, CHUNK_X do
		local chunkEnd = math.min(chunkStart + CHUNK_X - 1, NX - 1)
		local materials = table.create(chunkEnd - chunkStart + 1)
		local occupancies = table.create(chunkEnd - chunkStart + 1)
		for x = chunkStart, chunkEnd do
			local materialPlane = table.create(NY)
			local occupancyPlane = table.create(NY)
			for y = 0, NY - 1 do
				local materialRow = table.create(NZ)
				local occupancyRow = table.create(NZ)
				for z = 0, NZ - 1 do
					local occupancy = math.clamp(0.5 + buffer.readf32(field, index(x, y, z)) / VOXEL, 0, 1)
					if occupancy > 0 then
						materialRow[z + 1] = rockMaterial(voxelCenter(x, y, z), seed)
					else
						materialRow[z + 1] = Enum.Material.Air
					end
					occupancyRow[z + 1] = occupancy
				end
				materialPlane[y + 1] = materialRow
				occupancyPlane[y + 1] = occupancyRow
			end
			materials[x - chunkStart + 1] = materialPlane
			occupancies[x - chunkStart + 1] = occupancyPlane
		end
		local low = MIN_CORNER + Vector3.new(chunkStart * VOXEL, 0, 0)
		local high = MIN_CORNER + Vector3.new((chunkEnd + 1) * VOXEL, CaveConfig.SIZE.Y, CaveConfig.SIZE.Z)
		terrain:WriteVoxels(Region3.new(low, high), VOXEL, materials, occupancies)
		task.wait()
	end
end

export type Field = buffer

Carver.GRID = Vector3.new(NX, NY, NZ)

-- True when the zero-based voxel is open air in the field.
function Carver.isAir(field: Field, x: number, y: number, z: number): boolean
	return buffer.readf32(field, index(x, y, z)) < 0
end

function Carver.voxelCenter(x: number, y: number, z: number): Vector3
	return voxelCenter(x, y, z)
end

-- Zero-based voxel containing a world position.
function Carver.voxelAt(position: Vector3): (number, number, number)
	local v = (position - MIN_CORNER) / VOXEL
	return math.floor(v.X), math.floor(v.Y), math.floor(v.Z)
end

-- Builds the signed distance field for a layout without touching terrain. Yields between passes.
function Carver.buildField(layout: Layout.CaveLayout): Field
	local field = buffer.create(NX * NY * NZ * 4)
	for offset = 0, NX * NY * NZ * 4 - 4, 4 do
		buffer.writef32(field, offset, SOLID)
	end
	for _, cavern in layout.caverns do
		carveCavern(field, cavern)
	end
	task.wait()
	for _, tunnel in layout.tunnels do
		for i = 1, #tunnel.points - 1 do
			carveSegment(field, tunnel.points[i], tunnel.points[i + 1], tunnel.radius)
		end
	end
	task.wait()
	displaceAndShell(field, layout.seed)
	task.wait()
	return field
end

-- Clears existing terrain and carves the layout. Yields until the terrain is fully written.
function Carver.carve(layout: Layout.CaveLayout): Field
	Workspace.Terrain:Clear()
	local field = Carver.buildField(layout)
	writeTerrain(field, layout.seed)
	return field
end

return Carver
