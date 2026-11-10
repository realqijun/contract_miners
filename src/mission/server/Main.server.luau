--!strict
-- Mission place entry point: resolves the launch, generates the cave, lands the Dropcan and spawns the crew.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Layout = require(Shared.Cave.Layout)
local LaunchData = require(Shared.LaunchData)
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)
local Net = require(Shared.Net)

local Server = ServerScriptService.Server
local Atmosphere = require(Server.Cave.Atmosphere)
local Carver = require(Server.Cave.Carver)
local Surface = require(Server.Cave.Surface)
local Dropcan = require(Server.Models.Dropcan)
local Gear = require(Server.Character.Gear)
local Vitals = require(Server.Character.Vitals)
local Deposits = require(Server.Mission.Deposits)
local Held = require(Server.Equipment.Held)
local Pickaxe = require(Server.Equipment.Pickaxe)
local Runtime = require(Server.Mission.Runtime)

local KEYS = MissionState.KEYS

Players.CharacterAutoLoads = false
Net.createAll()
MissionState.set(KEYS.Phase, "Loading")

-- Studio playtests have no hub teleport, so they launch a solo Mining run with a random seed.
-- Setting the DevMissionType, DevSeed or DevClass attributes on Workspace overrides those defaults.
local function studioLaunch(player: Player): LaunchData.LaunchData
	local missionType = Workspace:GetAttribute("DevMissionType")
	local seed = Workspace:GetAttribute("DevSeed")
	local classId = Workspace:GetAttribute("DevClass")
	return {
		missionType = if Missions.isMissionType(missionType) then missionType else "Mining",
		seed = if type(seed) == "number" then seed else Random.new():NextInteger(1, LaunchData.MAX_SEED),
		partySize = 1,
		classes = { [tostring(player.UserId)] = if Classes.isClassId(classId) then classId else "Scout" },
		walkthrough = false,
	}
end

local function resolveLaunch(): LaunchData.LaunchData
	local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local launch = LaunchData.validate(first:GetJoinData().TeleportData)
	if launch then
		return launch
	end
	if RunService:IsStudio() then
		return studioLaunch(first)
	end
	-- A mission server reached without a valid launch cannot run; send everyone back.
	error("Mission server started without valid launch data")
end

local launch = resolveLaunch()
MissionState.set(KEYS.MissionType, launch.missionType)
MissionState.set(KEYS.Seed, launch.seed)
MissionState.set(KEYS.PartySize, launch.partySize)

Atmosphere.apply()
local layout = Layout.generate(launch.seed)
Carver.carve(layout)

local startCavern = layout.caverns[layout.startCavern]
local landing = Surface.floorBelow(Surface.cavernOrigin(startCavern), startCavern.radii.Y * 2)
	or Vector3.new(startCavern.center.X, startCavern.floorY, startCavern.center.Z)
local dropcan = Dropcan.build(Workspace, CFrame.new(landing))
Runtime.init({ launch = launch, layout = layout, dropcan = dropcan })
Deposits.populate()

Vitals.start()
Held.start()
Pickaxe.start()

-- Spawn points in a ring around the Dropcan, dropped onto the floor.
local function spawnPoint(index: number): CFrame
	local angle = math.rad(-90 + (index - 1) * 50)
	local around = landing + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 11 + Vector3.yAxis * 6
	local floor = Surface.floorBelow(around, 20) or landing
	return CFrame.lookAt(floor + Vector3.yAxis * 3, Vector3.new(landing.X, floor.Y + 3, landing.Z))
end

local spawnIndex = 0
local function spawnCharacter(player: Player)
	local classId = launch.classes[tostring(player.UserId)]
	if not classId then
		player:Kick("You are not part of this mission's crew.")
		return
	end
	player:SetAttribute("Class", classId)
	spawnIndex += 1
	local spawnAt = spawnPoint(spawnIndex)
	player.CharacterAdded:Once(function(character)
		character:PivotTo(spawnAt)
	end)
	player:LoadCharacter()
	local character = player.Character
	if character then
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		Gear.equip(character, classId)
		Vitals.track(player, character)
	end
end

MissionState.set(KEYS.Phase, "Active")

Players.PlayerAdded:Connect(spawnCharacter)
for _, player in Players:GetPlayers() do
	task.spawn(spawnCharacter, player)
end
