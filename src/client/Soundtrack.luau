--!strict
-- The mission's soundscape: the cave ambience and distant hive chitter throughout, combat music
-- that fades in while Vrill are close and out once they are gone, and stingers for the swarm
-- warning, the objective, the Lift Pod and its launch countdown.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.Audio)
local MissionState = require(Shared.MissionState)
local Sounds = require(script.Parent.Sounds)

local Soundtrack = {}

local KEYS = MissionState.KEYS
local player = Players.LocalPlayer
local rng = Random.new()

local function listener(): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else Workspace.CurrentCamera.CFrame.Position
end

local function fade(sound: Sound, volume: number)
	TweenService:Create(sound, TweenInfo.new(AudioConfig.COMBAT_FADE), { Volume = volume }):Play()
end

local function ambience()
	for _, name in { "CaveBed", "CaveDrips" } do
		local loop = Sounds.loop(name)
		if loop then
			loop:Play()
		end
	end
	-- Hive chitter somewhere out in the dark now and then.
	task.spawn(function()
		while MissionState.get(KEYS.Phase) ~= "Ended" do
			local band = AudioConfig.CHITTER_INTERVAL
			task.wait(rng:NextNumber(band[1], band[2]))
			local at = listener()
			if at then
				local away = rng:NextUnitVector() * rng:NextNumber(35, 70)
				Sounds.play(
					if rng:NextNumber() < 0.5 then "HiveChitter" else "HiveChitterLong",
					at + Vector3.new(away.X, away.Y * 0.3, away.Z)
				)
			end
		end
	end)
end

local function vrillNearby(): number
	local at = listener()
	if not at then
		return 0
	end
	local count = 0
	for _, enemy in CollectionService:GetTagged("Enemy") do
		local body = if enemy:IsA("Model") then enemy.PrimaryPart else nil
		if body and (body.Position - at).Magnitude <= AudioConfig.COMBAT_NEAR then
			count += 1
		end
	end
	return count
end

local function combatMusic()
	local music = Sounds.loop("CombatMusic")
	if not music then
		return
	end
	local full = music.Volume
	music.Volume = 0
	local playing = false
	local quietSince = 0
	local swarmAt = 0
	MissionState.observe(KEYS.Swarm, function(value)
		if type(value) == "number" then
			swarmAt = os.clock()
		end
	end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.5 then
			return
		end
		accumulated = 0
		local ended = MissionState.get(KEYS.Phase) == "Ended"
		local fighting = not ended
			and (vrillNearby() >= AudioConfig.COMBAT_COUNT or os.clock() - swarmAt < AudioConfig.COMBAT_LINGER)
		if fighting then
			quietSince = os.clock()
			if not playing then
				playing = true
				if not music.IsPlaying then
					music:Play()
				end
				fade(music, full)
			end
		elseif playing and (ended or os.clock() - quietSince >= AudioConfig.COMBAT_LINGER) then
			playing = false
			fade(music, 0)
		end
	end)
end

local function stingers()
	-- The swarm warning, but not for the value already set when we joined.
	local lastSwarm = MissionState.get(KEYS.Swarm)
	MissionState.observe(KEYS.Swarm, function(value)
		if type(value) == "number" and value ~= lastSwarm then
			lastSwarm = value
			Sounds.play("SwarmStinger")
		end
	end)

	-- The objective: the Volticite quota met, or the Refinery's pumping finished.
	local objectiveDone = false
	local function objective()
		if objectiveDone then
			return
		end
		local deposited, target = MissionState.get(KEYS.Deposited), MissionState.get(KEYS.Target)
		local mined = MissionState.get(KEYS.MissionType) == "Mining"
			and type(deposited) == "number"
			and type(target) == "number"
			and target > 0
			and deposited >= target
		local refined = MissionState.get(KEYS.RefineryStage) == "Launching"
		if mined or refined then
			objectiveDone = true
			Sounds.play("ObjectiveStinger")
		end
	end
	MissionState.observe(KEYS.Deposited, objective)
	MissionState.observe(KEYS.RefineryStage, objective)

	-- The Lift Pod, a moment after the objective's stinger when both come at once.
	local liftCalled = MissionState.get(KEYS.LiftLandsAt) ~= nil
	MissionState.observe(KEYS.LiftLandsAt, function(value)
		if value and not liftCalled then
			liftCalled = true
			task.delay(2.5, Sounds.play, "LiftPodStinger")
		end
	end)

	-- A beep each second of the last ten before launch, then the launch itself.
	task.spawn(function()
		local lastBeep = -1
		while true do
			task.wait(0.1)
			local launchAt = MissionState.get(KEYS.LiftLaunchAt)
			if type(launchAt) == "number" then
				local remaining = math.ceil(launchAt - Workspace:GetServerTimeNow())
				if remaining <= 10 and remaining >= 1 and remaining ~= lastBeep then
					lastBeep = remaining
					Sounds.play("CountdownBeep", nil, if remaining <= 3 then 1.4 else 1)
				elseif remaining <= 0 then
					Sounds.play("LiftOff")
					return
				end
			end
		end
	end)
end

function Soundtrack.start()
	ambience()
	combatMusic()
	stingers()
end

return Soundtrack
