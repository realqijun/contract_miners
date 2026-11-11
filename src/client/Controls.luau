--!strict
-- The controls reference, in the order players read it: the hub's controls board and the menu's
-- Controls tab both list these rows, so they never disagree with each other or with `Input`.

local Input = require(script.Parent.Input)

local Controls = {}

export type Row = { label: string, keyboard: string, gamepad: string }

local ACTIONS: { { label: string, action: Input.Action } } = {
	{ label = "Fire / mine", action = "Fire" },
	{ label = "Heavy swing (pickaxe)", action = "AltFire" },
	{ label = "Reload", action = "Reload" },
	{ label = "Primary / secondary weapon", action = "Primary" },
	{ label = "Traversal tool", action = "Traversal" },
	{ label = "Support tool", action = "Support" },
	{ label = "Pickaxe", action = "Pickaxe" },
	{ label = "Grenade", action = "Grenade" },
	{ label = "Flare", action = "Flare" },
	{ label = "Interact / revive / deposit", action = "Interact" },
	{ label = "Ping (hold: call resupply)", action = "Ping" },
	{ label = "First / third person", action = "CameraToggle" },
	{ label = "Team status (hold)", action = "TeamStatus" },
	{ label = "Sprint", action = "Sprint" },
	{ label = "Crouch", action = "Crouch" },
	{ label = "Menu", action = "Menu" },
}

-- Weapon switching is two keys on a keyboard and one cycling button on a gamepad.
local KEYBOARD_OVERRIDES: { [Input.Action]: string } = { Primary = "1 / 2" }
local GAMEPAD_OVERRIDES: { [Input.Action]: string } = { Primary = Input.LABELS.gamepad.CycleWeapon }

function Controls.rows(): { Row }
	local rows = {}
	for _, entry in ACTIONS do
		table.insert(rows, {
			label = entry.label,
			keyboard = KEYBOARD_OVERRIDES[entry.action] or Input.LABELS.keyboard[entry.action] or "-",
			gamepad = GAMEPAD_OVERRIDES[entry.action] or Input.LABELS.gamepad[entry.action] or "-",
		})
	end
	return rows
end

return Controls
