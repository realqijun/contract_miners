--!strict
-- Active Aegis Domes. Enemy spit hits the dome surface; melee against someone inside is softened.

local Workspace = game:GetService("Workspace")

local Shields = {}

type Dome = { part: BasePart, center: Vector3, radius: number, reduction: number }

local domes: { Dome } = {}
local folder: Folder? = nil

-- Domes live in their own folder: crew aim ignores it, enemy projectiles do not.
function Shields.folder(): Folder
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Shields"
		created.Parent = Workspace
		folder = created
	end
	return folder :: Folder
end

function Shields.add(part: BasePart, radius: number, reduction: number)
	table.insert(domes, { part = part, center = part.Position, radius = radius, reduction = reduction })
	part.Destroying:Connect(function()
		for index, dome in domes do
			if dome.part == part then
				table.remove(domes, index)
				break
			end
		end
	end)
end

-- Melee damage multiplier for someone standing at `position` (1 when unprotected).
function Shields.meleeMultiplier(position: Vector3): number
	local multiplier = 1
	for _, dome in domes do
		if (position - dome.center).Magnitude <= dome.radius then
			multiplier = math.min(multiplier, 1 - dome.reduction)
		end
	end
	return multiplier
end

return Shields
