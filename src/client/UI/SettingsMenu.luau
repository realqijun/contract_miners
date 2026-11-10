--!strict
-- The settings menu, shared by the hub and missions.

local Settings = require(script.Parent.Parent.Settings)
local Menu = require(script.Parent.Menu)

local SettingsMenu = {}

local function percent(value: number): string
	return `{math.floor(value * 100 + 0.5)}%`
end

local function multiplier(value: number): string
	return string.format("%.2fx", value)
end

function SettingsMenu.open()
	local content = Menu.open("Settings", 640, 460)
	Menu.list(content, 6)
	local values = Settings.get()
	local function slider(label: string, key: string, min: number, max: number, format: (number) -> string)
		Menu.slider(content, label, min, max, (values :: any)[key], format, function(value)
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
	invert = Menu.button(content, label(), function()
		Settings.apply({ invertY = not Settings.get().invertY })
		invert.Text = label()
	end)
	invert.Size = UDim2.fromOffset(220, 36)
end

return SettingsMenu
