--!strict
-- Class gear worn over the player's own avatar: helmet with headlamp, chest plate, shoulder pads and backpack.
-- Built for R15 rigs; parts are massless and non-colliding so they never affect movement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)

local Gear = {}

local DARK = Color3.fromRGB(44, 42, 52)
local STEEL = Color3.fromRGB(120, 118, 130)
local LENS = Color3.fromRGB(255, 244, 220)

local function attach(model: Model, body: BasePart, spec: Build.PartSpec): Part
	local part = Build.part(model, spec)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Hats and hair would poke through the helmet.
local function removeHeadwear(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			local kind = child.AccessoryType
			if kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair then
				child:Destroy()
			end
		end
	end
end

local function helmet(gear: Model, head: BasePart, color: Color3)
	local size = head.Size
	local top = head.CFrame * CFrame.new(0, size.Y * 0.12, 0)
	attach(gear, head, {
		name = "HelmetShell",
		shape = Enum.PartType.Ball,
		size = Vector3.one * size.X * 1.32,
		cframe = top,
		color = color,
	})
	attach(gear, head, {
		name = "HelmetBrim",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(size.X * 1.42, size.Y * 0.14, 0),
		cframe = head.CFrame * CFrame.new(0, size.Y * 0.08, 0),
		color = DARK,
		material = Enum.Material.Metal,
	})
	local housing = attach(gear, head, {
		name = "LampHousing",
		size = Vector3.new(size.X * 0.42, size.Y * 0.3, size.Z * 0.3),
		cframe = head.CFrame * CFrame.new(0, size.Y * 0.42, -size.Z * 0.62),
		color = DARK,
		material = Enum.Material.Metal,
	})
	local lens = attach(gear, head, {
		name = "HeadlampLens",
		size = Vector3.new(size.X * 0.32, size.Y * 0.2, 0.05),
		cframe = housing.CFrame * CFrame.new(0, 0, -size.Z * 0.16),
		color = LENS,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	Build.light(lens, "SpotLight", {
		Name = "Headlamp",
		Face = Enum.NormalId.Front,
		Range = PlayerConfig.HEADLAMP_RANGE,
		Angle = PlayerConfig.HEADLAMP_ANGLE,
		Brightness = PlayerConfig.HEADLAMP_BRIGHTNESS,
		Color = PlayerConfig.HEADLAMP_COLOR,
		Shadows = true,
	})
end

local function torsoGear(gear: Model, torso: BasePart, color: Color3)
	local size = torso.Size
	attach(gear, torso, {
		name = "ChestPlate",
		size = Vector3.new(size.X * 0.82, size.Y * 0.6, 0.18),
		cframe = torso.CFrame * CFrame.new(0, size.Y * 0.12, -size.Z * 0.5 - 0.05),
		color = DARK,
		material = Enum.Material.Metal,
	})
	attach(gear, torso, {
		name = "ChestStripe",
		size = Vector3.new(size.X * 0.82, size.Y * 0.12, 0.2),
		cframe = torso.CFrame * CFrame.new(0, size.Y * 0.3, -size.Z * 0.5 - 0.07),
		color = color,
	})

	-- Backpack frame, two canisters and a status light.
	local back = torso.CFrame * CFrame.new(0, size.Y * 0.05, size.Z * 0.5 + 0.45)
	attach(gear, torso, {
		name = "Backpack",
		size = Vector3.new(size.X * 0.78, size.Y * 0.95, 0.8),
		cframe = back,
		color = DARK,
		material = Enum.Material.DiamondPlate,
	})
	for _, side in { -1, 1 } do
		attach(gear, torso, {
			name = "Canister",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.5, size.Y * 0.7, 0),
			cframe = back * CFrame.new(side * size.X * 0.3, 0, 0.5),
			color = color,
			material = Enum.Material.Metal,
		})
	end
	attach(gear, torso, {
		name = "PackLight",
		size = Vector3.new(size.X * 0.2, 0.12, 0.05),
		cframe = back * CFrame.new(0, size.Y * 0.35, 0.42),
		color = color,
		material = Enum.Material.Neon,
		castShadow = false,
	})
end

local function shoulderPad(gear: Model, arm: BasePart, color: Color3)
	local size = arm.Size
	attach(gear, arm, {
		name = "ShoulderPad",
		size = Vector3.new(size.X * 1.35, size.Y * 0.32, size.Z * 1.35),
		cframe = arm.CFrame * CFrame.new(0, size.Y * 0.38, 0),
		color = color,
	})
	attach(gear, arm, {
		name = "ShoulderTrim",
		size = Vector3.new(size.X * 1.4, size.Y * 0.06, size.Z * 1.4),
		cframe = arm.CFrame * CFrame.new(0, size.Y * 0.2, 0),
		color = STEEL,
		material = Enum.Material.Metal,
	})
end

-- Dresses an R15 character in the gear for `classId`, replacing any previous gear.
function Gear.equip(character: Model, classId: Classes.ClassId)
	local existing = character:FindFirstChild("ClassGear")
	if existing then
		existing:Destroy()
	end
	removeHeadwear(character)
	local color = Classes.INFO[classId].color
	local gear = Build.model("ClassGear")
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local leftArm = character:FindFirstChild("LeftUpperArm") :: BasePart?
	local rightArm = character:FindFirstChild("RightUpperArm") :: BasePart?
	if head then
		helmet(gear, head, color)
	end
	if torso then
		torsoGear(gear, torso, color)
	end
	for _, arm in { leftArm, rightArm } do
		if arm then
			shoulderPad(gear, arm, color)
		end
	end
	gear.Parent = character
end

-- The headlamp light, so the owning client can hide it in favour of its camera-aligned lamp.
function Gear.headlamp(character: Model): SpotLight?
	local gear = character:FindFirstChild("ClassGear")
	local lens = gear and gear:FindFirstChild("HeadlampLens")
	return if lens then lens:FindFirstChild("Headlamp") :: SpotLight? else nil
end

return Gear
