--!strict
-- The Lift Pod: an open-fronted escape capsule. Crew standing on its deck at launch get out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)

local LiftPod = {}

-- A mid-tone hull: a headlamp at arm's length washes a paler one out to white inside the cabin.
local HULL = Color3.fromRGB(150, 144, 134)
local TRIM = Color3.fromRGB(46, 44, 54)
local GREEN = Color3.fromRGB(120, 255, 150)
local ORANGE = Color3.fromRGB(232, 120, 36)

LiftPod.DECK_RADIUS = 6

-- Builds the pod with its deck at `base`, its open side facing along `base`'s look vector.
-- Returns the model and the deck part.
function LiftPod.build(base: CFrame): (Model, BasePart)
	local model = Build.model("LiftPod")
	local deck = Build.part(model, {
		name = "Deck",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(LiftPod.DECK_RADIUS * 2 + 1, 1, 0),
		-- Flush with the floor it lands on, so the crew walks straight on.
		cframe = base * CFrame.new(0, -0.5, 0),
		color = TRIM,
		material = Enum.Material.DiamondPlate,
	})
	Build.part(model, {
		name = "DeckRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(LiftPod.DECK_RADIUS * 2 + 1.6, 0.4, 0),
		cframe = base * CFrame.new(0, -0.1, 0),
		color = GREEN,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	-- Curved back wall from pillars, leaving the front (-Z) open.
	for k = 0, 8 do
		local angle = math.rad(40 + k * 35)
		local out = base:VectorToWorldSpace(Vector3.new(math.sin(angle), 0, -math.cos(angle)))
		Build.part(model, {
			name = "Wall",
			size = Vector3.new(4.3, 11, 0.8),
			cframe = CFrame.lookAlong(base.Position + out * (LiftPod.DECK_RADIUS + 0.3) + Vector3.yAxis * 5.5, out),
			color = HULL,
			material = Enum.Material.Metal,
		})
	end
	Build.part(model, {
		name = "Roof",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(LiftPod.DECK_RADIUS * 2 + 2, 1.2, 0),
		cframe = base * CFrame.new(0, 12.6, 0),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Band",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(LiftPod.DECK_RADIUS * 2 + 2.2, 0.5, 0),
		cframe = base * CFrame.new(0, 11.8, 0),
		color = ORANGE,
	})
	Build.part(model, {
		name = "Nose",
		shape = Enum.PartType.Ball,
		size = Vector3.new(8, 8, 8),
		cframe = base * CFrame.new(0, 13.4, 0),
		color = HULL,
		material = Enum.Material.Metal,
	})
	local beacon = Build.part(model, {
		name = "Beacon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.2, 1.6, 0),
		cframe = base * CFrame.new(0, 18, 0),
		color = GREEN,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	-- The beacon lights the landing site; its shadows keep the roof between it and the cabin, which
	-- it would otherwise flood with green.
	Build.light(beacon, "PointLight", { Color = GREEN, Range = 40, Brightness = 2, Shadows = true })
	-- A soft cabin light: the crew's headlamps already light the hull, and anything brighter washes
	-- the inside out.
	Build.light(
		deck,
		"PointLight",
		{ Color = Color3.fromRGB(255, 236, 210), Range = 16, Brightness = 0.5, Shadows = false }
	)
	model.PrimaryPart = deck
	return model, deck
end

return LiftPod
