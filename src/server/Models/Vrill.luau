--!strict
-- Part-built Vrill. Every Vrill is a Humanoid rig around an invisible root, with visual parts
-- welded on and legs/wings on Motor6Ds so clients can animate them procedurally.
-- Parts marked Weakspot take bonus damage; parts marked Armor shrug off non-piercing hits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)

local Vrill = {}

local CHITIN = Color3.fromRGB(30, 36, 40)
local CHITIN_LIGHT = Color3.fromRGB(52, 62, 66)
local GLOW = Color3.fromRGB(140, 255, 90)
local BONE = Color3.fromRGB(226, 214, 186)
local SAC = Color3.fromRGB(255, 140, 40)

type Kit = {
	model: Model,
	root: Part,
}

local function newRig(name: string, rootSize: Vector3, hipHeight: number): Kit
	local model = Build.model(name)
	local root = Build.part(model, {
		name = "HumanoidRootPart",
		size = rootSize,
		cframe = CFrame.identity,
		color = CHITIN,
		transparency = 1,
	})
	root.Anchored = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = false
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	return { model = model, root = root }
end

local function weld(kit: Kit, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CanTouch = false
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = kit.root
	constraint.Part1 = part
	constraint.Parent = part
end

local function shell(kit: Kit, spec: Build.PartSpec, flags: { weakspot: boolean?, armor: boolean? }?): Part
	local part = Build.part(kit.model, spec)
	weld(kit, part)
	if flags and flags.weakspot then
		part:SetAttribute("Weakspot", true)
	end
	if flags and flags.armor then
		part:SetAttribute("Armor", true)
	end
	return part
end

-- A jointed limb hanging from `hip` on the root; clients swing it via Motor6D.Transform.
local function limb(kit: Kit, name: string, hip: CFrame, size: Vector3, color: Color3, phase: number): Part
	local part = Build.part(kit.model, {
		name = name,
		size = size,
		cframe = hip * CFrame.new(0, -size.Y / 2, 0),
		color = color,
		material = Enum.Material.SmoothPlastic,
	})
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CanTouch = false
	local joint = Instance.new("Motor6D")
	joint.Name = name .. "Joint"
	joint.Part0 = kit.root
	joint.Part1 = part
	joint.C0 = hip
	joint.C1 = CFrame.new(0, size.Y / 2, 0)
	joint:SetAttribute("Phase", phase)
	joint.Parent = kit.root
	return part
end

local function legs(
	kit: Kit,
	pairs: number,
	spread: number,
	length: number,
	rootHalfHeight: number,
	span: number,
	thickness: number
)
	for index = 1, pairs do
		local z = if pairs == 1 then 0 else -span / 2 + (index - 1) * span / (pairs - 1)
		for _, side in { -1, 1 } do
			local hip = CFrame.new(side * spread, -rootHalfHeight * 0.3, z) * CFrame.Angles(0, 0, side * math.rad(38))
			local phase = (index + (if side > 0 then 1 else 0)) % 2 * math.pi
			limb(kit, "Leg", hip, Vector3.new(thickness, length, thickness), CHITIN_LIGHT, phase)
		end
	end
end

local function eyes(kit: Kit, at: CFrame, spacing: number, size: number)
	for _, side in { -1, 1 } do
		shell(kit, {
			name = "Eye",
			shape = Enum.PartType.Ball,
			size = Vector3.one * size,
			cframe = at * CFrame.new(side * spacing, 0, 0),
			color = GLOW,
			material = Enum.Material.Neon,
			castShadow = false,
		}, { weakspot = true })
	end
end

local function mandibles(kit: Kit, at: CFrame, length: number)
	for _, side in { -1, 1 } do
		shell(kit, {
			name = "Mandible",
			size = Vector3.new(0.25, 0.3, length),
			cframe = at * CFrame.new(side * 0.35, 0, -length / 2) * CFrame.Angles(0, side * math.rad(-18), 0),
			color = BONE,
		})
	end
end

local function drone(): Kit
	local kit = newRig("Drone", Vector3.new(2, 1.4, 2.4), 1.2)
	shell(kit, {
		name = "Body",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2, 2, 2),
		cframe = CFrame.new(0, 0.1, 0.2),
		color = CHITIN,
		material = Enum.Material.SmoothPlastic,
	})
	shell(kit, {
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.2, 1.2, 1.2),
		cframe = CFrame.new(0, 0.2, -1.1),
		color = CHITIN_LIGHT,
	}, { weakspot = true })
	eyes(kit, CFrame.new(0, 0.4, -1.6), 0.28, 0.3)
	mandibles(kit, CFrame.new(0, -0.05, -1.55), 0.7)
	shell(kit, {
		name = "Glow",
		size = Vector3.new(0.4, 0.15, 1.2),
		cframe = CFrame.new(0, 1.05, 0.3),
		color = GLOW,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	legs(kit, 2, 0.8, 1.6, 0.7, 1.4, 0.22)
	return kit
end

local function warrior(): Kit
	local kit = newRig("Warrior", Vector3.new(3, 2.2, 4), 2.2)
	shell(kit, {
		name = "Abdomen",
		shape = Enum.PartType.Ball,
		size = Vector3.new(3, 2.6, 3.4),
		cframe = CFrame.new(0, 0.3, 1.2),
		color = CHITIN,
	})
	shell(kit, {
		name = "Thorax",
		size = Vector3.new(2.4, 1.8, 2.2),
		cframe = CFrame.new(0, 0.5, -0.6),
		color = CHITIN_LIGHT,
	}, { armor = true })
	shell(kit, {
		name = "Head",
		size = Vector3.new(1.6, 1.3, 1.4),
		cframe = CFrame.new(0, 0.6, -2.2),
		color = CHITIN,
	}, { weakspot = true })
	eyes(kit, CFrame.new(0, 0.9, -2.9), 0.45, 0.38)
	mandibles(kit, CFrame.new(0, 0.2, -2.8), 1.3)
	for index = 0, 2 do
		shell(kit, {
			name = "Spine",
			size = Vector3.new(0.3, 0.9, 0.3),
			cframe = CFrame.new(0, 1.9, 0.4 + index * 0.8) * CFrame.Angles(math.rad(-25), 0, 0),
			color = GLOW,
			material = Enum.Material.Neon,
			castShadow = false,
		})
	end
	legs(kit, 3, 1.2, 2.6, 1.1, 2.6, 0.32)
	return kit
end

local function bulwark(): Kit
	local kit = newRig("Bulwark", Vector3.new(5, 3.2, 6), 2.6)
	shell(kit, {
		name = "Body",
		shape = Enum.PartType.Ball,
		size = Vector3.new(5, 3.6, 6),
		cframe = CFrame.new(0, 0.4, 0.5),
		color = CHITIN,
	})
	-- The great front shield takes almost nothing from ordinary bullets.
	shell(kit, {
		name = "Shield",
		size = Vector3.new(6.2, 4.4, 0.9),
		cframe = CFrame.new(0, 0.9, -2.6) * CFrame.Angles(math.rad(-12), 0, 0),
		color = CHITIN_LIGHT,
		material = Enum.Material.Slate,
	}, { armor = true })
	for _, side in { -1, 1 } do
		shell(kit, {
			name = "Horn",
			size = Vector3.new(0.5, 0.5, 2.2),
			cframe = CFrame.new(side * 2.4, 2.6, -2.8) * CFrame.Angles(math.rad(25), 0, 0),
			color = BONE,
		}, { armor = true })
	end
	eyes(kit, CFrame.new(0, 2.4, -2.95), 0.7, 0.35)
	-- The glowing sac on its back is where it is soft.
	local sac = shell(kit, {
		name = "Sac",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.6, 2.2, 2.6),
		cframe = CFrame.new(0, 1.6, 2.8),
		color = SAC,
		material = Enum.Material.Neon,
		castShadow = false,
	}, { weakspot = true })
	Build.light(sac, "PointLight", { Color = SAC, Range = 12, Brightness = 1.4, Shadows = false })
	legs(kit, 3, 2, 3, 1.6, 4, 0.55)
	return kit
end

local function spitter(): Kit
	local kit = newRig("Spitter", Vector3.new(3, 4, 3), 0.2)
	shell(kit, {
		name = "Bulb",
		shape = Enum.PartType.Ball,
		size = Vector3.new(3.4, 3.6, 3.4),
		cframe = CFrame.new(0, 0.2, 0),
		color = CHITIN,
	})
	for index = 0, 4 do
		local angle = index * math.pi * 2 / 5
		shell(kit, {
			name = "Root",
			size = Vector3.new(0.5, 0.5, 2.6),
			cframe = CFrame.new(math.cos(angle) * 1.6, -1.5, math.sin(angle) * 1.6)
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(math.rad(20), 0, 0),
			color = CHITIN_LIGHT,
		})
	end
	local neck = shell(kit, {
		name = "Neck",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.3, 2.2, 0),
		cframe = CFrame.new(0, 2.6, 0),
		color = CHITIN_LIGHT,
	})
	neck:SetAttribute("Muzzle", true)
	local mouth = shell(kit, {
		name = "Mouth",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.7, 1.7, 1.7),
		cframe = CFrame.new(0, 3.9, 0),
		color = GLOW,
		material = Enum.Material.Neon,
		castShadow = false,
	}, { weakspot = true })
	Build.light(mouth, "PointLight", { Color = GLOW, Range = 14, Brightness = 1.2, Shadows = false })
	return kit
