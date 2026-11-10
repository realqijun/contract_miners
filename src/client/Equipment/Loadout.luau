--!strict
-- The local player's equipment slots: which item is in hand, switching, and routing fire input to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Parent.Input)

local Loadout = {}

export type Slot = "Primary" | "Secondary" | "Traversal" | "Support" | "Pickaxe"

export type Item = {
	equip: () -> (),
	unequip: () -> (),
	fire: ((down: boolean) -> ())?,
	altFire: ((down: boolean) -> ())?,
	reload: (() -> ())?,
}

local items: { [Slot]: Item } = {}
local current: Slot? = nil
-- The last weapon slot, so tools and the pickaxe hand back to it.
local lastWeapon: Slot = "Primary"
local enabled = true

function Loadout.select(slot: Slot)
	if slot == current or not items[slot] then
		return
	end
	local previous = current and items[current]
	if previous then
		if previous.fire then
			previous.fire(false)
		end
		previous.unequip()
	end
	current = slot
	if slot == "Primary" or slot == "Secondary" then
		lastWeapon = slot
	end
	items[slot].equip()
	Net.event("EquipSlot"):FireServer(slot)
	-- Keep firing if the trigger is still held across the switch.
	if Input.isHeld("Fire") then
		local fire = items[slot].fire
		if fire then
			fire(true)
		end
	end
end

function Loadout.current(): Slot?
	return current
end

function Loadout.returnToWeapon()
	Loadout.select(lastWeapon)
end

local function route(method: "fire" | "altFire", down: boolean)
	local item = current and items[current]
	if not (enabled and item) then
		return
	end
	local handler = item[method]
	if handler then
		handler(down)
	end
end

-- Installs the class's items and binds input. The first slot equipped is the primary weapon,
-- or the pickaxe if the class has no weapons installed.
function Loadout.start(installed: { [Slot]: Item })
	items = installed
	Input.onBegan("Fire", function()
		route("fire", true)
	end)
	Input.onEnded("Fire", function()
		route("fire", false)
	end)
	Input.onBegan("AltFire", function()
		route("altFire", true)
	end)
	Input.onEnded("AltFire", function()
		route("altFire", false)
	end)
	Input.onBegan("Reload", function()
		local item = current and items[current]
		if enabled and item and item.reload then
			item.reload()
		end
	end)
	for action, slot in
		{
			Primary = "Primary",
			Secondary = "Secondary",
			Traversal = "Traversal",
			Support = "Support",
			Pickaxe = "Pickaxe",
		} :: { [Input.Action]: Slot }
	do
		Input.onBegan(action, function()
			if enabled then
				Loadout.select(slot)
			end
		end)
	end
	Input.onBegan("CycleWeapon", function()
		if enabled then
			Loadout.select(if current == "Primary" then "Secondary" else "Primary")
		end
	end)
	Loadout.select(if items.Primary then "Primary" else "Pickaxe")
end

-- Downed players and open menus cannot use equipment.
function Loadout.setEnabled(value: boolean)
	enabled = value
	local item = current and items[current]
	if not value and item and item.fire then
		item.fire(false)
	end
end

return Loadout
