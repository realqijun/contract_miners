--!strict
-- Cave set dressing: clusters of glowing fungi on floors and walls and pale crystals on walls and
-- ceilings, seeded from the layout so a seed always looks the same. Purely decorative: nothing
-- collides with it or blocks a shot, and digging nearby clears it away. A few clusters per cavern
-- carry a light; the rest glow on their own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Build)
local Layout = require(Shared.Cave.Layout)
local Surface = require(script.Parent.Surface)

local Dressing = {}

-- Teal and ice blue, kept well apart from the violet and red of the minerals worth mining.
local FUNGUS_CAP = Color3.fromRGB(36, 160, 140)
local FUNGUS_STEM = Color3.fromRGB(150, 170, 160)
local CRYSTAL = Color3.fromRGB(96, 146, 196)
local LIGHTS_PER_CAVERN = 3
-- Room left around minerals and the landing site, so decoration never hides them.
local CLEARANCE = 7

type Cluster = { position: Vector3, model: Model }

local folder: Folder? = nil
local clusters: { Cluster } = {}

local function frameOn(position: Vector3, normal: Vector3, spin: number): CFrame
	local across = if math.abs(normal.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local right = across:Cross(normal).Unit
	return CFrame.fromMatrix(position, right, normal) * CFrame.Angles(0, spin, 0)
end

local function decorative(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function fungi(parent: Model, base: CFrame, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		local height = rng:NextNumber(0.6, 1.8)
		local width = rng:NextNumber(0.9, 2)
		local at = base
			* CFrame.new(offset)
			* CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
		decorative(Build.part(parent, {
			name = "Stem",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(width * 0.22, height, 0),
			cframe = at * CFrame.new(0, height / 2, 0),
			color = FUNGUS_STEM,
		}))
		decorative(Build.part(parent, {
			name = "Cap",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(width, 0.3, 0),
			cframe = at * CFrame.new(0, height, 0),
			color = FUNGUS_CAP,
			material = Enum.Material.Neon,
		}))
	end
end

local function crystals(parent: Model, base: CFrame, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local length = rng:NextNumber(2.5, 6)
		local thickness = rng:NextNumber(0.6, 1.2)
		local at = base
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		local part = Build.part(parent, {
			name = "Crystal",
			size = Vector3.new(thickness, length, thickness),
			cframe = at * CFrame.new(0, length / 2 - 0.3, 0) * CFrame.Angles(0, math.rad(45), 0),
			color = CRYSTAL,
			material = Enum.Material.Neon,
			transparency = 0.25,
		})
		decorative(part)
	end
end

local function clearOf(position: Vector3, avoid: { Vector3 }): boolean
	for _, point in avoid do
		if (point - position).Magnitude < CLEARANCE then
			return false
		end
	end
	for _, cluster in clusters do
		if (cluster.position - position).Magnitude < CLEARANCE then
			return false
		end
	end
	return true
end

local function dressCavern(cavern: Layout.Cavern, seed: number, avoid: { Vector3 })
	local rng = Random.new(seed * 31 + cavern.index)
	local reach = math.max(cavern.radii.X, cavern.radii.Z)
	local fungusCount = math.clamp(math.round(reach / 5), 4, 10)
	local crystalCount = math.clamp(math.round(reach / 9), 2, 6)
	local lit = 0
	local function place(
		kinds: { [Surface.Kind]: boolean },
		count: number,
		build: (Model, CFrame, Random) -> (),
		light: Color3
	)
		for _, hit in Surface.scatter(rng, cavern, count, kinds) do
			if clearOf(hit.position, avoid) then
				local model = Build.model("Decor", folder)
				build(model, frameOn(hit.position, hit.normal, rng:NextNumber(0, math.pi * 2)), rng)
				if lit < LIGHTS_PER_CAVERN then
					lit += 1
					local first = model:FindFirstChildWhichIsA("BasePart")
					if first then
						Build.light(
							first,
							"PointLight",
							{ Color = light, Range = 16, Brightness = 0.9, Shadows = false }
						)
					end
				end
				table.insert(clusters, { position = hit.position, model = model })
			end
		end
	end
	place({ Floor = true, Wall = true }, fungusCount, fungi, FUNGUS_CAP)
	place({ Wall = true, Ceiling = true }, crystalCount, crystals, CRYSTAL)
end

-- Dresses every cavern of `layout`, keeping clear of the points in `avoid`.
function Dressing.populate(layout: Layout.CaveLayout, avoid: { Vector3 })
	local created = Instance.new("Folder")
	created.Name = "Dressing"
	created.Parent = Workspace
	folder = created
	for _, cavern in layout.caverns do
		dressCavern(cavern, layout.seed, avoid)
		task.wait()
	end
end

-- Removes decoration within `radius` of `center`, where the rock it grew on has been dug away.
function Dressing.clear(center: Vector3, radius: number)
	for index = #clusters, 1, -1 do
		local cluster = clusters[index]
		if (cluster.position - center).Magnitude <= radius + 1 then
			cluster.model:Destroy()
			table.remove(clusters, index)
		end
	end
end

return Dressing
