--!strict
-- Builds the crew ship's deck: a hangar in orbit over Kessra with terminals along the walls and two
-- launch bays. Built in code so the whole hub lives in the repository.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.Build)
local Dropcan = require(ServerScriptService.Server.Models.Dropcan)

local Deck = {}

local FLOOR = Color3.fromRGB(58, 60, 70)
local PLATE = Color3.fromRGB(78, 80, 92)
local WALL = Color3.fromRGB(190, 184, 172)
local TRIM = Color3.fromRGB(40, 38, 48)
local ORANGE = Color3.fromRGB(232, 120, 36)
local WARM = Color3.fromRGB(255, 226, 190)
local VIOLET = Color3.fromRGB(176, 96, 255)

Deck.SIZE = Vector3.new(140, 34, 90)

export type Terminal = { part: BasePart, opens: string }

export type Built = {
	spawn: CFrame,
	terminals: { Terminal },
	-- Launch bays: where each pad's centre is and its board console.
	pads: { { center: Vector3, board: BasePart, dropcan: Dropcan.Dropcan } },
}

local function lights()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(70, 66, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 36, 60)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 6000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
	local bloom = (Lighting:FindFirstChild("DeckBloom") or Instance.new("BloomEffect")) :: BloomEffect
	bloom.Name = "DeckBloom"
	bloom.Intensity = 0.6
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
end

local function shell(model: Model)
	local size = Deck.SIZE
	-- Floor in panels of about 20 studs that tile the footprint exactly, over a dark subfloor
	-- that shows through the seams.
	local columns = math.round(size.X / 20)
	local rows = math.round(size.Z / 20)
	local panel = Vector2.new(size.X / columns, size.Z / rows)
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			Build.part(model, {
				name = "FloorPanel",
				size = Vector3.new(panel.X - 0.4, 1, panel.Y - 0.4),
				cframe = CFrame.new(-size.X / 2 + (column + 0.5) * panel.X, -0.5, -size.Z / 2 + (row + 0.5) * panel.Y),
				color = if (column + row) % 2 == 0 then FLOOR else PLATE,
				material = Enum.Material.DiamondPlate,
			})
		end
	end
	Build.part(model, {
		name = "Subfloor",
		size = Vector3.new(size.X, 1, size.Z),
		cframe = CFrame.new(0, -1.2, 0),
		color = TRIM,
	})
	Build.part(model, {
		name = "Ceiling",
		size = Vector3.new(size.X, 2, size.Z),
		cframe = CFrame.new(0, size.Y + 1, 0),
		color = TRIM,
		material = Enum.Material.Metal,
	})
	-- Back and side walls; the front (+Z) wall is a great window onto Kessra. Walls reach below
	-- the floor so nothing shows through under them.
	Build.part(model, {
		name = "BackWall",
		size = Vector3.new(size.X, size.Y + 2, 2),
		cframe = CFrame.new(0, size.Y / 2 - 1, -size.Z / 2 - 1),
		color = WALL,
		material = Enum.Material.Metal,
	})
	for _, side in { -1, 1 } do
		Build.part(model, {
			name = "SideWall",
			size = Vector3.new(2, size.Y + 2, size.Z),
			cframe = CFrame.new(side * (size.X / 2 + 1), size.Y / 2 - 1, 0),
			color = WALL,
			material = Enum.Material.Metal,
		})
	end
	Build.part(model, {
		name = "WindowSill",
		size = Vector3.new(size.X, 6, 2),
		cframe = CFrame.new(0, 1, size.Z / 2 + 1),
		color = TRIM,
		material = Enum.Material.Metal,
	})
	Build.part(model, {
		name = "Window",
		size = Vector3.new(size.X, size.Y - 4, 0.4),
		cframe = CFrame.new(0, size.Y / 2 + 2, size.Z / 2 + 1),
		color = Color3.fromRGB(160, 190, 255),
		-- Not Glass: that material hides transparent things behind it, such as the planet below.
		transparency = 0.92,
	})
	for x = -size.X / 2, size.X / 2, 14 do
		Build.part(model, {
			name = "WindowStrut",
			size = Vector3.new(1.2, size.Y - 4, 1.6),
			cframe = CFrame.new(x, size.Y / 2 + 2, size.Z / 2 + 1),
			color = TRIM,
			material = Enum.Material.Metal,
		})
	end
	-- Ceiling beams with warm lights.
	for x = -size.X / 2 + 14, size.X / 2 - 14, 28 do
		Build.part(model, {
			name = "Beam",
			size = Vector3.new(2, 2, size.Z),
			cframe = CFrame.new(x, size.Y - 1, 0),
			color = TRIM,
			material = Enum.Material.Metal,
		})
		for z = -size.Z / 2 + 15, size.Z / 2 - 15, 30 do
			local lamp = Build.part(model, {
				name = "Lamp",
				size = Vector3.new(4, 0.4, 4),
				cframe = CFrame.new(x, size.Y - 2.2, z),
				color = WARM,
				material = Enum.Material.Neon,
				castShadow = false,
			})
			Build.light(
				lamp,
				"SpotLight",
				{ Face = Enum.NormalId.Bottom, Range = 40, Angle = 100, Brightness = 1.6, Color = WARM, Shadows = true }
			)
		end
	end
	-- Kessra itself, filling the view below the window. Ball parts this large render visibly
	-- faceted, so the planet is a smooth disc drawn on a plane facing the deck. The plane stays
	-- within the view distance of low graphics settings.
	local backdrop = Build.part(model, {
		name = "Kessra",
		size = Vector3.new(900, 900, 1),
		cframe = CFrame.lookAt(Vector3.new(-60, -360, 350), Vector3.new(-60, -360, 0)),
		color = Color3.new(0, 0, 0),
		transparency = 1,
		collide = false,
		castShadow = false,
	})
	local planet = Instance.new("SurfaceGui")
	planet.Face = Enum.NormalId.Front
	planet.CanvasSize = Vector2.new(1024, 1024)
	planet.LightInfluence = 0
	planet.Parent = backdrop
	local function disc(scale: number, color: Color3, transparency: number): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(scale, scale)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = transparency
		frame.BorderSizePixel = 0
		frame.Parent = planet
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		return frame
	end
	-- A soft atmosphere from stacked faint rings, then the surface lit from the upper left.
	for ring = 0, 4 do
		disc(1 - ring * 0.006, VIOLET, 0.9 - ring * 0.08)
	end
	local surface = disc(0.968, Color3.new(1, 1, 1), 0)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 65
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 140, 250)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(120, 70, 190)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 26, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 8, 26)),
	})
	shade.Parent = surface
