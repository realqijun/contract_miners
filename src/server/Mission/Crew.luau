--!strict
-- Spawning crew members into the mission with their class gear, vitals and ammo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Cave.Layout)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Progress = require(ReplicatedStorage.Shared.Progress)

local Server = script.Parent.Parent
local PlayerData = require(Server.Data.PlayerData)
local Surface = require(Server.Cave.Surface)
local Gear = require(Server.Character.Gear)
local Vitals = require(Server.Character.Vitals)
local Weapons = require(Server.Equipment.Weapons)
local Tools = require(Server.Equipment.Tools)
local Runtime = require(script.Parent.Runtime)

local Crew = {}

local landingIndex = 0

-- Crew members land on a ring this far from the Dropcan, one place every RING_STEP_DEGREES.
local LANDING_RING = 11
local RING_STEP_DEGREES = 50
local RING_PLACES = 7
-- The landing search walks outwards from the cavern's centre in steps of this many studs, and
-- wants floor within these heights of the cavern's floor level and of the landing itself.
local LANDING_SEARCH_STEP = 6
local LANDING_LEVEL_TOLERANCE = 8
local LANDING_SPOT_TOLERANCE = 3

-- Is `player` part of this mission's launch crew?
function Crew.isCrew(player: Player): boolean
	return Runtime.get().launch.classes[tostring(player.UserId)] ~= nil
end

-- Loads a fresh character standing at `at`, dressed and armed for the player's class.
function Crew.spawn(player: Player, at: CFrame)
	local classId = Runtime.get().launch.classes[tostring(player.UserId)]
	local data = PlayerData.await(player)
	if not data then
		return
	end
	player:SetAttribute("Class", classId)
	-- Equipment stats on both sides read the equipped upgrades from this attribute.
	player:SetAttribute("Upgrades", table.concat(Progress.equippedList(data, classId), ","))
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

-- The floor under the `index`th place on a ring of `radius` around `center`, if there is any.
local function ringFloor(center: Vector3, index: number, radius: number): Vector3?
	local angle = math.rad(-90 + (index - 1) * RING_STEP_DEGREES)
	local around = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius + Vector3.yAxis * 6
	return Surface.floorBelow(around, 20)
end

-- A spot on the floor near `center`, facing it, for the `index`th person arriving there. A place
-- with no floor under it (rock, or a drop) passes to the next one round the ring, then to wider
-- rings, so nobody is ever put inside whatever stands at `center`.
function Crew.ringSpot(center: Vector3, index: number, radius: number): CFrame
	for _, scale in { 1, 1.5, 2 } do
		for step = 0, RING_PLACES - 1 do
			local floor = ringFloor(center, index + step, radius * scale)
			if floor then
				return CFrame.lookAt(floor + Vector3.yAxis * 3, Vector3.new(center.X, floor.Y + 3, center.Z))
			end
		end
	end
	return CFrame.new(center + Vector3.yAxis * 3)
end

-- Where the Dropcan lands: the stretch of the start cavern's floor nearest its centre that is at
-- the cavern's floor level and has level floor at every crew member's landing place, so nobody
-- arrives in a pit, on a ledge or inside rock. Nil when the cavern has no such stretch.
function Crew.landingSite(cavern: Layout.Cavern): Vector3?
	local origin = Surface.cavernOrigin(cavern)
	local reach = math.min(cavern.radii.X, cavern.radii.Z) * 0.6
	for distance = 0, reach, LANDING_SEARCH_STEP do
		local count = if distance == 0 then 1 else math.max(6, math.floor(2 * math.pi * distance / LANDING_SEARCH_STEP))
		for step = 0, count - 1 do
			local angle = step / count * 2 * math.pi
			local top = origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
			local floor = Surface.floorBelow(top, cavern.radii.Y * 2)
			if floor and math.abs(floor.Y - cavern.floorY) <= LANDING_LEVEL_TOLERANCE then
				local level = true
				for index = 1, Missions.MAX_PARTY do
					local spot = ringFloor(floor, index, LANDING_RING)
					if not spot or math.abs(spot.Y - floor.Y) > LANDING_SPOT_TOLERANCE then
						level = false
						break
					end
				end
				if level then
					return floor
				end
			end
		end
	end
	return nil
end

-- Spawns a crew member around the Dropcan at mission start.
function Crew.land(player: Player)
	if not Crew.isCrew(player) then
		player:Kick("You are not part of this mission's crew.")
		return
	end
	landingIndex += 1
	Crew.spawn(player, Crew.ringSpot(Runtime.get().landing, landingIndex, LANDING_RING))
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
