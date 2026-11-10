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
local Vitals = require(Server.Character.Vitals)
local Deposits = require(Server.Mission.Deposits)
local Held = require(Server.Equipment.Held)
local Pickaxe = require(Server.Equipment.Pickaxe)
local Weapons = require(Server.Equipment.Weapons)
local Projectiles = require(Server.Combat.Projectiles)
local Hive = require(Server.Enemies.Hive)
local Spawner = require(Server.Enemies.Spawner)
local Runtime = require(Server.Mission.Runtime)
local Crew = require(Server.Mission.Crew)
local Flow = require(Server.Mission.Flow)
local Revive = require(Server.Mission.Revive)

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
Runtime.init({ launch = launch, layout = layout, dropcan = dropcan, landing = landing })
Deposits.populate()

Vitals.start()
Held.start()
Pickaxe.start()
Weapons.start()
Projectiles.start()
Hive.start()
Spawner.start()
Revive.start()

Flow.begin()
Players.PlayerAdded:Connect(Crew.land)
for _, player in Players:GetPlayers() do
	task.spawn(Crew.land, player)
end
