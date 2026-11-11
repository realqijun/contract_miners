--!strict
-- Mission place entry point: resolves the launch, generates the cave, lands the Dropcan and spawns the crew.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CaveConfig = require(Shared.Config.Cave)
local Classes = require(Shared.Config.Classes)
local Layout = require(Shared.Cave.Layout)
local WalkthroughCave = require(Shared.Cave.WalkthroughCave)
local WalkthroughConfig = require(Shared.Config.Walkthrough)
local LaunchData = require(Shared.LaunchData)
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)
local Net = require(Shared.Net)
local Places = require(Shared.Config.Places)

local Server = ServerScriptService.Server
local Atmosphere = require(Server.Cave.Atmosphere)
local Carver = require(Server.Cave.Carver)
local Dressing = require(Server.Cave.Dressing)
local Surface = require(Server.Cave.Surface)
local Dropcan = require(Server.Models.Dropcan)
local Motion = require(Server.Character.Motion)
local Vitals = require(Server.Character.Vitals)
local Deposits = require(Server.Mission.Deposits)
local Held = require(Server.Equipment.Held)
local Pickaxe = require(Server.Equipment.Pickaxe)
local Weapons = require(Server.Equipment.Weapons)
local Tools = require(Server.Equipment.Tools)
local Projectiles = require(Server.Combat.Projectiles)
local Hive = require(Server.Enemies.Hive)
local Spawner = require(Server.Enemies.Spawner)
local Runtime = require(Server.Mission.Runtime)
local Crew = require(Server.Mission.Crew)
local Flow = require(Server.Mission.Flow)
local Revive = require(Server.Mission.Revive)
local Pings = require(Server.Mission.Pings)
local PlayerData = require(Server.Data.PlayerData)
local Progress = require(Shared.Progress)
local Objectives = require(Server.Mission.Objectives)
local Resupply = require(Server.Mission.Resupply)
local Walkthrough = require(Server.Mission.Walkthrough)

local KEYS = MissionState.KEYS
-- The fallback landing pad's size: room for the Dropcan and the crew's landing ring.
local LANDING_PAD_RADIUS = 16
local LANDING_HEADROOM = 20

Players.CharacterAutoLoads = false
Net.createAll()
PlayerData.start()
MissionState.set(KEYS.Phase, "Loading")

-- Studio playtests have no hub teleport, so they launch a solo Mining run with a random seed.
-- Setting the DevMissionType, DevSeed or DevClass attributes on Workspace overrides those defaults,
-- and DevWalkthrough = true runs the walkthrough instead.
local function studioLaunch(player: Player): LaunchData.LaunchData
	local missionType = Workspace:GetAttribute("DevMissionType")
	local seed = Workspace:GetAttribute("DevSeed")
	local classId = Workspace:GetAttribute("DevClass")
	local walkthrough = Workspace:GetAttribute("DevWalkthrough") == true
	return {
		missionType = if Missions.isMissionType(missionType) and not walkthrough then missionType else "Mining",
		seed = if type(seed) == "number" then seed else Random.new():NextInteger(1, LaunchData.MAX_SEED),
		partySize = 1,
		classes = { [tostring(player.UserId)] = if Classes.isClassId(classId) then classId else "Scout" },
		walkthrough = walkthrough,
	}
end

local function resolveLaunch(): LaunchData.LaunchData?
	local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local launch = LaunchData.validate(first:GetJoinData().TeleportData)
	if launch then
		return launch
	end
	if RunService:IsStudio() then
		return studioLaunch(first)
	end
	return nil
end

local resolved = resolveLaunch()
if not resolved then
	-- A mission server reached without a valid launch (a direct join, or tampered teleport data)
	-- cannot run: everyone who arrives goes back to the hub.
	warn("Mission server started without valid launch data; returning players to the hub")
	local function sendBack(player: Player)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(Places.HUB, { player })
		end)
		if not ok then
			warn("Returning a player to the hub failed:", err)
		end
	end
	Players.PlayerAdded:Connect(sendBack)
	for _, player in Players:GetPlayers() do
		task.spawn(sendBack, player)
	end
	return
