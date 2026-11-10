--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Cave.Layout)
local Carver = require(ServerScriptService.Server.Cave.Carver)

local SEEDS = { 1, 7, 42, 1337, 98765, 2024111, 31415926, 2147483646 }

-- Flood fills from the start cavern through voxels a player fits in (the voxel and the one above are air),
-- and counts how many cavern floors are reached.
local function reachableCaverns(field: Carver.Field, layout: Layout.CaveLayout): number
	local grid = Carver.GRID
	local nx, ny, nz = grid.X, grid.Y, grid.Z
	local visited = buffer.create(nx * ny * nz)
	local function key(x: number, y: number, z: number): number
		return (x * ny + y) * nz + z
	end
	local start = layout.caverns[layout.startCavern]
	local sx, sy, sz = Carver.voxelAt(Vector3.new(start.center.X, start.floorY + 4, start.center.Z))
	local queue = { key(sx, sy, sz) }
	buffer.writeu8(visited, queue[1], 1)
	local head = 1
	while head <= #queue do
		local k = queue[head]
		head += 1
		local z = k % nz
		local y = (k // nz) % ny
		local x = k // (nz * ny)
		for _, d in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
			local ax, ay, az = x + d[1], y + d[2], z + d[3]
			if ax >= 0 and ay >= 0 and az >= 0 and ax < nx and ay < ny and az < nz then
				local n = key(ax, ay, az)
				if
					buffer.readu8(visited, n) == 0
					and ay + 1 < ny
					and Carver.isAir(field, ax, ay, az)
					and Carver.isAir(field, ax, ay + 1, az)
				then
					buffer.writeu8(visited, n, 1)
					table.insert(queue, n)
				end
			end
		end
	end
	local reached = 0
	for _, cavern in layout.caverns do
		local cx, cy, cz = Carver.voxelAt(Vector3.new(cavern.center.X, cavern.floorY + 4, cavern.center.Z))
		if buffer.readu8(visited, key(cx, cy, cz)) == 1 then
			reached += 1
		end
	end
	return reached
end

return function(t)
	t.describe("buildField", function()
		t.it("opens air at the start cavern floor", function()
			local layout = Layout.generate(SEEDS[1])
			local field = Carver.buildField(layout)
			local start = layout.caverns[layout.startCavern]
			t.expect(Carver.isAir(field, Carver.voxelAt(Vector3.new(start.center.X, start.floorY + 4, start.center.Z))))
				.toBeTruthy()
		end)

		t.it("connects every cavern through player-sized passages", function()
			for _, seed in SEEDS do
				local layout = Layout.generate(seed)
				local field = Carver.buildField(layout)
				t.expect(reachableCaverns(field, layout)).toBe(#layout.caverns)
			end
		end)
	end)
end
