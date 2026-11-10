--!strict
-- Refinery mission hardware: the Refinery tower with its rocket, slurry wells, and pipe segments.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)

local RefineryModels = {}

local HULL = Color3.fromRGB(206, 198, 182)
local DARK = Color3.fromRGB(46, 44, 54)
local ORANGE = Color3.fromRGB(232, 120, 36)
local SLURRY = Color3.fromRGB(176, 96, 255)
local PIPE = Color3.fromRGB(120, 118, 132)

export type Refinery = {
	model: Model,
	inlet: Vector3,
	rocket: Model,
	tank: BasePart,
	prompt: Attachment,
	screen: TextLabel,
}

function RefineryModels.refinery(base: CFrame): Refinery
	local model = Build.model("Refinery")
	Build.part(model, {
		name = "Foundation",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(22, 1.6, 0),
		cframe = base * CFrame.new(0, 0.8, 0),
		color = DARK,
		material = Enum.Material.DiamondPlate,
	})
	-- Three squat legs ringing a central tank.
	for k = 0, 2 do
		local angle = k * math.pi * 2 / 3
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Build.part(model, {
			name = "Leg",
			size = Vector3.new(1.6, 12, 1.6),
			cframe = CFrame.new(base.Position + out * 7 + Vector3.yAxis * 7),
			color = HULL,
			material = Enum.Material.Metal,
		})
	end
	local tank = Build.part(model, {
		name = "Tank",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(11, 9, 0),
		cframe = base * CFrame.new(0, 8, 0),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "TankBand",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(11.3, 1, 0),
		cframe = base * CFrame.new(0, 10, 0),
		color = ORANGE,
	})
	local gauge = Build.part(model, {
		name = "Gauge",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(11.4, 0.4, 0),
		cframe = base * CFrame.new(0, 6, 0),
		color = SLURRY,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	Build.light(gauge, "PointLight", { Color = SLURRY, Range = 22, Brightness = 1.4, Shadows = false })
	-- Gantry and the rocket that carries the refined slurry to orbit.
	Build.part(model, {
		name = "Gantry",
		size = Vector3.new(1.4, 26, 1.4),
		cframe = base * CFrame.new(4.2, 24, 0),
		color = DARK,
		material = Enum.Material.Metal,
	})
	local rocket = Build.model("Rocket", model)
	Build.part(rocket, {
		name = "Body",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4, 16, 0),
		cframe = base * CFrame.new(0, 21, 0),
		color = HULL,
		material = Enum.Material.Metal,
	})
	Build.part(rocket, {
		name = "Nose",
		shape = Enum.PartType.Ball,
		size = Vector3.new(4, 5, 4),
		cframe = base * CFrame.new(0, 29.5, 0),
		color = ORANGE,
	})
	for k = 0, 3 do
		local angle = k * math.pi / 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Build.part(rocket, {
			name = "Fin",
			size = Vector3.new(0.4, 4, 2.2),
			cframe = CFrame.lookAlong(base.Position + out * 2.6 + Vector3.yAxis * 14.5, Vector3.new(-out.Z, 0, out.X)),
			color = ORANGE,
		})
	end
	local engine = Build.part(rocket, {
		name = "Engine",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3, 1.2, 0),
		cframe = base * CFrame.new(0, 12.6, 0),
		color = DARK,
		material = Enum.Material.Metal,
	})
	local flame = Instance.new("Attachment")
	flame.Name = "Exhaust"
	flame.Position = Vector3.new(0, 0, 0)
	flame.Parent = engine

	-- Inlet where pipelines plug in, and the control console.
	local inletPart = Build.part(model, {
		name = "Inlet",
		size = Vector3.new(2.4, 2.4, 2.4),
		cframe = base * CFrame.new(0, 2.8, -8.5),
		color = PIPE,
		material = Enum.Material.Metal,
	})
	local console = Build.part(model, {
		name = "Console",
		size = Vector3.new(3, 3.2, 1.2),
		cframe = base * CFrame.new(-6, 3.2, -6),
		color = DARK,
		material = Enum.Material.Metal,
	})
	local screenPart = Build.part(model, {
		name = "Screen",
		size = Vector3.new(2.6, 1.6, 0.1),
		cframe = console.CFrame * CFrame.new(0, 0.5, -0.65),
		color = Color3.fromRGB(12, 10, 18),
		-- Not Glass: that material can hide the screen's own SurfaceGui.
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(300, 180)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screenPart
	local screen = Instance.new("TextLabel")
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundTransparency = 1
	screen.Font = Enum.Font.GothamBold
	screen.TextScaled = true
	screen.TextColor3 = SLURRY
	screen.Parent = gui
	local promptPoint = Instance.new("Attachment")
	promptPoint.Name = "Controls"
	promptPoint.Parent = console

	model.PrimaryPart = tank
	return {
		model = model,
		inlet = inletPart.Position,
		rocket = rocket,
		tank = tank,
		prompt = promptPoint,
		screen = screen,
	}
end

-- A slurry well: a crusted vent with a glowing pool and a valve to hook a pipeline onto.
function RefineryModels.well(base: CFrame, label: string): (Model, BasePart)
	local model = Build.model("Well")
	for k = 0, 5 do
		local angle = k * math.pi / 3
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Build.part(model, {
			name = "Crust",
			size = Vector3.new(2.6, 2.2, 1.6),
			cframe = CFrame.lookAlong(base.Position + out * 3.4 + Vector3.yAxis * 0.8, out)
				* CFrame.Angles(math.rad(-20), 0, 0),
			color = Color3.fromRGB(56, 44, 72),
			material = Enum.Material.Slate,
		})
	end
	local pool = Build.part(model, {
		name = "Pool",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(6, 0.4, 0),
		cframe = base * CFrame.new(0, 0.6, 0),
		color = SLURRY,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	Build.light(pool, "PointLight", { Color = SLURRY, Range = 24, Brightness = 2, Shadows = false })
	local valve = Build.part(model, {
		name = "Valve",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.4, 3, 0),
		cframe = base * CFrame.new(0, 2, 0),
		color = PIPE,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Wheel",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2, 0.3, 0),
		cframe = base * CFrame.new(0, 3.6, 0),
		color = ORANGE,
	})
	model:SetAttribute("Label", label)
	model.PrimaryPart = valve
	return model, valve
end

-- One pipe span between two nodes, with a support leg under its start.
function RefineryModels.pipe(parent: Instance, from: Vector3, to: Vector3, floorY: number?): Part
	local length = (to - from).Magnitude
	local pipe = Build.part(parent, {
		name = "Pipe",
		size = Vector3.new(0.9, 0.9, length + 0.4),
		cframe = CFrame.lookAt((from + to) / 2, to),
		color = PIPE,
		material = Enum.Material.Metal,
	})
	pipe.CanCollide = false
	Build.part(pipe, {
		name = "Joint",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.3, 1.3, 1.3),
		cframe = CFrame.new(from),
		color = DARK,
		material = Enum.Material.Metal,
	}).CanCollide =
		false
	if floorY and from.Y - floorY > 1 then
		local height = from.Y - floorY
		Build.part(pipe, {
			name = "Support",
			size = Vector3.new(0.35, height, 0.35),
			cframe = CFrame.new(from.X, floorY + height / 2, from.Z),
			color = DARK,
			material = Enum.Material.Metal,
		}).CanCollide =
			false
	end
	return pipe
end

return RefineryModels
