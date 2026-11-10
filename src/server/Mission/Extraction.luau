--!strict
-- The Lift Pod: called when the objective is done, it drills down in a cavern far from the crew,
-- brings a swarm with it, and launches after a countdown with whoever stands on its deck.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)

local Server = script.Parent.Parent
local Digging = require(Server.Cave.Digging)
local Surface = require(Server.Cave.Surface)
local Vitals = require(Server.Character.Vitals)
local Explosions = require(Server.Combat.Explosions)
local Spawner = require(Server.Enemies.Spawner)
local LiftPod = require(Server.Models.LiftPod)
local Flow = require(script.Parent.Flow)
local Runtime = require(script.Parent.Runtime)

local Extraction = {}

local KEYS = MissionState.KEYS
local DESCENT_SECONDS = 10
local DROP_HEIGHT = 70

local called = false

local function crewCentroid(): Vector3?
	local sum, count = Vector3.zero, 0
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			sum += root.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

-- The cavern floor furthest from the crew, so reaching the pod is the final push.
local function chooseLandingSite(): Vector3
	local world = Runtime.get()
	local from = crewCentroid() or world.landing
	local best, bestDistance = world.landing, -1
	for _, cavern in world.layout.caverns do
		local floor = Surface.floorBelow(Surface.cavernOrigin(cavern), cavern.radii.Y * 2)
		if floor then
			local distance = (floor - from).Magnitude
			if distance > bestDistance then
				best, bestDistance = floor, distance
			end
		end
	end
	return best
end

local function aboard(deck: BasePart): { [Player]: boolean }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root and Vitals.isAlive(player) then
			local offset = root.Position - deck.Position
			if
				Vector2.new(offset.X, offset.Z).Magnitude <= LiftPod.DECK_RADIUS + 0.5
				and offset.Y > -1
				and offset.Y < 8
			then
				list[player] = true
			end
		end
	end
	return list
end

local function countdown(model: Model, deck: BasePart)
	local launchAt = os.clock() + Missions.LIFT_POD_COUNTDOWN
	MissionState.set(KEYS.LiftLaunchAt, Workspace:GetServerTimeNow() + Missions.LIFT_POD_COUNTDOWN)
	Spawner.swarm(1.2)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if Flow.isOver() then
			connection:Disconnect()
			return
		end
		local riders = aboard(deck)
		local count = 0
		for _ in riders do
			count += 1
		end
		if MissionState.get(KEYS.Aboard) ~= count then
			MissionState.set(KEYS.Aboard, count)
		end
		if os.clock() >= launchAt then
			connection:Disconnect()
			Spawner.stop()
			if count > 0 then
				Flow.succeed(riders)
			else
				Flow.fail("Nobody made it onto the Lift Pod")
			end
			-- Lift off with whoever is aboard.
			local driver = Instance.new("CFrameValue")
			driver.Value = model:GetPivot()
			driver.Changed:Connect(function(value)
				model:PivotTo(value)
			end)
			TweenService:Create(driver, TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Value = model:GetPivot() + Vector3.yAxis * DROP_HEIGHT,
			}):Play()
		end
	end)
end

-- Calls the Lift Pod. Safe to call more than once; only the first call counts.
function Extraction.call()
	if called or Flow.isOver() then
		return
	end
	called = true
	MissionState.set(KEYS.Phase, "Extraction")
	local site = chooseLandingSite()
	MissionState.set(KEYS.LiftLandsAt, Workspace:GetServerTimeNow() + DESCENT_SECONDS)
	Digging.capsule(site + Vector3.yAxis * 10, site + Vector3.yAxis * DROP_HEIGHT, LiftPod.DECK_RADIUS + 2)
	-- Clear standing room around the deck too.
	Digging.sphere(site + Vector3.yAxis * 6, LiftPod.DECK_RADIUS + 3)
	local model, deck = LiftPod.build(CFrame.new(site))
	local landed = model:GetPivot()
	model:PivotTo(landed + Vector3.yAxis * DROP_HEIGHT)
	model:SetAttribute("MarkerLabel", "Lift Pod")
	model:SetAttribute("MarkerColor", Color3.fromRGB(120, 255, 150))
	model.Parent = Workspace
	CollectionService:AddTag(model, "Marker")
	local driver = Instance.new("CFrameValue")
	driver.Value = model:GetPivot()
	driver.Changed:Connect(function(value)
		model:PivotTo(value)
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(DESCENT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = landed }
	)
	tween.Completed:Once(function()
		driver:Destroy()
		Explosions.detonate({ position = site + Vector3.yAxis, radius = 9, damage = 600, style = "Blast" })
		countdown(model, deck)
	end)
	tween:Play()
end

return Extraction
