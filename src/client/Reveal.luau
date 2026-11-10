--!strict
-- Outlines minerals revealed by a Lumen Dart until their reveal runs out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)

local Reveal = {}

local function watch(mineral: Instance)
	if not mineral:IsA("Model") then
		return
	end
	mineral:GetAttributeChangedSignal("RevealedUntil"):Connect(function()
		local untilTime = mineral:GetAttribute("RevealedUntil")
		if type(untilTime) ~= "number" then
			return
		end
		local highlight = mineral:FindFirstChild("Reveal") :: Highlight?
		if not highlight then
			local created = Instance.new("Highlight")
			created.Name = "Reveal"
			created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			created.FillTransparency = 0.7
			local kind = mineral:GetAttribute("Kind")
			created.OutlineColor = (Resources.COLORS :: any)[kind] or Color3.new(1, 1, 1)
			created.FillColor = created.OutlineColor
			created.Parent = mineral
			highlight = created
		end
		task.delay(math.max(0, untilTime - Workspace:GetServerTimeNow()), function()
			if mineral:GetAttribute("RevealedUntil") == untilTime and highlight then
				highlight:Destroy()
			end
		end)
	end)
end

function Reveal.start()
	local minerals = Workspace:WaitForChild("Minerals")
	minerals.ChildAdded:Connect(watch)
	for _, mineral in minerals:GetChildren() do
		watch(mineral)
	end
end

return Reveal