end

local function wasp(): Kit
	local kit = newRig("Wasp", Vector3.new(1.6, 1.4, 3), 0)
	shell(kit, {
		name = "Body",
		size = Vector3.new(1.2, 1.1, 2.4),
		cframe = CFrame.new(0, 0, 0),
		color = CHITIN,
	})
	shell(kit, {
		name = "Tail",
		size = Vector3.new(0.9, 0.9, 1.6),
		cframe = CFrame.new(0, -0.3, 1.8) * CFrame.Angles(math.rad(-25), 0, 0),
		color = GLOW,
		material = Enum.Material.Neon,
		castShadow = false,
	}, { weakspot = true })
	shell(kit, {
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(0, 0.1, -1.5),
		color = CHITIN_LIGHT,
	})
	eyes(kit, CFrame.new(0, 0.3, -1.9), 0.25, 0.25)
	for _, side in { -1, 1 } do
		local hip = CFrame.new(side * 0.6, 0.55, -0.2) * CFrame.Angles(0, 0, side * math.rad(-80))
		local wing = limb(
			kit,
			"Wing",
			hip,
			Vector3.new(0.08, 2.6, 1.3),
			Color3.fromRGB(190, 255, 170),
			if side > 0 then 0 else math.pi
		)
		wing.Transparency = 0.45
		wing.Material = Enum.Material.Glass
	end
	return kit
