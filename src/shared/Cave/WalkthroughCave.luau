--!strict
-- The walkthrough's small, handcrafted cave: a landing cavern for mining, a tunnel to a cavern
-- with a ledge that takes a traversal tool to climb, an upper cavern for Ferrin, resupply and a
-- swarm, and a far cavern where the Lift Pod lands. Pure data in the same shape as Layout.

local CaveConfig = require(script.Parent.Parent.Config.Cave)
local Layout = require(script.Parent.Layout)

local WalkthroughCave = {}

-- A ray from inside a cavern towards the rock where a mineral should grow.
export type SurfaceRay = { from: Vector3, toward: Vector3 }

export type Spots = {
	-- Where the Move step sends the player.
	move: Vector3,
	volticite: { SurfaceRay },
	-- The marker at the far end of the first tunnel.
	tunnelEnd: Vector3,
	-- Top of the ledge, and the lowest floor height that counts as standing on it. Wall noise
	-- moves the real floor a little, so this sits a couple of studs under the planned one.
	ledge: Vector3,
	ledgeFloorY: number,
	-- The middle of the upper cavern's floor.
	upper: Vector3,
	ferrin: { SurfaceRay },
	-- A point above the floor where the Lift Pod lands.
	liftPod: Vector3,
}

local SEED = 1
-- Generous, so wall noise never pinches a passage too low to walk through.
local TUNNEL_RADIUS = 10

local function cavern(index: number, center: Vector3, radii: Vector3): Layout.Cavern
	return {
		index = index,
		center = center,
		radii = radii,
		floorY = center.Y - radii.Y * CaveConfig.CAVERN_FLOOR_DEPTH,
	}
end

-- A straight tunnel sampled like generated ones.
local function tunnel(from: number, to: number, a: Vector3, b: Vector3): Layout.Tunnel
	local points = {}
	local steps = math.max(1, math.ceil((b - a).Magnitude / CaveConfig.TUNNEL_STEP))
	for step = 0, steps do
		table.insert(points, a:Lerp(b, step / steps))
	end
	return { from = from, to = to, radius = TUNNEL_RADIUS, points = points }
end

local function floorLevel(c: Layout.Cavern, x: number, z: number): Vector3
	return Vector3.new(x, c.floorY + TUNNEL_RADIUS * 0.7, z)
end

function WalkthroughCave.build(): (Layout.CaveLayout, Spots)
	local landing = cavern(1, Vector3.new(-120, -140, 0), Vector3.new(34, 20, 30))
	local cliff = cavern(2, Vector3.new(-10, -138, 0), Vector3.new(34, 24, 30))
	local upper = cavern(3, Vector3.new(-10, -129, 75), Vector3.new(28, 18, 24))
	local far = cavern(4, Vector3.new(70, -125, 75), Vector3.new(30, 18, 26))

	-- The ledge tunnel runs level out of the upper cavern and stops inside the cliff cavern's wall,
	-- leaving its mouth high above the cliff cavern's floor over an overhanging wall.
	local ledgeHeight = upper.floorY + TUNNEL_RADIUS * 0.7
	local layout: Layout.CaveLayout = {
		seed = SEED,
		caverns = { landing, cliff, upper, far },
		tunnels = {
			tunnel(1, 2, floorLevel(landing, landing.center.X, 0), floorLevel(cliff, cliff.center.X, 0)),
			tunnel(
				3,
				2,
				Vector3.new(upper.center.X, ledgeHeight, upper.center.Z),
				Vector3.new(cliff.center.X, ledgeHeight, 22)
			),
			tunnel(
				3,
				4,
				floorLevel(upper, upper.center.X, upper.center.Z),
				floorLevel(far, far.center.X, far.center.Z)
			),
		},
		startCavern = 1,
	}

	local mid = landing.floorY + 6
	local upperMid = upper.floorY + 5
	local spots: Spots = {
		move = Vector3.new(-136, landing.floorY, -16),
		volticite = {
			{ from = Vector3.new(-120, mid, 0), toward = Vector3.new(-1, 0.1, 0.35) },
			{ from = Vector3.new(-120, mid, 0), toward = Vector3.new(-0.6, 0.1, -1) },
		},
		tunnelEnd = Vector3.new(cliff.center.X, cliff.floorY, 6),
		ledge = Vector3.new(cliff.center.X, ledgeHeight - TUNNEL_RADIUS, 34),
		ledgeFloorY = ledgeHeight - TUNNEL_RADIUS - 2,
		upper = Vector3.new(upper.center.X, upper.floorY, upper.center.Z),
		ferrin = {
			{ from = Vector3.new(-10, upperMid, 75), toward = Vector3.new(-1, 0, 0) },
			{ from = Vector3.new(-10, upperMid, 75), toward = Vector3.new(-0.7, 0, 0.7) },
			{ from = Vector3.new(-10, upperMid, 75), toward = Vector3.new(0, 0, 1) },
			{ from = Vector3.new(-10, upperMid, 75), toward = Vector3.new(0.7, 0, 0.7) },
			{ from = Vector3.new(-10, upperMid, 75), toward = Vector3.new(-0.7, 0, -0.5) },
		},
		liftPod = Vector3.new(far.center.X + 6, far.floorY + 8, far.center.Z),
	}
	return layout, spots
end

return WalkthroughCave
