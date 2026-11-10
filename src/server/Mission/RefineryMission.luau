--!strict
-- The Refinery objective: call the Refinery down at its site, walk pipelines back from three
-- slurry wells, defend the pipes through three minutes of pumping, then launch the rocket.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Cave.Layout)
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)

local Server = script.Parent.Parent
local Digging = require(Server.Cave.Digging)
local Surface = require(Server.Cave.Surface)
local Vitals = require(Server.Character.Vitals)
local Damage = require(Server.Combat.Damage)
local Explosions = require(Server.Combat.Explosions)
local Hive = require(Server.Enemies.Hive)
local Spawner = require(Server.Enemies.Spawner)
local RefineryModels = require(Server.Models.Refinery)
local Extraction = require(script.Parent.Extraction)
local Flow = require(script.Parent.Flow)
local Runtime = require(script.Parent.Runtime)

local RefineryMission = {}

local KEYS = MissionState.KEYS
local NODE_SPACING = 8
local CONNECT_DISTANCE = 12
local PIPE_HEALTH = 150
local DROP_SECONDS = 6
local SWARM_EVERY = 40

type Pipeline = {
	index: number,
	model: Model,
	valve: BasePart,
	nodes: { Vector3 },
	segments: { BasePart },
	layer: Player?,
	connected: boolean,
	resume: BasePart?,
}

local pipelines: { Pipeline } = {}
local folder: Folder
local refinery: RefineryModels.Refinery? = nil
local brokenCount = 0

local function setStage(stage: string)
	MissionState.set(KEYS.RefineryStage, stage)
end

local function prompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local created = Instance.new("ProximityPrompt")
	created.ActionText = action
	created.ObjectText = object
	created.HoldDuration = hold
	created.MaxActivationDistance = 9
	created.RequiresLineOfSight = false
	created.Parent = parent
	return created
end

local function mark(instance: Instance, label: string, color: Color3)
	instance:SetAttribute("MarkerLabel", label)
	instance:SetAttribute("MarkerColor", color)
	CollectionService:AddTag(instance, "Marker")
end

local function unmark(instance: Instance)
	CollectionService:RemoveTag(instance, "Marker")
end

-- The largest cavern near the middle of the cave, other than the landing cavern, hosts the Refinery.
local function chooseSite(layout: Layout.CaveLayout): (Layout.Cavern, Vector3)
	local centroid = Vector3.zero
	for _, cavern in layout.caverns do
		centroid += cavern.center
	end
	centroid /= #layout.caverns
	local best, bestScore = layout.caverns[1], -math.huge
	for index, cavern in layout.caverns do
		local score = math.min(cavern.radii.X, cavern.radii.Z) * 2 - (cavern.center - centroid).Magnitude * 0.25
		if index ~= layout.startCavern and score > bestScore then
			best, bestScore = cavern, score
		end
	end
	local floor = Surface.floorBelow(Surface.cavernOrigin(best), best.radii.Y * 2)
		or Vector3.new(best.center.X, best.floorY, best.center.Z)
	return best, floor
end

local function updateScreen()
	if not refinery then
		return
	end
	local stage = MissionState.get(KEYS.RefineryStage)
	if stage == "Pumping" then
		refinery.screen.Text =
			string.format("PUMPING\n%d%%", math.floor((MissionState.get(KEYS.PumpProgress) or 0) * 100))
	elseif stage == "Pipes" then
		refinery.screen.Text = `WELLS\n{MissionState.get(KEYS.WellsConnected) or 0} / {Missions.REFINERY_WELLS}`
	else
		refinery.screen.Text = "READY"
	end
end

------------------------------------------------------------------------------------------------
-- Pipes

