--!strict
-- The settings menu, shared by the hub and missions: a Settings tab and a Controls reference tab.

local Controls = require(script.Parent.Parent.Controls)
local Settings = require(script.Parent.Parent.Settings)
local Menu = require(script.Parent.Menu)
local Theme = require(script.Parent.Theme)

local SettingsMenu = {}

type Tab = "Settings" | "Controls"

local TABS: { Tab } = { "Settings", "Controls" }
local TAB_HEIGHT = 34
local TAB_GAP = 14

local function percent(value: number): string
	return `{math.floor(value * 100 + 0.5)}%`
end

local function multiplier(value: number): string
	return string.format("%.2fx", value)
end

local function settingsTab(body: Frame)
	Menu.list(body, 6)
	local values = Settings.get()
	local function slider(label: string, key: string, min: number, max: number, format: (number) -> string)
		Menu.slider(body, label, min, max, (values :: any)[key], format, function(value)
			Settings.apply({ [key] = value })
		end)
	end
	slider("Mouse sensitivity", "mouseSensitivity", 0.1, 4, multiplier)
	slider("Gamepad sensitivity", "gamepadSensitivity", 0.1, 4, multiplier)
	slider("Field of view", "fieldOfView", 60, 100, function(value)
		return tostring(math.floor(value + 0.5))
	end)
	slider("Master volume", "masterVolume", 0, 1, percent)
	slider("Music volume", "musicVolume", 0, 1, percent)
	slider("Effects volume", "sfxVolume", 0, 1, percent)
	slider("Gamepad aim assist", "aimAssist", 0, 1, percent)
	local invert: TextButton
	local function label(): string
		return if Settings.get().invertY then "Invert look: ON" else "Invert look: OFF"
	end
	invert = Menu.button(body, label(), function()
		Settings.apply({ invertY = not Settings.get().invertY })
		invert.Text = label()
	end)
	invert.Size = UDim2.fromOffset(220, 36)
end

local function controlsTab(body: Frame)
	Menu.list(body, 0)
	local function row(order: number, cells: { string }, header: boolean)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, if header then 26 else 21)
		frame.LayoutOrder = order
		frame.Parent = body
		local columns = { { 0, 0.56 }, { 0.56, 0.22 }, { 0.78, 0.22 } }
		for index, text in cells do
			Theme.label(frame, {
				Position = UDim2.fromScale(columns[index][1], 0),
				Size = UDim2.fromScale(columns[index][2], 1),
				TextSize = if header then 13 else 15,
				Font = if header or index == 2 then Theme.FONT_BOLD else Theme.FONT,
				TextColor3 = if header or index == 3
					then Theme.TEXT_DIM
					elseif index == 2 then Theme.ACCENT
					else Theme.TEXT,
				TextYAlignment = if header then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
				Text = text,
			})
		end
	end
	row(0, { "ACTION", "KEYBOARD", "GAMEPAD" }, true)
	for index, entry in Controls.rows() do
		row(index, { entry.label, entry.keyboard, entry.gamepad }, false)
	end
end

function SettingsMenu.open(initial: Tab?)
	local content = Menu.open("Settings", 640, 520)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, TAB_HEIGHT + TAB_GAP)
	body.Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + TAB_GAP))
	body.Parent = content

	local buttons: { [Tab]: TextButton } = {}
	local function show(tab: Tab)
		body:ClearAllChildren()
		for name, button in buttons do
			local selected = name == tab
			button.BackgroundColor3 = if selected then Theme.ACCENT else Menu.SECONDARY
			button.TextColor3 = if selected then Menu.ON_ACCENT else Theme.TEXT
		end
		if tab == "Settings" then
			settingsTab(body)
		else
			controlsTab(body)
		end
	end
	for index, tab in TABS do
		local button = Menu.button(content, tab, function()
			show(tab)
		end)
		button.Position = UDim2.fromOffset((index - 1) * 128, 0)
		button.Size = UDim2.fromOffset(120, TAB_HEIGHT)
		buttons[tab] = button
	end
	show(initial or "Settings")
end

return SettingsMenu
