--!strict
-- Launch bays: crews form by standing on a pad. The first player on a pad leads and picks the
-- mission at its board; a countdown then teleports everyone on the pad into a reserved mission
-- server together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LaunchData = require(Shared.LaunchData)
local Missions = require(Shared.Config.Missions)
local Net = require(Shared.Net)
local Places = require(Shared.Config.Places)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Deck = require(script.Parent.Deck)

local LaunchPads = {}

local PAD_RADIUS = 11
local COUNTDOWN = 10

type Pad = {
	index: number,
	center: Vector3,
	board: BasePart,
	dropcan: any,
	members: { Player },
	leader: Player?,
	missionType: Missions.MissionType?,
	seed: number?,
	launchAt: number?,
	-- Replicated state for the board and HUD.
	state: Configuration,
}

local pads: { Pad } = {}
local rng = Random.new()

local function onPad(pad: Pad, player: Player): boolean
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return false
	end
	local offset = root.Position - pad.center
	return Vector2.new(offset.X, offset.Z).Magnitude <= PAD_RADIUS and offset.Y < 12
end

local function publish(pad: Pad)
	local names = {}
	for _, member in pad.members do
		table.insert(names, member.DisplayName)
	end
	pad.state:SetAttribute("Members", table.concat(names, ", "))
	pad.state:SetAttribute("LeaderId", if pad.leader then pad.leader.UserId else 0)
	pad.state:SetAttribute("MissionType", pad.missionType or "")
	pad.state:SetAttribute("Seed", pad.seed or 0)
	pad.state:SetAttribute("LaunchAt", pad.launchAt or 0)
	local display = if pad.launchAt
		then `LAUNCH IN {math.max(0, math.ceil(pad.launchAt - Workspace:GetServerTimeNow()))}`
		elseif pad.leader then "PICK A MISSION"
		else "STANDBY"
	pad.dropcan.setDisplay(display)
end

local function reset(pad: Pad)
	pad.missionType = nil
	pad.seed = nil
	pad.launchAt = nil
end

local function notice(players: { Player }, text: string)
	for _, player in players do
		Net.event("Notice"):FireClient(player, text)
	end
end

-- Builds the launch data for the crew on a pad and teleports them.
local function launch(pad: Pad)
	local crew = table.clone(pad.members)
	local missionType = pad.missionType :: Missions.MissionType
	local seed = pad.seed or rng:NextInteger(1, LaunchData.MAX_SEED)
	reset(pad)
	local classes = {}
	for _, member in crew do
		local data = PlayerData.get(member)
		classes[tostring(member.UserId)] = if data then data.selectedClass else "Scout"
	end
	local launchData: LaunchData.LaunchData = {
		missionType = missionType,
		seed = seed,
		partySize = #crew,
		classes = classes,
		walkthrough = false,
	}
	LaunchPads.teleport(crew, launchData)
end

-- Teleports a crew into a fresh reserved Mission server carrying `launchData`.
function LaunchPads.teleport(crew: { Player }, launchData: LaunchData.LaunchData)
	if RunService:IsStudio() or not Places.published() then
		notice(crew, "Launching works once the experience is published.")
		return
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData(launchData)
		TeleportService:TeleportAsync(Places.MISSION, crew, options)
	end)
	if not ok then
		warn("Launch teleport failed:", err)
		notice(crew, "The Dropcan failed to launch. Try again.")
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, pad in pads do
		-- Keep members in arrival order; drop anyone who stepped off.
		local present = {}
		for _, member in pad.members do
			if member.Parent == Players and onPad(pad, member) then
				table.insert(present, member)
			end
		end
		for _, player in Players:GetPlayers() do
			if not table.find(present, player) and #present < Missions.MAX_PARTY and onPad(pad, player) then
				local elsewhere = false
				for _, other in pads do
					if other ~= pad and table.find(other.members, player) then
						elsewhere = true
					end
				end
				if not elsewhere then
					table.insert(present, player)
				end
			end
		end
		pad.members = present
		local leader = present[1]
		if leader ~= pad.leader then
			pad.leader = leader
			reset(pad)
		end
		if pad.launchAt and now >= pad.launchAt then
			launch(pad)
		end
		publish(pad)
	end
end

function LaunchPads.start(built: Deck.Built)
	local folder = Instance.new("Folder")
	folder.Name = "LaunchPads"
	folder.Parent = ReplicatedStorage
	for index, bay in built.pads do
		local state = Instance.new("Configuration")
		state.Name = `Pad{index}`
		state.Parent = folder
		local pad: Pad = {
			index = index,
			center = bay.center,
			board = bay.board,
			dropcan = bay.dropcan,
			members = {},
			leader = nil,
			missionType = nil,
			seed = nil,
			launchAt = nil,
			state = state,
		}
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Choose mission"
		prompt.ObjectText = "Mission board"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "MissionBoard")
		prompt:SetAttribute("Pad", index)
		prompt.Parent = bay.board
		table.insert(pads, pad)
	end
	Net.func("ChooseMission").OnServerInvoke = function(player, missionType, seed)
		if not Missions.isMissionType(missionType) then
			return false, "Unknown mission"
		end
		if
			seed ~= nil
			and (type(seed) ~= "number" or seed ~= math.floor(seed) or seed < 1 or seed > LaunchData.MAX_SEED)
		then
			return false, "Seeds are whole numbers from 1 to " .. LaunchData.MAX_SEED
		end
		for _, pad in pads do
			if pad.leader == player then
				pad.missionType = missionType
				pad.seed = seed
				pad.launchAt = Workspace:GetServerTimeNow() + COUNTDOWN
				publish(pad)
				return true, nil
			elseif pad.leader and table.find(pad.members, player) then
				return false, `{pad.leader.DisplayName} leads this pad and picks the mission.`
			end
		end
		return false, "Stand on a launch pad first. The first one aboard picks the mission."
	end
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= 0.25 then
			accumulated = 0
			step()
		end
	end)
end

return LaunchPads