local function setBroken(segment: BasePart, broken: boolean)
	if (segment:GetAttribute("Broken") == true) == broken then
		return
	end
	segment:SetAttribute("Broken", broken)
	brokenCount += if broken then 1 else -1
	MissionState.set(KEYS.PipesBroken, brokenCount)
	segment.Color = if broken then Color3.fromRGB(200, 60, 50) else Color3.fromRGB(120, 118, 132)
	local repair = segment:FindFirstChild("RepairPrompt") :: ProximityPrompt?
	if repair then
		repair.Enabled = broken
	end
	if broken then
		mark(segment, "Broken pipe", Color3.fromRGB(255, 92, 72))
	else
		unmark(segment)
		segment:SetAttribute("Health", PIPE_HEALTH)
	end
end

local function addSegment(pipeline: Pipeline, from: Vector3, to: Vector3)
	local floor = Surface.floorBelow(from + Vector3.yAxis, 12)
	local segment = RefineryModels.pipe(folder, from, to, if floor then floor.Y else nil)
	segment:SetAttribute("Health", PIPE_HEALTH)
	CollectionService:AddTag(segment, "Pipe")
	local repair = prompt(segment, "Repair pipe", `Well {pipeline.index}`, 2)
	repair.Name = "RepairPrompt"
	repair.Enabled = false
	repair.Triggered:Connect(function(player)
		if Vitals.isAlive(player) then
			setBroken(segment, false)
		end
	end)
	table.insert(pipeline.segments, segment)
end

local function clearResume(pipeline: Pipeline)
	if pipeline.resume then
		pipeline.resume:Destroy()
		pipeline.resume = nil
	end
end

local function beginLaying(pipeline: Pipeline, player: Player)
	if pipeline.connected or pipeline.layer or not Vitals.isAlive(player) or player:GetAttribute("LayingPipe") then
		return
	end
	if MissionState.get(KEYS.RefineryStage) ~= "Pipes" then
		return
	end
	clearResume(pipeline)
	pipeline.layer = player
	player:SetAttribute("LayingPipe", pipeline.index)
end

-- The laying player went down or left: leave a marker where anyone can pick the pipe back up.
local function pause(pipeline: Pipeline)
	local layer = pipeline.layer
	if layer then
		layer:SetAttribute("LayingPipe", nil)
	end
	pipeline.layer = nil
	local last = pipeline.nodes[#pipeline.nodes]
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = last
	holder.Parent = folder
	mark(holder, `Pipe end (well {pipeline.index})`, Color3.fromRGB(176, 96, 255))
	prompt(holder, "Continue pipeline", `Well {pipeline.index}`, 0.5).Triggered:Connect(function(player)
		beginLaying(pipeline, player)
	end)
	pipeline.resume = holder
end

local function stepLaying(pipeline: Pipeline)
	local layer = pipeline.layer :: Player
	local root = layer.Character and layer.Character.PrimaryPart
	if not root or not Vitals.isAlive(layer) or layer.Parent == nil then
		pause(pipeline)
		return
	end
	local head = root.Position + Vector3.yAxis * 0.5
	local last = pipeline.nodes[#pipeline.nodes]
	local current = refinery :: RefineryModels.Refinery
	if (head - current.inlet).Magnitude <= CONNECT_DISTANCE then
		addSegment(pipeline, last, current.inlet)
		pipeline.connected = true
		pipeline.layer = nil
		layer:SetAttribute("LayingPipe", nil)
		unmark(pipeline.model)
		MissionState.set(KEYS.WellsConnected, (MissionState.get(KEYS.WellsConnected) or 0) + 1)
		return
	end
	if (head - last).Magnitude >= NODE_SPACING then
		addSegment(pipeline, last, head)
		table.insert(pipeline.nodes, head)
	end
end

------------------------------------------------------------------------------------------------
-- Stages

local function launch()
	setStage("Launching")
	local current = refinery :: RefineryModels.Refinery
	local rocket = current.rocket
	local exhaust = rocket:FindFirstChild("Engine")
		and (rocket:FindFirstChild("Engine") :: BasePart):FindFirstChild("Exhaust")
	if exhaust then
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 180, 90), Color3.fromRGB(255, 80, 40))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new(3, 7)
		fire.Lifetime = NumberRange.new(0.6, 1)
		fire.Speed = NumberRange.new(30, 40)
		fire.EmissionDirection = Enum.NormalId.Bottom
		fire.Rate = 120
		fire.Parent = exhaust
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 60
		light.Brightness = 4
		light.Parent = exhaust
	end
	-- Blast a hole straight up so the rocket has somewhere to go.
	local top = rocket:GetPivot().Position
	Digging.capsule(top, top + Vector3.yAxis * 200, 5)
	local driver = Instance.new("CFrameValue")
	driver.Value = rocket:GetPivot()
	driver.Changed:Connect(function(value)
		rocket:PivotTo(value)
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Value = rocket:GetPivot() + Vector3.yAxis * 220,
	})
	tween.Completed:Once(function()
		rocket:Destroy()
		driver:Destroy()
		setStage("Done")
		Extraction.call(nil)
	end)
	tween:Play()
