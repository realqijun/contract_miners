--!strict
-- The class terminal: four class cards with their role, level and kit; picking one changes your gear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Kits = require(Shared.Config.Kits)
local Net = require(Shared.Net)
local Progress = require(Shared.Progress)
local Progression = require(Shared.Config.Progression)
local ToolsConfig = require(Shared.Config.Tools)
local Weapons = require(Shared.Config.Weapons)

local Client = ReplicatedStorage.Client
local Menu = require(Client.UI.Menu)
local Theme = require(Client.UI.Theme)
local ProgressView = require(Client.ProgressView)

local ClassSelect = {}

local function itemLine(id: string): (string, string)
	local weapon = (Weapons.STATS :: any)[id]
	if weapon then
		return weapon.displayName, weapon.description
	end
	local tool = ToolsConfig.TOOLS[id] or ToolsConfig.GRENADES[id]
	return tool.displayName, tool.description
end

local function card(parent: Instance, classId: Classes.ClassId, data: Progress.Data, order: number)
	local info = Classes.INFO[classId]
	local selected = data.selectedClass == classId
	local frame = Theme.panel(classId, parent)
	frame.LayoutOrder = order
	frame.Size = UDim2.new(0.25, -9, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(28, 24, 38)
	local stroke = Instance.new("UIStroke")
	stroke.Color = info.color
	stroke.Thickness = if selected then 3 else 1
	stroke.Parent = frame
	Theme.label(frame, {
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28, 0, 26),
		Font = Theme.FONT_HEAVY,
		TextSize = 22,
		TextColor3 = info.color,
		Text = string.upper(info.displayName),
	})
	local xp = data.classes[classId].xp
	local level = Progression.levelFor(xp)
	local nextXp = Progression.LEVEL_XP[level + 1]
	local floorXp = Progression.LEVEL_XP[level] or 0
	Theme.label(frame, {
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 18),
		TextSize = 14,
		TextColor3 = Theme.TEXT_DIM,
		Text = info.role,
	})
	Theme.label(frame, {
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(1, -28, 0, 18),
		TextSize = 14,
		Font = Theme.FONT_BOLD,
		-- XP within the current level, the same span the bar below fills.
		Text = `Level {level}` .. (if nextXp then `  ·  {xp - floorXp} / {nextXp - floorXp} XP` else "  ·  Max"),
	})
	local bar = Theme.bar(frame, info.color, UDim2.fromOffset(14, 82), UDim2.new(1, -28, 0, 4))
	bar.set(if nextXp then (xp - floorXp) / (nextXp - floorXp) else 1)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 98)
	list.Size = UDim2.new(1, -28, 1, -158)
	list.Parent = frame
	Menu.list(list, 6)
	local kit = Kits.BY_CLASS[classId]
	for index, id in { kit.primary, kit.secondary, kit.traversal, kit.support, kit.grenade } do
		local name, description = itemLine(id)
		Theme.label(list, {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 52),
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true,
			Text = `<b>{name}</b>\n<font color="#A096B6">{description}</font>`,
		})
	end
	local button = Menu.button(frame, if selected then "Selected" else "Select", function()
		Net.func("SelectClass"):InvokeServer(classId)
	end, if selected then "Selected" else "Primary")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -14)
	button.Size = UDim2.new(1, -28, 0, 38)
end

function ClassSelect.open()
	local content = Menu.open("Choose your class", 1100, 560)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = content
	local layout = Menu.list(row, 12)
	layout.FillDirection = Enum.FillDirection.Horizontal
	local connection: RBXScriptConnection? = nil
	connection = ProgressView.observe(function(data)
		if not row.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		for _, child in row:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for order, classId in Classes.ORDER do
			card(row, classId, data, order)
		end
	end)
end

return ClassSelect