end
local launch: LaunchData.LaunchData = resolved
MissionState.set(KEYS.MissionType, launch.missionType)
MissionState.set(KEYS.Seed, launch.seed)
MissionState.set(KEYS.PartySize, launch.partySize)

Atmosphere.apply()
-- The walkthrough plays in its own fixed cave; every other mission generates one from the seed.
local layout, spots
if launch.walkthrough then
	layout, spots = WalkthroughCave.build()
else
	layout = Layout.generate(launch.seed)
end
Carver.carve(layout)

-- The Dropcan lands on open, level floor in the start cavern. In the rare cave with none, it
-- flattens a pad at the cavern's centre: rock up to the floor level, open air above.
local startCavern = layout.caverns[layout.startCavern]
local landing = Crew.landingSite(startCavern)
if not landing then
	local site = Vector3.new(
		startCavern.center.X,
		math.round(startCavern.floorY / CaveConfig.VOXEL) * CaveConfig.VOXEL,
		startCavern.center.Z
	)
	warn(`No level landing in the start cavern of seed {launch.seed}; flattening a pad`)
	Workspace.Terrain:FillCylinder(
		CFrame.new(site + Vector3.yAxis * LANDING_HEADROOM / 2),
		LANDING_HEADROOM,
		LANDING_PAD_RADIUS,
		Enum.Material.Air
	)
	Workspace.Terrain:FillCylinder(
		CFrame.new(site - Vector3.yAxis * CaveConfig.VOXEL),
		CaveConfig.VOXEL * 2,
		LANDING_PAD_RADIUS,
		Enum.Material.Slate
	)
	-- Measure the pad once the edit has reached collision.
	task.wait()
	landing = Surface.floorBelow(site + Vector3.yAxis * CaveConfig.VOXEL * 2, CaveConfig.VOXEL * 4) or site
end
assert(landing, "landing resolved")
local dropcan = Dropcan.build(Workspace, CFrame.new(landing))
Runtime.init({ launch = launch, layout = layout, dropcan = dropcan, landing = landing })
if spots then
	Deposits.populateFixed(spots.volticite, spots.ferrin, WalkthroughConfig.VOLTICITE_TARGET)
else
	Deposits.populate()
end
-- Decoration keeps clear of the minerals and the landing site.
local keepClear = { landing }
for _, mineral in Workspace.Minerals:GetChildren() do
	if mineral:IsA("Model") then
		table.insert(keepClear, mineral:GetPivot().Position)
	end
end
Dressing.populate(layout, keepClear)

Vitals.start()
Motion.start()
Held.start()
Pickaxe.start()
Weapons.start()
Tools.start()
Projectiles.start()
Hive.start()
Spawner.start(launch.walkthrough)
Revive.start()
Pings.start()
if spots then
	Walkthrough.start(spots)
else
	Objectives.start()
end
Resupply.onRefill(Tools.refill)
-- Bank every crew member's rewards the moment the mission ends. The walkthrough is practice and
-- leaves progress untouched.
Flow.onEnded(function(outcome, rewards)
	if launch.walkthrough then
		return
	end
	for player, reward in rewards do
		local classId = launch.classes[tostring(player.UserId)]
		if classId then
			PlayerData.update(player, function(data)
				Progress.grant(data, classId, reward.credits, reward.xp)
				data.stats.missions += 1
				data.stats.successes += if outcome == "Success" then 1 else 0
				data.stats.volticite += player:GetAttribute("Delivered") or 0
			end)
		end
	end
end)

Flow.begin()
Players.PlayerAdded:Connect(Crew.land)
for _, player in Players:GetPlayers() do
	task.spawn(Crew.land, player)
end