end

local function pump()
	setStage("Pumping")
	MissionState.set(KEYS.PumpProgress, 0)
	Spawner.swarm(0.8)
	local progress = 0
	local sinceSwarm = 0
	-- Studio-only test hook: automated playtests shorten pumping through this attribute.
	local override = Workspace:GetAttribute("DevPumpSeconds")
	local pumpSeconds = if RunService:IsStudio() and type(override) == "number"
		then override
		else Missions.REFINERY_PUMP_SECONDS
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if Flow.isOver() then
			connection:Disconnect()
			return
		end
		sinceSwarm += dt
		if sinceSwarm >= SWARM_EVERY then
			sinceSwarm = 0
			Spawner.swarm(0.6)
		end
		if brokenCount == 0 then
			progress += dt / pumpSeconds
		end
		local shown = math.floor(progress * 100)
		if shown ~= math.floor((MissionState.get(KEYS.PumpProgress) or 0) * 100) then
			MissionState.set(KEYS.PumpProgress, math.min(1, shown / 100))
			updateScreen()
		end
		if progress >= 1 then
			connection:Disconnect()
			launch()
		end
	end)
end

local function callRefinery(site: Vector3)
	setStage("Dropping")
	Digging.capsule(site + Vector3.yAxis * 10, site + Vector3.yAxis * 80, 9)
	Digging.sphere(site + Vector3.yAxis * 8, 13)
	local built = RefineryModels.refinery(CFrame.new(site))
	refinery = built
	local landed = built.model:GetPivot()
	built.model:PivotTo(landed + Vector3.yAxis * 80)
	built.model.Parent = Workspace
	mark(built.model, "Refinery", Color3.fromRGB(176, 96, 255))
	local driver = Instance.new("CFrameValue")
	driver.Value = built.model:GetPivot()
	driver.Changed:Connect(function(value)
		built.model:PivotTo(value)
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(DROP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = landed }
	)
	tween.Completed:Once(function()
		driver:Destroy()
		Explosions.detonate({ position = site + Vector3.yAxis, radius = 14, damage = 800, style = "Blast" })
		-- Pipes are laid relative to where the Refinery actually stands.
		built.inlet = (built.model:FindFirstChild("Inlet") :: BasePart).Position
		setStage("Pipes")
		MissionState.set(KEYS.WellsConnected, 0)
		for _, pipeline in pipelines do
			mark(pipeline.model, `Well {pipeline.index}`, Color3.fromRGB(176, 96, 255))
		end
		updateScreen()
	end)
	tween:Play()
end

