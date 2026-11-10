--!strict
-- Bottom-right panel for whatever is in hand: name, magazine and reserve (or charges), heat bar.
-- Items push their status here whenever it changes.

local Theme = require(script.Parent.Theme)
local Hud = require(script.Parent.Hud)

local EquipmentHud = {}

export type Status = {
	name: string,
	-- Big number (magazine or charges); nil hides it.
	primary: number?,
	-- Small number after the slash (reserve); nil hides it.
	secondary: number?,
	-- 0..1 heat or cooldown bar; nil hides it.
	bar: number?,
	barColor: Color3?,
	-- Short state line: "RELOADING", "OVERHEATED", "Heavy swing ready".
	note: string?,
}

local panel: Frame
local nameLabel: TextLabel
local primaryLabel: TextLabel
local secondaryLabel: TextLabel
local noteLabel: TextLabel
local bar: Theme.Bar

local function ensure()
	if panel then
		return
	end
	panel = Theme.panel("Equipment", Hud.gui())
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -24, 1, -24)
	panel.Size = UDim2.fromOffset(260, 92)
	nameLabel = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Theme.FONT_BOLD,
		TextSize = 14,
		TextColor3 = Theme.TEXT_DIM,
	})
	-- Magazine and reserve sit side by side, baseline-aligned.
	local counts = Instance.new("Frame")
	counts.BackgroundTransparency = 1
	counts.Position = UDim2.fromOffset(14, 26)
	counts.Size = UDim2.fromOffset(200, 40)
	counts.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.Parent = counts
	primaryLabel = Theme.label(counts, {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.FONT_HEAVY,
		TextSize = 36,
		LayoutOrder = 1,
	})
	secondaryLabel = Theme.label(counts, {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.FONT_BOLD,
		TextSize = 18,
		TextColor3 = Theme.TEXT_DIM,
		LayoutOrder = 2,
	})
	noteLabel = Theme.label(panel, {
		Position = UDim2.fromOffset(124, 26),
		Size = UDim2.new(1, -138, 0, 14),
		Font = Theme.FONT_BOLD,
		TextSize = 12,
		TextColor3 = Theme.ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bar = Theme.bar(panel, Theme.ACCENT, UDim2.new(0, 14, 1, -18), UDim2.new(1, -28, 0, 6))
end

function EquipmentHud.show(status: Status)
	ensure()
	nameLabel.Text = string.upper(status.name)
	primaryLabel.Text = if status.primary then tostring(status.primary) else ""
	primaryLabel.TextColor3 = if status.primary == 0 then Theme.WARNING else Theme.TEXT
	secondaryLabel.Text = if status.secondary then "/ " .. tostring(status.secondary) else ""
	noteLabel.Text = status.note or ""
	bar.frame.Visible = status.bar ~= nil
	if status.bar then
		bar.set(status.bar)
		local fill = bar.frame:FindFirstChildOfClass("Frame")
		if fill then
			fill.BackgroundColor3 = status.barColor or Theme.ACCENT
		end
	end
end

return EquipmentHud
