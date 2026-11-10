--!strict
-- Part-built handheld items. Each builder returns an unanchored Model welded to its "Grip" part,
-- whose CFrame is where the hand holds it (-Z points forward along the item).
-- Used for both the first-person viewmodel and the item other players see in hand.

local Build = require(script.Parent.Parent.Build)
local Guns = require(script.Parent.Guns)

local Items = {}

-- "Pickaxe", or any weapon or tool id.
export type ItemId = string

local STEEL = Color3.fromRGB(150, 150, 160)
local DARK = Color3.fromRGB(44, 42, 52)
local WOOD = Color3.fromRGB(110, 74, 46)

local function weldAll(model: Model, grip: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part ~= grip then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = grip
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	model.PrimaryPart = grip
	-- Pivot on the build origin, not the grip part's own (possibly rotated) frame.
	grip.PivotOffset = grip.CFrame:Inverse()
end

local function pickaxe(accent: Color3): Model
	local model = Build.model("Pickaxe")
	local origin = CFrame.identity
	-- The handle runs up from the grip; the head sits across its top.
	local grip = Build.part(model, {
		name = "Grip",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.32, 1.1, 0),
		cframe = origin,
		color = DARK,
		material = Enum.Material.Fabric,
	})
	Build.part(model, {
		name = "Handle",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.26, 2.6, 0),
		cframe = origin * CFrame.new(0, 1.6, 0),
		color = WOOD,
		material = Enum.Material.Wood,
	})
	Build.part(model, {
		name = "Collar",
		size = Vector3.new(0.5, 0.55, 0.5),
		cframe = origin * CFrame.new(0, 2.9, 0),
		color = accent,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Beak",
		size = Vector3.new(0.34, 0.36, 1.6),
		cframe = origin * CFrame.new(0, 2.95, -0.95) * CFrame.Angles(math.rad(-10), 0, 0),
		color = STEEL,
		material = Enum.Material.Metal,
	})
	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.34, 0.36, 0.7)
	tip.CFrame = origin * CFrame.new(0, 2.81, -2.05) * CFrame.Angles(math.rad(-10), 0, 0) * CFrame.Angles(math.pi, 0, 0)
	tip.Color = STEEL
	tip.Material = Enum.Material.Metal
	tip.Parent = model
	Build.part(model, {
		name = "Adze",
		size = Vector3.new(0.5, 0.3, 0.8),
		cframe = origin * CFrame.new(0, 2.95, 0.6),
		color = STEEL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Glow",
		size = Vector3.new(0.52, 0.08, 0.3),
		cframe = origin * CFrame.new(0, 3.2, 0),
		color = accent,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	weldAll(model, grip)
	return model
end

function Items.build(id: ItemId, accent: Color3): Model
	if id == "Pickaxe" then
		return pickaxe(accent)
	end
	local builder = Guns.BUILDERS[id]
	assert(builder, `No model for item "{id}"`)
	local model = Build.model(id)
	builder(model, accent)
	weldAll(model, model:FindFirstChild("Grip") :: BasePart)
	return model
end

return Items