local function placeWells(layout: Layout.CaveLayout, siteCavern: Layout.Cavern, site: Vector3)
	-- The three caverns furthest from the site.
	local ranked = {}
	for _, cavern in layout.caverns do
		if cavern ~= siteCavern then
			table.insert(ranked, cavern)
		end
	end
	table.sort(ranked, function(a, b)
		return (a.center - site).Magnitude > (b.center - site).Magnitude
	end)
	for index = 1, math.min(Missions.REFINERY_WELLS, #ranked) do
		local cavern = ranked[index]
		local floor = Surface.floorBelow(Surface.cavernOrigin(cavern), cavern.radii.Y * 2)
			or Vector3.new(cavern.center.X, cavern.floorY, cavern.center.Z)
		Digging.sphere(floor + Vector3.yAxis * 4, 5)
		local model, valve = RefineryModels.well(CFrame.new(floor), `Well {index}`)
		model.Parent = folder
		local pipeline: Pipeline = {
			index = index,
			model = model,
			valve = valve,
			nodes = { valve.Position + Vector3.yAxis * 1.2 },
			segments = {},
			layer = nil,
			connected = false,
			resume = nil,
		}
		local start = prompt(valve, "Start pipeline", `Well {index}`, 0.5)
		-- Reachable from anywhere around the crust ring.
		start.MaxActivationDistance = 12
		start.Triggered:Connect(function(player)
			beginLaying(pipeline, player)
		end)
		table.insert(pipelines, pipeline)
	end
end

function RefineryMission.start()
	local world = Runtime.get()
	folder = Instance.new("Folder")
	folder.Name = "RefineryWorks"
	folder.Parent = Workspace

	local siteCavern, site = chooseSite(world.layout)
	placeWells(world.layout, siteCavern, site)

	-- The landing beacon marks the site until someone calls the Refinery down.
	local beacon = Instance.new("Part")
	beacon.Name = "RefinerySite"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(0.3, 18, 18)
	beacon.CFrame = CFrame.new(site + Vector3.yAxis * 0.2) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(176, 96, 255)
	beacon.Transparency = 0.6
	beacon.Parent = folder
	mark(beacon, "Refinery site", Color3.fromRGB(176, 96, 255))
	-- A standing pole carries the prompt at chest height; prompts only show while on screen,
	-- and the flat ring is underfoot.
	local pole = Instance.new("Part")
	pole.Name = "SitePole"
	pole.Anchored = true
	pole.CanCollide = false
	pole.Size = Vector3.new(0.6, 6, 0.6)
	pole.Position = site + Vector3.yAxis * 3
	pole.Material = Enum.Material.Neon
	pole.Color = Color3.fromRGB(176, 96, 255)
	pole.Parent = beacon
	prompt(pole, "Call down the Refinery", "Refinery site", 1.5).Triggered:Connect(function(player)
		if Vitals.isAlive(player) and MissionState.get(KEYS.RefineryStage) == "Site" then
			beacon:Destroy()
			callRefinery(site)
		end
	end)
	setStage("Site")

	Damage.register("Pipe", function(target, info)
		local segment = target :: BasePart
		if segment:GetAttribute("Broken") or MissionState.get(KEYS.RefineryStage) ~= "Pumping" then
			return
		end
		-- Only the Vrill break pipes.
		if info.attacker then
			return
		end
		local health = (segment:GetAttribute("Health") or PIPE_HEALTH) - info.amount
		segment:SetAttribute("Health", health)
		if health <= 0 then
			setBroken(segment, true)
		end
	end)
	Hive.setStructureTargets(function()
		if MissionState.get(KEYS.RefineryStage) ~= "Pumping" then
			return {}
		end
		local intact = {}
		for _, pipeline in pipelines do
			for _, segment in pipeline.segments do
				if not segment:GetAttribute("Broken") then
					table.insert(intact, segment)
				end
			end
		end
		return intact
	end)

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.2 then
			return
		end
		accumulated = 0
		for _, pipeline in pipelines do
			if pipeline.layer then
				stepLaying(pipeline)
			end
		end
	end)
	MissionState.observe(KEYS.WellsConnected, function(connected)
		updateScreen()
		if connected == Missions.REFINERY_WELLS and MissionState.get(KEYS.RefineryStage) == "Pipes" then
			task.delay(4, pump)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, pipeline in pipelines do
			if pipeline.layer == player then
				pause(pipeline)
			end
		end
	end)
end

return RefineryMission
