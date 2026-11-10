--!strict
-- Named input actions for keyboard/mouse and gamepad.
-- Gameplay code listens to actions, never to raw keys, so bindings live in one table.

local UserInputService = game:GetService("UserInputService")

local Input = {}

export type Action =
	"Fire"
	| "AltFire"
	| "Reload"
	| "Primary"
	| "Secondary"
	| "CycleWeapon"
	| "Traversal"
	| "Support"
	| "Pickaxe"
	| "Grenade"
	| "Flare"
	| "Interact"
	| "Ping"
	| "CameraToggle"
	| "TeamStatus"
	| "Sprint"
	| "Crouch"
	| "Menu"

type Binding = Enum.KeyCode | Enum.UserInputType

local BINDINGS: { [Action]: { Binding } } = {
	Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	AltFire = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },
	Primary = { Enum.KeyCode.One },
	Secondary = { Enum.KeyCode.Two },
	CycleWeapon = { Enum.KeyCode.DPadUp },
	Traversal = { Enum.KeyCode.Three, Enum.KeyCode.DPadRight },
	Support = { Enum.KeyCode.Four, Enum.KeyCode.DPadLeft },
	Pickaxe = { Enum.KeyCode.Q, Enum.KeyCode.DPadDown },
	Grenade = { Enum.KeyCode.G, Enum.KeyCode.ButtonR1 },
	Flare = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
	Interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	Ping = { Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonSelect },
	CameraToggle = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 },
	TeamStatus = { Enum.KeyCode.Tab },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Crouch = { Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB },
	Menu = { Enum.KeyCode.M, Enum.KeyCode.ButtonStart },
}

-- Human-readable key names for hints and the controls board.
Input.LABELS = {
	keyboard = {
		Fire = "LMB",
		AltFire = "RMB",
		Reload = "R",
		Primary = "1",
		Secondary = "2",
		Traversal = "3",
		Support = "4",
		Pickaxe = "Q",
		Grenade = "G",
		Flare = "F",
		Interact = "E",
		Ping = "MMB",
		CameraToggle = "V",
		TeamStatus = "Tab",
		Sprint = "Shift",
		Crouch = "Ctrl",
		Menu = "M",
	},
	gamepad = {
		Fire = "RT",
		AltFire = "LT",
		Reload = "Y",
		CycleWeapon = "D-Up",
		Traversal = "D-Right",
		Support = "D-Left",
		Pickaxe = "D-Down",
		Grenade = "RB",
		Flare = "LB",
		Interact = "X",
		Ping = "View",
		CameraToggle = "RS",
		Sprint = "LS",
		Crouch = "B",
		Menu = "Menu",
	},
} :: { [string]: { [Action]: string } }

local actionsFor: { [Binding]: { Action } } = {}
for action, bindings in BINDINGS do
	for _, binding in bindings do
		actionsFor[binding] = actionsFor[binding] or {}
		table.insert(actionsFor[binding], action)
	end
end

local held: { [Action]: number } = {}
local began: { [Action]: { (Action) -> () } } = {}
local ended: { [Action]: { (Action) -> () } } = {}
local enabled = true

local function bindingOf(input: InputObject): Binding
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:match("^Gamepad") then
		return input.KeyCode
	end
	return input.UserInputType
end

local function dispatch(list: { (Action) -> () }?, action: Action)
	if list then
		for _, callback in list do
			task.spawn(callback, action)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not enabled then
		return
	end
	for _, action in actionsFor[bindingOf(input)] or {} do
		held[action] = (held[action] or 0) + 1
		if held[action] == 1 then
			dispatch(began[action], action)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	for _, action in actionsFor[bindingOf(input)] or {} do
		local count = held[action]
		if count then
			if count <= 1 then
				held[action] = nil
				dispatch(ended[action], action)
			else
				held[action] = count - 1
			end
		end
	end
end)

-- Calls `callback` when the action is pressed. Returns a function that disconnects it.
function Input.onBegan(action: Action, callback: (Action) -> ()): () -> ()
	began[action] = began[action] or {}
	table.insert(began[action], callback)
	return function()
		local index = table.find(began[action], callback)
		if index then
			table.remove(began[action], index)
		end
	end
end

-- Calls `callback` when the action is released. Returns a function that disconnects it.
function Input.onEnded(action: Action, callback: (Action) -> ()): () -> ()
	ended[action] = ended[action] or {}
	table.insert(ended[action], callback)
	return function()
		local index = table.find(ended[action], callback)
		if index then
			table.remove(ended[action], index)
		end
	end
end

function Input.isHeld(action: Action): boolean
	return held[action] ~= nil
end

-- Disables gameplay input (menus open, downed). Releases everything held.
function Input.setEnabled(value: boolean)
	enabled = value
	if not value then
		for action in held do
			held[action] = nil
			dispatch(ended[action], action)
		end
	end
end

function Input.isGamepad(): boolean
	return UserInputService:GetLastInputType().Name:match("^Gamepad") ~= nil
end

function Input.label(action: Action): string
	local labels = if Input.isGamepad() then Input.LABELS.gamepad else Input.LABELS.keyboard
	return labels[action] or "?"
end

return Input
