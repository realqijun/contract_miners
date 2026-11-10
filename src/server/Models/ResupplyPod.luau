--!strict
-- The resupply pod: a squat crate on thrusters that drops through the rock with ammo and medkits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)

local ResupplyPod = {}

local SHELL = Color3.fromRGB(64, 66, 78)
local STRIPE = Color3.fromRGB(226, 104, 58)
local GLOW = Color3.fromRGB(120, 255, 170)

-- Builds the pod standing on `base`. Returns the model and the part prompts attach to.
function ResupplyPod.build(base: CFrame): (Model, BasePart)
	local model = Build.model("ResupplyPod")
	local body = Build.part(model, {
		name = "Body",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5, 4.6, 0),
		cframe = base * CFrame.new(0, 2.6, 0),
		color = SHELL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Stripe",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5.2, 0.6, 0),
		cframe = base * CFrame.new(0, 3.4, 0),
		color = STRIPE,
	})
	Build.part(model, {
		name = "Lid",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4.4, 0.8, 0),
		cframe = base * CFrame.new(0, 5.3, 0),
		color = STRIPE,
		material = Enum.Material.Metal,
	})
	local beacon = Build.part(model, {
		name = "Beacon",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1, 1, 1),
		cframe = base * CFrame.new(0, 5.9, 0),
		color = GLOW,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	Build.light(beacon, "PointLight", { Color = GLOW, Range = 16, Brightness = 1.6, Shadows = false })
	for k = 0, 3 do
		local angle = k * math.pi / 2 + math.pi / 4
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Build.part(model, {
			name = "Fin",
			size = Vector3.new(0.4, 2.6, 1.6),
			cframe = CFrame.lookAlong(base.Position + out * 2.6 + Vector3.yAxis * 1.3, out),
			color = SHELL,
			material = Enum.Material.DiamondPlate,
		})
	end
	model.PrimaryPart = body
	return model, body
end

return ResupplyPod
