--!strict
-- Lighting and terrain colouring for Kessra's violet crystal caves.
-- Lighting.Technology must be set to Future in the Mission place file itself; scripts cannot change it.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Atmosphere = {}

local TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Slate] = Color3.fromRGB(58, 48, 74),
	[Enum.Material.Basalt] = Color3.fromRGB(36, 30, 50),
}

-- Replaces any previous post effect of the same name so applying twice is harmless.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className :: any)
	created.Name = name
	return created
end

function Atmosphere.apply()
	for material, color in TERRAIN_COLORS do
		Workspace.Terrain:SetMaterialColor(material, color)
	end

	-- Caves are lit only by the miners, crystals and fungi; daylight never reaches them.
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(26, 20, 38)
	Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.3
	Lighting.FogColor = Color3.fromRGB(14, 10, 22)
	Lighting.FogStart = 40
	Lighting.FogEnd = 260

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end

	local bloom = effect("BloomEffect", "CaveBloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local grade = effect("ColorCorrectionEffect", "CaveGrade") :: ColorCorrectionEffect
	grade.Contrast = 0.12
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(236, 230, 255)
	grade.Parent = Lighting
end

return Atmosphere
