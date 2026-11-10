--!strict
-- The Dropcan: the pod the crew arrives in. It stays in place as the team's base and Volticite deposit.

local Build = require(game:GetService("ReplicatedStorage").Shared.Build)

local Dropcan = {}

local HULL = Color3.fromRGB(212, 202, 184)
local ACCENT = Color3.fromRGB(232, 120, 36)
local DARK = Color3.fromRGB(46, 44, 54)
local HAZARD = Color3.fromRGB(240, 196, 40)
local VIOLET = Color3.fromRGB(176, 96, 255)
local WARM_LIGHT = Color3.fromRGB(255, 214, 170)

export type Dropcan = {
	model: Model,
	-- Where the deposit ProximityPrompt lives.
	depositPoint: Attachment,
	-- Text shown on the side screen.
	setDisplay: (text: string) -> (),
}

local function vertical(base: CFrame, height: number): CFrame
	return base * CFrame.new(0, height, 0)
end

-- Builds a Dropcan standing on `base` (a floor point with the pod's facing).
function Dropcan.build(parent: Instance, base: CFrame): Dropcan
	local model = Build.model("Dropcan")

	-- Landing legs and feet.
	for k = 0, 3 do
		local angle = math.rad(45 + k * 90)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local foot = base.Position + base:VectorToWorldSpace(outward * 7.5)
		local hip = base.Position + base:VectorToWorldSpace(outward * 4.6) + base.UpVector * 5
		local footTop = foot + base.UpVector * 0.6
		Build.part(model, {
			name = "Foot",
			size = Vector3.new(2.4, 0.6, 2.4),
			cframe = CFrame.lookAlong(foot + base.UpVector * 0.3, base:VectorToWorldSpace(outward), base.UpVector),
			color = DARK,
			material = Enum.Material.DiamondPlate,
		})
		local legLength = (hip - footTop).Magnitude
		Build.part(model, {
			name = "Leg",
			size = Vector3.new(0.9, 0.9, legLength),
			cframe = CFrame.lookAt((hip + footTop) / 2, hip),
			color = DARK,
			material = Enum.Material.Metal,
		})
	end

	-- Thrusters under the hull.
	Build.part(model, {
		name = "ThrusterGlow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(7, 0.4, 0),
		cframe = vertical(base, 1.6),
		color = ACCENT,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	Build.part(model, {
		name = "Skirt",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(9, 2, 0),
		cframe = vertical(base, 2.8),
		color = DARK,
		material = Enum.Material.Metal,
	})

	-- Hull with hazard bands.
	local hull = Build.part(model, {
		name = "Hull",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(10, 9, 0),
		cframe = vertical(base, 8.3),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "HazardBand",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(10.3, 0.8, 0),
		cframe = vertical(base, 4.5),
		color = HAZARD,
	})
	Build.part(model, {
		name = "AccentBand",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(10.3, 0.6, 0),
		cframe = vertical(base, 12.2),
		color = ACCENT,
	})

	-- Nose.
	Build.part(model, {
		name = "Shoulder",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(8, 1.6, 0),
		cframe = vertical(base, 13.6),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Neck",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5.5, 1.6, 0),
		cframe = vertical(base, 15.2),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Cap",
		shape = Enum.PartType.Ball,
		size = Vector3.new(4.2, 4.2, 4.2),
		cframe = vertical(base, 16.4),
		color = ACCENT,
	})
	local beacon = Build.part(model, {
		name = "Beacon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.9, 1.4, 0),
		cframe = vertical(base, 18.8),
		color = ACCENT,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	Build.light(beacon, "PointLight", { Color = ACCENT, Range = 18, Brightness = 1.4, Shadows = false })

	-- Hatch on the front.
	Build.part(model, {
		name = "HatchFrame",
		size = Vector3.new(4.6, 6.4, 0.6),
		cframe = base * CFrame.new(0, 7.8, -5.05),
		color = DARK,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Hatch",
		size = Vector3.new(3.8, 5.6, 0.4),
		cframe = base * CFrame.new(0, 7.8, -5.3),
		color = Color3.fromRGB(176, 168, 152),
		material = Enum.Material.DiamondPlate,
	})
	Build.part(model, {
		name = "HatchLight",
		size = Vector3.new(2.6, 0.25, 0.1),
		cframe = base * CFrame.new(0, 10.2, -5.52),
		color = WARM_LIGHT,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})

	-- Deposit hopper on the right side.
	Build.part(model, {
		name = "Hopper",
		size = Vector3.new(3, 2.6, 3.4),
		cframe = base * CFrame.new(5.8, 5.9, 0),
		color = DARK,
		material = Enum.Material.DiamondPlate,
	})
	Build.part(model, {
		name = "HopperLip",
		size = Vector3.new(3.4, 0.4, 3.8),
		cframe = base * CFrame.new(5.9, 7.4, 0),
		color = HAZARD,
	})
	local hopperGlow = Build.part(model, {
		name = "HopperGlow",
		size = Vector3.new(2.4, 0.15, 2.8),
		cframe = base * CFrame.new(5.9, 7.62, 0),
		color = VIOLET,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	Build.light(hopperGlow, "PointLight", { Color = VIOLET, Range = 10, Brightness = 1, Shadows = false })
	local depositPoint = Instance.new("Attachment")
	depositPoint.Name = "DepositPoint"
	depositPoint.Position = Vector3.new(0, 0.5, 0)
	depositPoint.Parent = hopperGlow

	-- Status screen above the hopper.
	local screen = Build.part(model, {
		name = "Screen",
		size = Vector3.new(0.2, 2.2, 3.6),
		cframe = base * CFrame.new(5.08, 10.2, 0),
		color = Color3.fromRGB(12, 10, 18),
		material = Enum.Material.Glass,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.CanvasSize = Vector2.new(360, 220)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = VIOLET
	label.Text = ""
	label.Parent = gui

	-- Floodlights so the landing site reads clearly.
	for k = 0, 3 do
		local angle = math.rad(k * 90)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local housing = Build.part(model, {
			name = "Floodlight",
			size = Vector3.new(1.2, 0.6, 0.8),
			cframe = CFrame.lookAlong(
				base.Position + base:VectorToWorldSpace(outward * 5.3) + base.UpVector * 12.9,
				base:VectorToWorldSpace(outward) - base.UpVector * 0.6,
				base.UpVector
			),
			color = WARM_LIGHT,
			material = Enum.Material.Neon,
			collide = false,
			castShadow = false,
		})
		Build.light(housing, "SpotLight", {
			Color = WARM_LIGHT,
			Range = 44,
			Brightness = 2.2,
			Angle = 80,
			Face = Enum.NormalId.Front,
			Shadows = true,
		})
	end
	Build.light(hull, "PointLight", { Color = WARM_LIGHT, Range = 22, Brightness = 0.8, Shadows = false })

	model.PrimaryPart = hull
	model.Parent = parent

	return {
		model = model,
		depositPoint = depositPoint,
		setDisplay = function(text: string)
			label.Text = text
		end,
	}
end

return Dropcan
