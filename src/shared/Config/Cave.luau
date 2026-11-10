--!strict
-- Tuning for cave generation. All distances are in studs.

local Cave = {}

-- Terrain voxel size. Roblox terrain is always 4 studs per voxel.
Cave.VOXEL = 4

-- World-space box the cave is carved into. Both corners sit on the voxel grid.
Cave.MIN_CORNER = Vector3.new(-252, -200, -252)
Cave.SIZE = Vector3.new(504, 200, 504)

-- Solid shell at the box edges that is never carved and cannot be dug.
Cave.SHELL = 16

Cave.CAVERN_COUNT_MIN = 7
Cave.CAVERN_COUNT_MAX = 10

-- Ellipsoid half-extents of a cavern.
Cave.CAVERN_RADIUS_XZ_MIN = 26
Cave.CAVERN_RADIUS_XZ_MAX = 52
Cave.CAVERN_RADIUS_Y_MIN = 16
Cave.CAVERN_RADIUS_Y_MAX = 30

-- Fraction of the vertical radius below the centre where the flat floor is cut.
Cave.CAVERN_FLOOR_DEPTH = 0.55

-- Minimum rock between two caverns' ellipsoids.
Cave.CAVERN_GAP = 18

Cave.TUNNEL_RADIUS_MIN = 7
Cave.TUNNEL_RADIUS_MAX = 10

-- Sideways and vertical wander of tunnel control points.
Cave.TUNNEL_WANDER_XZ = 26
Cave.TUNNEL_WANDER_Y = 14

-- Spacing of sampled points along a tunnel's centre line.
Cave.TUNNEL_STEP = 5

-- Extra tunnels beyond the spanning tree, making loops.
Cave.EXTRA_TUNNELS_MAX = 2
Cave.EXTRA_TUNNEL_CHANCE = 0.35
Cave.EXTRA_TUNNEL_MAX_LENGTH = 220

-- Organic wall displacement from 3D noise.
Cave.NOISE_SCALE = 34
Cave.NOISE_AMPLITUDE = 6
Cave.DETAIL_NOISE_SCALE = 11
Cave.DETAIL_NOISE_AMPLITUDE = 2

return Cave
