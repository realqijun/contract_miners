--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local CaveConfig = require(Shared.Config.Cave)
local Layout = require(Shared.Cave.Layout)

local SEEDS = { 1, 7, 42, 1337, 98765, 2024111, 31415926, 2147483646 }

return function(t)
	t.describe("generate", function()
		t.it("is deterministic for a seed", function()
			for _, seed in SEEDS do
				t.expect(Layout.generate(seed)).toEqual(Layout.generate(seed))
			end
		end)

		t.it("differs between seeds", function()
			local a = Layout.generate(SEEDS[1])
			local b = Layout.generate(SEEDS[2])
			t.expect(a.caverns[1].center == b.caverns[1].center).toBeFalsy()
		end)

		t.it("places the configured number of caverns", function()
			for _, seed in SEEDS do
				t.expect(#Layout.generate(seed).caverns)
					.toBeBetween(CaveConfig.CAVERN_COUNT_MIN, CaveConfig.CAVERN_COUNT_MAX)
			end
		end)

		t.it("keeps caverns and tunnels clear of the solid shell", function()
			local low = CaveConfig.MIN_CORNER + Vector3.one * CaveConfig.SHELL
			local high = CaveConfig.MIN_CORNER + CaveConfig.SIZE - Vector3.one * CaveConfig.SHELL
			local function inside(point: Vector3, margin: Vector3): boolean
				return point - margin == (point - margin):Max(low) and point + margin == (point + margin):Min(high)
			end
			for _, seed in SEEDS do
				local layout = Layout.generate(seed)
				for _, cavern in layout.caverns do
					t.expect(inside(cavern.center, cavern.radii)).toBeTruthy()
				end
				for _, tunnel in layout.tunnels do
					for _, point in tunnel.points do
						t.expect(inside(point, Vector3.one * tunnel.radius)).toBeTruthy()
					end
				end
			end
		end)

		t.it("links every cavern into one network", function()
			for _, seed in SEEDS do
				local layout = Layout.generate(seed)
				local neighbours: { [number]: { number } } = {}
				for _, tunnel in layout.tunnels do
					neighbours[tunnel.from] = neighbours[tunnel.from] or {}
					neighbours[tunnel.to] = neighbours[tunnel.to] or {}
					table.insert(neighbours[tunnel.from], tunnel.to)
					table.insert(neighbours[tunnel.to], tunnel.from)
				end
				local seen = { [layout.startCavern] = true }
				local stack = { layout.startCavern }
				local count = 1
				while #stack > 0 do
					local current = table.remove(stack) :: number
					for _, next in neighbours[current] or {} do
						if not seen[next] then
							seen[next] = true
							count += 1
							table.insert(stack, next)
						end
					end
				end
				t.expect(count).toBe(#layout.caverns)
			end
		end)
	end)
end
