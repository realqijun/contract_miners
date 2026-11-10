--!strict
-- The local player's settings. Persisted by the server with the profile; this module holds the live values.

local Settings = {}

export type Values = {
	mouseSensitivity: number,
	gamepadSensitivity: number,
	invertY: boolean,
	fieldOfView: number,
	masterVolume: number,
	musicVolume: number,
	sfxVolume: number,
	aimAssist: number,
}

Settings.DEFAULTS = {
	mouseSensitivity = 1,
	gamepadSensitivity = 1,
	invertY = false,
	fieldOfView = 80,
	masterVolume = 1,
	musicVolume = 0.7,
	sfxVolume = 1,
	aimAssist = 0.5,
} :: Values

local values: Values = table.clone(Settings.DEFAULTS)
local listeners: { (Values) -> () } = {}

function Settings.get(): Values
	return values
end

function Settings.apply(changes: { [string]: any })
	for key, value in changes do
		if (Settings.DEFAULTS :: any)[key] ~= nil and typeof(value) == typeof((Settings.DEFAULTS :: any)[key]) then
			(values :: any)[key] = value
		end
	end
	for _, listener in listeners do
		task.spawn(listener, values)
	end
end

-- Calls `callback` now and on every change.
function Settings.observe(callback: (Values) -> ())
	table.insert(listeners, callback)
	task.spawn(callback, values)
end

return Settings
