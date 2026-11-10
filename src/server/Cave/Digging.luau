--!strict
-- Server-side terrain removal. Every dig goes through here so the solid shell is never breached.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CaveConfig = require(ReplicatedStorage.Shared.Config.Cave)
local Dressing = require(script.Parent.Dressing)

local Digging = {}

local LOW = CaveConfig.MIN_CORNER + Vector3.one * CaveConfig.SHELL
local HIGH = CaveConfig.MIN_CORNER + CaveConfig.SIZE - Vector3.one * CaveConfig.SHELL

-- Largest radius that keeps a sphere at `center` inside the diggable volume, or 0.
local function safeRadius(center: Vector3, radius: number): number
	local room = math.min(
		center.X - LOW.X,
		center.Y - LOW.Y,
		center.Z - LOW.Z,
		HIGH.X - center.X,
		HIGH.Y - center.Y,
		HIGH.Z - center.Z
	)
	return math.clamp(math.min(radius, room), 0, radius)
end

-- Removes a sphere of terrain. Returns false if nothing could be dug there.
function Digging.sphere(center: Vector3, radius: number): boolean
	local allowed = safeRadius(center, radius)
	if allowed < 1 then
		return false
	end
	Workspace.Terrain:FillBall(center, allowed, Enum.Material.Air)
	Dressing.clear(center, allowed)
	return true
end

-- Removes a capsule of terrain between two points (tunnelling beams).
function Digging.capsule(from: Vector3, to: Vector3, radius: number): boolean
	local length = (to - from).Magnitude
	local steps = math.max(1, math.ceil(length / (radius * 0.75)))
	local dug = false
	for step = 0, steps do
		dug = Digging.sphere(from:Lerp(to, step / steps), radius) or dug
	end
	return dug
end

function Digging.isDiggable(position: Vector3): boolean
	return safeRadius(position, 1) >= 1
end

return Digging
