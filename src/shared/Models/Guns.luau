--!strict
-- Part-built class weapons. Each builder lays parts out around the hand at the origin with -Z forward,
-- and marks the barrel end with a "Muzzle" attachment for tracers and flashes.

local Build = require(script.Parent.Parent.Build)

local Guns = {}

local GUNMETAL = Color3.fromRGB(58, 56, 66)
local STEEL = Color3.fromRGB(140, 140, 152)
local BLACK = Color3.fromRGB(28, 26, 32)
local BRASS = Color3.fromRGB(196, 150, 72)

local ALONG_Z = CFrame.Angles(math.rad(90), 0, 0)

local function box(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return Build.part(
		model,
		{ name = name, size = size, cframe = cframe, color = color, material = material or Enum.Material.Metal }
	)
end

-- A cylinder whose axis runs along Z through `center`.
local function tube(
	model: Model,
	name: string,
	diameter: number,
	length: number,
	center: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return Build.part(model, {
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(diameter, length, 0),
		cframe = center * ALONG_Z,
		color = color,
		material = material or Enum.Material.Metal,
	})
end

local function glow(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	return Build.part(model, {
		name = name,
		size = size,
		cframe = cframe,
		color = color,
		material = Enum.Material.Neon,
		castShadow = false,
	})
end

local function muzzle(on: BasePart, worldPosition: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Muzzle"
	attachment.WorldPosition = worldPosition
	attachment.Parent = on
end

local function grip(model: Model, color: Color3?): Part
	return box(
		model,
		"Grip",
		Vector3.new(0.34, 0.95, 0.5),
		CFrame.Angles(math.rad(14), 0, 0),
		color or BLACK,
		Enum.Material.Fabric
	)
end

local function rivetDriver(model: Model, accent: Color3)
	grip(model)
	box(model, "Body", Vector3.new(0.55, 0.6, 2.1), CFrame.new(0, 0.62, -0.55), GUNMETAL)
	box(model, "Shroud", Vector3.new(0.62, 0.22, 1.3), CFrame.new(0, 0.98, -0.9), accent, Enum.Material.SmoothPlastic)
	-- Nail drum on the side.
	Build.part(model, {
		name = "Drum",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.9, 0.42, 0),
		cframe = CFrame.new(0.42, 0.55, -0.35) * CFrame.Angles(0, 0, math.rad(90)),
		color = BRASS,
		material = Enum.Material.Metal,
	})
	local barrel = box(model, "Barrel", Vector3.new(0.3, 0.3, 0.9), CFrame.new(0, 0.62, -2.0), STEEL)
	glow(model, "Strip", Vector3.new(0.05, 0.08, 1.6), CFrame.new(-0.29, 0.62, -0.6), accent)
	muzzle(barrel, Vector3.new(0, 0.62, -2.48))
end

local function arcMortar(model: Model, accent: Color3)
	grip(model)
	local tubePart = tube(model, "Tube", 0.95, 2.8, CFrame.new(0, 0.85, -0.8), GUNMETAL)
	tube(model, "Ring", 1.15, 0.3, CFrame.new(0, 0.85, -2.1), accent, Enum.Material.SmoothPlastic)
	tube(model, "Breech", 1.05, 0.5, CFrame.new(0, 0.85, 0.45), BLACK)
	for index = 0, 2 do
		tube(model, "Coil", 1.0, 0.08, CFrame.new(0, 0.85, -0.6 - index * 0.35), accent, Enum.Material.Neon)
	end
	box(model, "Foregrip", Vector3.new(0.28, 0.6, 0.3), CFrame.new(0, 0.2, -1.4), BLACK, Enum.Material.Fabric)
	muzzle(tubePart, Vector3.new(0, 0.85, -2.25))
end

local function burstCarbine(model: Model, accent: Color3)
	grip(model)
	box(model, "Body", Vector3.new(0.42, 0.55, 2.4), CFrame.new(0, 0.6, -0.6), GUNMETAL)
	box(model, "Stock", Vector3.new(0.34, 0.5, 1.0), CFrame.new(0, 0.5, 1.0), BLACK, Enum.Material.SmoothPlastic)
	local barrel = tube(model, "Barrel", 0.18, 1.3, CFrame.new(0, 0.66, -2.4), STEEL)
	box(
		model,
		"Magazine",
		Vector3.new(0.3, 0.75, 0.42),
		CFrame.new(0, 0.05, -0.75) * CFrame.Angles(math.rad(-8), 0, 0),
		BLACK
	)
	tube(model, "Scope", 0.3, 0.9, CFrame.new(0, 1.07, -0.5), BLACK)
	glow(model, "Lens", Vector3.new(0.2, 0.2, 0.04), CFrame.new(0, 1.07, -0.96), accent)
	box(model, "Rail", Vector3.new(0.44, 0.08, 1.6), CFrame.new(0, 0.9, -0.6), accent, Enum.Material.SmoothPlastic)
	muzzle(barrel, Vector3.new(0, 0.66, -3.05))
end

local function boltPistol(model: Model, accent: Color3)
	grip(model)
	box(model, "Slide", Vector3.new(0.4, 0.5, 1.5), CFrame.new(0, 0.62, -0.45), GUNMETAL)
	local barrel = tube(model, "Barrel", 0.28, 0.5, CFrame.new(0, 0.6, -1.4), STEEL)
	glow(model, "BoltRail", Vector3.new(0.06, 0.12, 1.2), CFrame.new(0.21, 0.66, -0.5), accent)
	glow(model, "BoltRailLeft", Vector3.new(0.06, 0.12, 1.2), CFrame.new(-0.21, 0.66, -0.5), accent)
	box(model, "Hammer", Vector3.new(0.2, 0.3, 0.2), CFrame.new(0, 0.85, 0.25), BLACK)
	muzzle(barrel, Vector3.new(0, 0.6, -1.66))
end

local function rotaryCannon(model: Model, accent: Color3)
	grip(model)
	box(model, "Housing", Vector3.new(0.9, 0.85, 1.6), CFrame.new(0, 0.7, -0.3), GUNMETAL)
	box(model, "AmmoBox", Vector3.new(0.7, 0.8, 0.9), CFrame.new(0.75, 0.4, 0.05), accent, Enum.Material.SmoothPlastic)
	box(model, "CarryHandle", Vector3.new(0.18, 0.18, 1.0), CFrame.new(0, 1.3, -0.3), BLACK)
	local spinner = tube(model, "Spinner", 0.85, 0.3, CFrame.new(0, 0.7, -1.2), STEEL)
	spinner:SetAttribute("Spins", true)
	local barrels = Build.model("Barrels", model)
	for index = 0, 5 do
		local angle = index * math.pi / 3
		local offset = Vector3.new(math.cos(angle) * 0.24, 0.7 + math.sin(angle) * 0.24, -2.1)
		tube(barrels, "Barrel", 0.16, 1.8, CFrame.new(offset), STEEL)
	end
	tube(model, "Clamp", 0.75, 0.15, CFrame.new(0, 0.7, -2.7), BLACK)
	glow(model, "HeatStrip", Vector3.new(0.92, 0.06, 0.6), CFrame.new(0, 1.13, -0.6), accent)
	muzzle(spinner, Vector3.new(0, 0.7, -3.05))
end

local function handCannon(model: Model, accent: Color3)
	grip(model, Color3.fromRGB(92, 58, 36))
	box(model, "Frame", Vector3.new(0.4, 0.55, 0.9), CFrame.new(0, 0.62, -0.25), GUNMETAL)
	Build.part(model, {
		name = "Cylinder",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, 0.55, 0),
		cframe = CFrame.new(0, 0.66, -0.45) * ALONG_Z,
		color = STEEL,
		material = Enum.Material.Metal,
	})
	local barrel = box(model, "Barrel", Vector3.new(0.3, 0.32, 1.6), CFrame.new(0, 0.75, -1.4), GUNMETAL)
	box(model, "Rib", Vector3.new(0.12, 0.1, 1.6), CFrame.new(0, 0.95, -1.4), accent, Enum.Material.SmoothPlastic)
	box(
		model,
		"Hammer",
		Vector3.new(0.14, 0.32, 0.25),
		CFrame.new(0, 0.95, 0.15) * CFrame.Angles(math.rad(-30), 0, 0),
		BLACK
	)
	muzzle(barrel, Vector3.new(0, 0.75, -2.22))
end

local function flameProjector(model: Model, accent: Color3)
	grip(model)
	box(model, "Body", Vector3.new(0.5, 0.55, 1.6), CFrame.new(0, 0.62, -0.5), GUNMETAL)
	tube(model, "Tank", 0.7, 1.4, CFrame.new(0, 0.05, -0.65), accent, Enum.Material.SmoothPlastic)
	tube(model, "TankCap", 0.5, 0.15, CFrame.new(0, 0.05, 0.12), BLACK)
	local nozzle = tube(model, "Nozzle", 0.36, 1.1, CFrame.new(0, 0.66, -1.8), STEEL)
	tube(model, "Flare", 0.5, 0.2, CFrame.new(0, 0.66, -2.35), BLACK)
	local pilot =
		glow(model, "Pilot", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 0.42, -2.35), Color3.fromRGB(80, 170, 255))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 180, 255)
	light.Range = 4
	light.Brightness = 1
	light.Parent = pilot
	muzzle(nozzle, Vector3.new(0, 0.66, -2.5))
end

local function autoPistol(model: Model, accent: Color3)
	grip(model)
	box(model, "Body", Vector3.new(0.38, 0.5, 1.3), CFrame.new(0, 0.6, -0.4), GUNMETAL)
	box(
		model,
		"Magazine",
		Vector3.new(0.26, 0.9, 0.34),
		CFrame.new(0, -0.35, 0.05) * CFrame.Angles(math.rad(14), 0, 0),
		BLACK
	)
	local barrel = tube(model, "Barrel", 0.2, 0.6, CFrame.new(0, 0.62, -1.3), STEEL)
	box(model, "Top", Vector3.new(0.4, 0.1, 1.0), CFrame.new(0, 0.9, -0.4), accent, Enum.Material.SmoothPlastic)
	muzzle(barrel, Vector3.new(0, 0.62, -1.62))
end

Guns.BUILDERS = {
	RivetDriver = rivetDriver,
	ArcMortar = arcMortar,
	BurstCarbine = burstCarbine,
	BoltPistol = boltPistol,
	RotaryCannon = rotaryCannon,
	HandCannon = handCannon,
	FlameProjector = flameProjector,
	AutoPistol = autoPistol,
} :: { [string]: (Model, Color3) -> () }

return Guns
