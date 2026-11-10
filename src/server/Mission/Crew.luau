--!strict
-- Spawning crew members into the mission with their class gear, vitals and ammo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Server = script.Parent.Parent
local Surface = require(Server.Cave.Surface)
local Gear = require(Server.Character.Gear)
local Vitals = require(Server.Character.Vitals)
local Weapons = require(Server.Equipment.Weapons)
local Tools = require(Server.Equipment.Tools)
local Runtime = require(script.Parent.Runtime)

local Crew = {}

local landingIndex = 0

-- Is `player` part of this mission's launch crew?
function Crew.isCrew(player: Player): boolean
	return Runtime.get().launch.classes[tostring(player.UserId)] ~= nil
end

-- Loads a fresh character standing at `at`, dressed and armed for the player's class.
function Crew.spawn(player: Player, at: CFrame)
	local classId = Runtime.get().launch.classes[tostring(player.UserId)]
	player:SetAttribute("Class", classId)
	player:SetAttribute("Dead", false)
	player.CharacterAdded:Once(function(character)
		character:PivotTo(at)
	end)
	player:LoadCharacter()
	local character = player.Character
	if not character then
		return
	end
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	-- Only satchel charges damage the crew; this tag is how they find us.
	CollectionService:AddTag(character, "Crew")
	Gear.equip(character, classId)
	Vitals.track(player, character)
	Weapons.arm(player)
	Tools.arm(player)
end

-- A spot near `center` on the floor, facing it, for the `index`th person arriving there.
function Crew.ringSpot(center: Vector3, index: number, radius: number): CFrame
	local angle = math.rad(-90 + (index - 1) * 50)
	local around = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius + Vector3.yAxis * 6
	local floor = Surface.floorBelow(around, 20) or center
	return CFrame.lookAt(floor + Vector3.yAxis * 3, Vector3.new(center.X, floor.Y + 3, center.Z))
end

-- Spawns a crew member around the Dropcan at mission start.
function Crew.land(player: Player)
	if not Crew.isCrew(player) then
		player:Kick("You are not part of this mission's crew.")
		return
	end
	landingIndex += 1
	Crew.spawn(player, Crew.ringSpot(Runtime.get().landing, landingIndex, 11))
end

-- Crew members currently standing (not downed or dead).
function Crew.standing(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Vitals.isAlive(player) then
			table.insert(list, player)
		end
	end
	return list
end

return Crew
