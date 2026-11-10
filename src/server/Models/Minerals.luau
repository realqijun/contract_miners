--!strict
-- Part-built mineral deposits: Volticite veins, Ferrin nodes and health crystals.
-- Each deposit is a Model whose pieces are removed as it is mined out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)

local Minerals = {}

local ROCK = Color3.fromRGB(46, 38, 60)

-- A frame sitting on the surface with Y along the surface normal.
local function surfaceFrame(position: Vector3, normal: Vector3, rng: Random): CFrame
	local tangent = normal:Cross(if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local spin = CFrame.fromAxisAngle(normal, rng:NextNumber(0, math.pi * 2))
	local base = CFrame.fromMatrix(position, tangent, normal)
	return spin.Rotation * base.Rotation + position
end

local function piece(model: Model, spec: Build.PartSpec): Part
	local part = Build.part(model, spec)
	part:SetAttribute("Piece", true)
	return part
end

local function spike(
	model: Model,
	frame: CFrame,
	rng: Random,
	length: number,
	width: number,
	color: Color3,
	neon: boolean
): Part
	local tilt = CFrame.Angles(rng:NextNumber(-0.55, 0.55), 0, rng:NextNumber(-0.55, 0.55))
	local offset = CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
	local cframe = frame
		* offset
		* tilt
		* CFrame.new(0, length * 0.42, 0)
		* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	return piece(model, {
		name = "Crystal",
		size = Vector3.new(width, length, width),
		cframe = cframe,
		color = color,
		material = if neon then Enum.Material.Neon else Enum.Material.Glass,
		transparency = if neon then 0 else 0.15,
		reflectance = if neon then 0 else 0.2,
		castShadow = false,
	})
end

local function shards(model: Model): { Instance }
	local found = {}
	for _, child in model:GetChildren() do
		if child:GetAttribute("Piece") and child.Name ~= "Matrix" then
			table.insert(found, child)
		end
	end
	return found
end

local function finish(model: Model, kind: Resources.Kind, amount: number, parent: Instance): Model
	model:SetAttribute("Kind", kind)
	model:SetAttribute("PieceCount", #shards(model))
	model:SetAttribute("Remaining", amount)
	model:SetAttribute("Total", amount)
	model.Parent = parent
	return model
end

function Minerals.volticite(parent: Instance, position: Vector3, normal: Vector3, rng: Random, amount: number): Model
	local model = Build.model("Volticite")
	local frame = surfaceFrame(position, normal, rng)
	local color = Resources.COLORS.Volticite
	piece(model, {
		name = "Matrix",
		shape = Enum.PartType.Ball,
		size = Vector3.new(4.2, 4.2, 4.2),
		cframe = frame * CFrame.new(0, -1.2, 0),
		color = ROCK,
		material = Enum.Material.Slate,
	})
	for index = 1, rng:NextInteger(5, 7) do
		local length = rng:NextNumber(2.2, 4.2)
		local glowing = index <= 2
		spike(model, frame, rng, length, rng:NextNumber(0.55, 0.9), color, glowing)
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 14
	glow.Brightness = 1.3
	glow.Shadows = false
	glow.Parent = model:FindFirstChild("Matrix")
	return finish(model, "Volticite", amount, parent)
end

function Minerals.ferrin(parent: Instance, position: Vector3, normal: Vector3, rng: Random, amount: number): Model
	local model = Build.model("Ferrin")
	local frame = surfaceFrame(position, normal, rng)
	local color = Resources.COLORS.Ferrin
	for _ = 1, rng:NextInteger(4, 6) do
		local size = rng:NextNumber(1.3, 2.4)
		piece(model, {
			name = "Nodule",
			shape = Enum.PartType.Ball,
			size = Vector3.one * size,
			cframe = frame * CFrame.new(rng:NextNumber(-1.4, 1.4), size * 0.15, rng:NextNumber(-1.4, 1.4)),
			color = color:Lerp(Color3.fromRGB(120, 60, 40), rng:NextNumber(0, 0.4)),
			material = Enum.Material.CorrodedMetal,
		})
	end
	piece(model, {
		name = "Fleck",
		size = Vector3.new(0.3, 0.3, 0.3),
		cframe = frame * CFrame.new(0, 0.9, 0),
		color = Color3.fromRGB(255, 160, 90),
		material = Enum.Material.Neon,
		castShadow = false,
	})
	return finish(model, "Ferrin", amount, parent)
end

function Minerals.health(parent: Instance, position: Vector3, normal: Vector3, rng: Random): Model
	local model = Build.model("HealthCrystal")
	local frame = surfaceFrame(position, normal, rng)
	local color = Resources.COLORS.Health
	piece(model, {
		name = "Matrix",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.6, 2.6, 2.6),
		cframe = frame * CFrame.new(0, -0.8, 0),
		color = ROCK,
		material = Enum.Material.Slate,
	})
	for index = 1, 3 do
		spike(model, frame, rng, rng:NextNumber(1.8, 2.8), 0.6, color, index == 1)
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Shadows = false
	glow.Parent = model:FindFirstChild("Matrix")
	return finish(model, "Health", 1, parent)
end

-- Removes pieces so what is left matches the remaining fraction. Destroys the model when empty.
function Minerals.setRemaining(model: Model, remaining: number)
	model:SetAttribute("Remaining", remaining)
	if remaining <= 0 then
		model:Destroy()
		return
	end
	local total = model:GetAttribute("Total") :: number
	local pieceCount = model:GetAttribute("PieceCount") :: number
	local pieces = shards(model)
	local keep = math.max(1, math.ceil(pieceCount * remaining / total))
	for index = #pieces, keep + 1, -1 do
		pieces[index]:Destroy()
	end
end

return Minerals
