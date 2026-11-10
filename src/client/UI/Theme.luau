--!strict
-- Shared look for every screen: colours, fonts and small widget builders.

local Theme = {}

Theme.FONT = Enum.Font.GothamMedium
Theme.FONT_BOLD = Enum.Font.GothamBold
Theme.FONT_HEAVY = Enum.Font.GothamBlack

Theme.TEXT = Color3.fromRGB(236, 230, 248)
Theme.TEXT_DIM = Color3.fromRGB(160, 150, 182)
Theme.PANEL = Color3.fromRGB(16, 12, 24)
Theme.PANEL_TRANSPARENCY = 0.25
Theme.TRACK = Color3.fromRGB(40, 34, 54)
Theme.HEALTH = Color3.fromRGB(232, 64, 76)
Theme.SHIELD = Color3.fromRGB(86, 200, 255)
Theme.VOLTICITE = Color3.fromRGB(176, 96, 255)
Theme.FERRIN = Color3.fromRGB(226, 104, 58)
Theme.ACCENT = Color3.fromRGB(255, 176, 64)
Theme.WARNING = Color3.fromRGB(255, 92, 72)

function Theme.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
end

function Theme.panel(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.PANEL
	frame.BackgroundTransparency = Theme.PANEL_TRANSPARENCY
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame)
	return frame
end

function Theme.label(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.TextColor3 = Theme.TEXT
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

export type Bar = {
	frame: Frame,
	set: (fraction: number) -> (),
}

-- A horizontal fill bar.
function Theme.bar(parent: Instance, color: Color3, position: UDim2, size: UDim2): Bar
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.TRACK
	track.BorderSizePixel = 0
	track.Position = position
	track.Size = size
	track.Parent = parent
	Theme.corner(track, 3)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	Theme.corner(fill, 3)
	return {
		frame = track,
		set = function(fraction: number)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		end,
	}
end

return Theme
