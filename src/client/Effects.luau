--!strict
-- Local visual effects: impact debris, sparks and dust. Effects never affect gameplay.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)

local Effects = {}

local SURFACE_COLORS: { [string]: Color3 } = {
	Rock = Color3.fromRGB(96, 82, 116),
	Flesh = Color3.fromRGB(150, 230, 90),
	Volticite = Resources.COLORS.Volticite,
	Ferrin = Resources.COLORS.Ferrin,
	Health = Resources.COLORS.Health,
	Metal = Color3.fromRGB(255, 200, 120),
}

local function folder(): Folder
	local existing = Workspace:FindFirstChild("Effects")
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = "Effects"
	created.Parent = Workspace
	return created
end

local function anchor(position: Vector3, normal: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.lookAlong(position, normal)
	part.Parent = folder()
	Debris:AddItem(part, lifetime)
	return part
end

-- Chips and dust thrown off a struck surface.
function Effects.impact(position: Vector3, normal: Vector3, surface: string)
	local color = SURFACE_COLORS[surface] or SURFACE_COLORS.Rock
	local holder = anchor(position + normal * 0.2, normal, 2)

	local chips = Instance.new("ParticleEmitter")
	chips.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chips.Color = ColorSequence.new(color)
	chips.LightEmission = if surface == "Rock" then 0 else 0.6
	chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	chips.Lifetime = NumberRange.new(0.35, 0.7)
	chips.Speed = NumberRange.new(10, 20)
	chips.SpreadAngle = Vector2.new(55, 55)
	chips.Acceleration = Vector3.new(0, -60, 0)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Rate = 0
	chips.Parent = holder
	chips:Emit(if surface == "Rock" then 10 else 16)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(color:Lerp(Color3.new(0.3, 0.3, 0.3), 0.5))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Rate = 0
	dust.Parent = holder
	dust:Emit(4)
end

return Effects