end

-- A lit title on the front face of a screen part.
local function screenTitle(screen: BasePart, title: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 200)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = title
	label.Parent = gui
	Build.light(screen, "PointLight", { Color = color, Range = 10, Brightness = 0.8, Shadows = false })
end

-- A console whose front (-Z of `at`) faces the player, with a screen tilted up above it.
local function console(model: Model, name: string, title: string, color: Color3, at: CFrame): BasePart
	local body = Build.part(model, {
		name = name,
		size = Vector3.new(6, 4.2, 2),
		cframe = at * CFrame.new(0, 2.1, 0),
		color = TRIM,
		material = Enum.Material.Metal,
	})
	local screen = Build.part(model, {
		name = "Screen",
		size = Vector3.new(5, 2.6, 0.2),
		cframe = at * CFrame.new(0, 5.6, 0.2) * CFrame.Angles(math.rad(12), 0, 0),
		color = Color3.fromRGB(12, 10, 18),
		-- Not Glass: that material can hide the screen's own SurfaceGui.
	})
	screenTitle(screen, title, color)
	return body
end

-- Faces a console standing at `position` towards `facing`.
local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

-- A wall terminal. Its prompt opens a menu on the client.
local function terminal(model: Model, title: string, opens: string, at: CFrame): Terminal
	local body = console(model, "Terminal", title, ORANGE, at)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Opens", opens)
	prompt.Parent = body
	CollectionService:AddTag(body, "Terminal")
	return { part = body, opens = opens }
end

-- The controls board: a big wall screen listing every binding, filled in by clients.
local function controlsBoard(model: Model, at: CFrame)
	local board = Build.part(model, {
		name = "ControlsBoard",
		size = Vector3.new(26, 14, 0.4),
		cframe = at,
		color = Color3.fromRGB(14, 12, 20),
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Controls"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1300, 700)
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = board
	Build.part(model, {
		name = "BoardFrame",
		size = Vector3.new(27, 15, 0.3),
		cframe = at * CFrame.new(0, 0, 0.3),
		color = ORANGE,
	})
	CollectionService:AddTag(board, "ControlsBoard")
end

local function launchBay(model: Model, center: Vector3): { center: Vector3, board: BasePart, dropcan: Dropcan.Dropcan }
	Build.part(model, {
		name = "Pad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(22, 0.4, 0),
		cframe = CFrame.new(center + Vector3.yAxis * 0.2),
		color = TRIM,
		material = Enum.Material.DiamondPlate,
	})
	Build.part(model, {
		name = "PadRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(23, 0.3, 0),
		cframe = CFrame.new(center + Vector3.yAxis * 0.1),
		color = ORANGE,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	local dropcan = Dropcan.build(model, CFrame.new(center + Vector3.yAxis * 0.4) * CFrame.Angles(0, math.pi, 0))
	-- The Dropcan here is scenery and a marker, not a deposit point.
	CollectionService:RemoveTag(dropcan.model, "Marker")
	dropcan.setDisplay("STANDBY")
	local board =
		console(model, "MissionBoard", "MISSIONS", VIOLET, facing(center + Vector3.new(0, 0, -14), Vector3.zAxis))
	return { center = center, board = board, dropcan = dropcan }
end

function Deck.build(): Built
	lights()
	local model = Build.model("Deck")
	shell(model)
	local size = Deck.SIZE
	local left = -size.X / 2 + 3
	local terminals = {
		terminal(model, "CLASSES", "ClassSelect", facing(Vector3.new(left, 0, -18), Vector3.xAxis)),
		terminal(model, "UPGRADES", "Upgrades", facing(Vector3.new(left, 0, 4), Vector3.xAxis)),
		terminal(model, "SETTINGS", "Settings", facing(Vector3.new(left, 0, 24), Vector3.xAxis)),
		terminal(model, "WALKTHROUGH", "Walkthrough", facing(Vector3.new(-28, 0, -size.Z / 2 + 3), Vector3.zAxis)),
	}
	controlsBoard(model, facing(Vector3.new(0, 13, -size.Z / 2 + 0.3), Vector3.zAxis))
	local pads = {
		launchBay(model, Vector3.new(size.X / 2 - 22, 0, -16)),
		launchBay(model, Vector3.new(size.X / 2 - 22, 0, 20)),
	}
	model.Parent = Workspace
	return {
		spawn = CFrame.new(-20, 3, 6) * CFrame.Angles(0, math.rad(-90), 0),
		terminals = terminals,
		pads = pads,
	}
end

return Deck