end

local function ravager(): Kit
	local kit = newRig("Ravager", Vector3.new(6, 4, 8), 3.6)
	shell(kit, {
		name = "Body",
		shape = Enum.PartType.Ball,
		size = Vector3.new(6.5, 5.5, 8.5),
		cframe = CFrame.new(0, 0.8, 0.6),
		color = CHITIN,
	})
	shell(kit, {
		name = "Carapace",
		size = Vector3.new(6, 1.2, 6),
		cframe = CFrame.new(0, 3.4, 0.2) * CFrame.Angles(math.rad(-8), 0, 0),
		color = CHITIN_LIGHT,
		material = Enum.Material.Slate,
	}, { armor = true })
	shell(kit, {
		name = "Head",
		size = Vector3.new(3, 2.4, 2.6),
		cframe = CFrame.new(0, 1.2, -4.2),
		color = CHITIN_LIGHT,
	}, { armor = true })
	for _, side in { -1, 1 } do
		shell(kit, {
			name = "Horn",
			size = Vector3.new(0.8, 0.8, 4),
			cframe = CFrame.new(side * 1.4, 2.4, -5.2) * CFrame.Angles(math.rad(30), side * math.rad(15), 0),
			color = BONE,
		}, { armor = true })
	end
	eyes(kit, CFrame.new(0, 1.6, -5.55), 0.8, 0.5)
	local core = shell(kit, {
		name = "Core",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.2, 2.2, 2.2),
		cframe = CFrame.new(0, 1, 4.6),
		color = GLOW,
		material = Enum.Material.Neon,
		castShadow = false,
	}, { weakspot = true })
	Build.light(core, "PointLight", { Color = GLOW, Range = 16, Brightness = 1.6, Shadows = false })
	legs(kit, 3, 2.6, 4.4, 2, 5, 0.8)
	return kit
end

local BUILDERS: { [Enemies.EnemyType]: () -> Kit } = {
	Drone = drone,
	Warrior = warrior,
	Bulwark = bulwark,
	Spitter = spitter,
	Wasp = wasp,
	Ravager = ravager,
}

function Vrill.build(enemyType: Enemies.EnemyType): Model
	local kit = BUILDERS[enemyType]()
	kit.model:SetAttribute("EnemyType", enemyType)
	return kit.model
end

return Vrill
