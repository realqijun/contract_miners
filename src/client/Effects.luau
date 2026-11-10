--!strict
-- Local visual effects: impact debris, sparks and dust. Effects never affect gameplay.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

-- A bright streak from the muzzle to the impact that fades quickly.
function Effects.tracer(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 220, 150)
	part.Size = Vector3.new(0.08, 0.08, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = folder()
	TweenService:Create(
		part,
		TweenInfo.new(0.08, Enum.EasingStyle.Linear),
		{ Transparency = 1, Size = Vector3.new(0.02, 0.02, length) }
	):Play()
	Debris:AddItem(part, 0.1)
end

-- A brief flash and light at a muzzle.
function Effects.muzzleFlash(position: Vector3, direction: Vector3, color: Color3?)
	local holder = anchor(position, direction, 0.08)
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 200, 120)
	light.Range = 12
	light.Brightness = 3
	light.Shadows = false
	light.Parent = holder
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color or Color3.fromRGB(255, 210, 140)
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.5, 0.5, 0.5)
	flash.CFrame = CFrame.new(position)
	flash.Parent = folder()
	Debris:AddItem(flash, 0.05)
end

local EXPLOSION_COLORS: { [string]: Color3 } = {
	Blast = Color3.fromRGB(255, 150, 60),
	Mortar = Color3.fromRGB(255, 170, 70),
	Cryo = Color3.fromRGB(150, 220, 255),
	Seismic = Color3.fromRGB(210, 170, 120),
	Satchel = Color3.fromRGB(255, 120, 50),
	Decoy = Color3.fromRGB(255, 200, 80),
}

-- Fireball, flash and smoke sized to the blast radius.
function Effects.explosion(position: Vector3, radius: number, style: string)
	local color = EXPLOSION_COLORS[style] or EXPLOSION_COLORS.Blast
	local ball = Instance.new("Part")
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one * radius * 0.4
	ball.CFrame = CFrame.new(position)
	ball.Parent = folder()
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.4)

	local holder = anchor(position, Vector3.yAxis, 3)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 4
	light.Brightness = 5
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 80))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.4), NumberSequenceKeypoint.new(1, radius * 1.2) })
	smoke.Lifetime = NumberRange.new(1, 1.8)
	smoke.Speed = NumberRange.new(radius * 0.6, radius * 1.4)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 0
	smoke.Parent = holder
	smoke:Emit(14)
	Effects.impact(position, Vector3.yAxis, "Rock")
end

-- One tick of a flame stream: a burst of fire particles carried out to the stream's range.
function Effects.flame(position: Vector3, direction: Vector3, range: number)
	local holder = anchor(position, direction, 1.2)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 255)),
		ColorSequenceKeypoint.new(0.15, Color3.fromRGB(255, 200, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 30)),
	})
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 3.2) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.35, 0.5)
	fire.Speed = NumberRange.new(range * 1.8, range * 2.4)
	fire.SpreadAngle = Vector2.new(9, 9)
	fire.EmissionDirection = Enum.NormalId.Front
	fire.Rate = 0
	fire.Parent = holder
	fire:Emit(10)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 16
	light.Brightness = 2
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
end

-- Earth bursting where a Vrill digs in or out.
function Effects.burrow(position: Vector3)
	local holder = anchor(position, Vector3.yAxis, 2.5)
	local dirt = Instance.new("ParticleEmitter")
	dirt.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dirt.Color = ColorSequence.new(Color3.fromRGB(70, 56, 84))
	dirt.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dirt.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	dirt.Lifetime = NumberRange.new(0.8, 1.4)
	dirt.Speed = NumberRange.new(6, 14)
	dirt.SpreadAngle = Vector2.new(40, 40)
	dirt.EmissionDirection = Enum.NormalId.Front
	dirt.Acceleration = Vector3.new(0, -20, 0)
	dirt.Rate = 0
	dirt.Parent = holder
	dirt:Emit(16)
	Effects.impact(position, Vector3.yAxis, "Rock")
end

-- Bioluminescent splatter when a Vrill dies.
function Effects.enemyDeath(position: Vector3, size: number)
	local holder = anchor(position, Vector3.yAxis, 2)
	local goo = Instance.new("ParticleEmitter")
	goo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	goo.Color = ColorSequence.new(Color3.fromRGB(140, 255, 90))
	goo.LightEmission = 0.8
	goo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * size), NumberSequenceKeypoint.new(1, 0) })
	goo.Lifetime = NumberRange.new(0.4, 0.9)
	goo.Speed = NumberRange.new(8, 18)
	goo.SpreadAngle = Vector2.new(180, 180)
	goo.Acceleration = Vector3.new(0, -50, 0)
	goo.Rate = 0
	goo.Parent = holder
	goo:Emit(math.floor(10 + size * 4))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 255, 90)
	light.Range = 6 + size * 2
	light.Brightness = 2
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
end

local projectiles: { [number]: { part: Part, velocity: Vector3, gravity: number, age: number } } = {}
local PROJECTILE_COLORS: { [string]: Color3 } = {
	Mortar = Color3.fromRGB(255, 170, 70),
	Grenade = Color3.fromRGB(255, 200, 120),
	Acid = Color3.fromRGB(140, 255, 90),
}

-- Draws a server projectile locally along the same ballistic arc.
function Effects.projectile(id: number, origin: Vector3, velocity: Vector3, gravity: number, style: string)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = PROJECTILE_COLORS[style] or PROJECTILE_COLORS.Grenade
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.CFrame = CFrame.new(origin)
	part.Parent = folder()
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = part
	projectiles[id] = { part = part, velocity = velocity, gravity = gravity, age = 0 }
end

function Effects.endProjectile(id: number)
	local projectile = projectiles[id]
	if projectile then
		projectile.part:Destroy()
		projectiles[id] = nil
	end
end

RunService.Heartbeat:Connect(function(dt)
	for id, projectile in projectiles do
		projectile.age += dt
		local velocity = projectile.velocity - Vector3.yAxis * projectile.gravity * dt
		projectile.part.Position += (projectile.velocity + velocity) * 0.5 * dt
		projectile.velocity = velocity
		-- The end broadcast is unreliable; never leave a projectile flying forever.
		if projectile.age > 8 then
			Effects.endProjectile(id)
		end
	end
end)

return Effects
