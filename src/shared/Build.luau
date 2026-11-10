--!strict
-- Small helpers for assembling part-built models in code.
-- Shared because both the server (world models) and client (viewmodels, effects) build geometry.

local Build = {}

export type PartSpec = {
	name: string?,
	shape: Enum.PartType?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	castShadow: boolean?,
}

-- An anchored part. Cylinders are given in "upright" terms: size.Y is height, size.X is diameter,
-- and the part is rotated so its axis points along the cframe's up vector.
function Build.part(parent: Instance, spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name or "Part"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	part.CanCollide = if spec.collide == nil then true else spec.collide
	part.CastShadow = if spec.castShadow == nil then true else spec.castShadow
	local shape = spec.shape or Enum.PartType.Block
	part.Shape = shape
	if shape == Enum.PartType.Cylinder then
		part.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.X)
		part.CFrame = spec.cframe * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Size = spec.size
		part.CFrame = spec.cframe
	end
	part.Parent = parent
	return part
end

function Build.light(parent: Instance, className: "PointLight" | "SpotLight", props: { [string]: any }): Light
	local light = Instance.new(className) :: Light
	for key, value in props do
		(light :: any)[key] = value
	end
	light.Parent = parent
	return light
end

function Build.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

return Build
