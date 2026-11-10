--!strict
-- Decides when and where Vrill appear: ambient groups placed at generation, timed swarms,
-- and swarms requested by objectives. Spawns beyond the live cap wait in a queue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EnemiesConfig = require(Shared.Config.Enemies)
local MissionState = require(Shared.MissionState)

local Server = script.Parent.Parent
local Surface = require(Server.Cave.Surface)
local Vitals = require(Server.Character.Vitals)
local Runtime = require(Server.Mission.Runtime)
local Hive = require(script.Parent.Hive)

local Spawner = {}

local queue: { EnemiesConfig.EnemyType } = {}
local countScale = 1
local nextSwarm = math.huge
local rng = Random.new()
local paused = false

local function crewPositions(): { Vector3 }
	local positions = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root and Vitals.isAlive(player) then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function drainQueue()
	local crew = crewPositions()
	if #crew == 0 then
		return
	end
	while #queue > 0 and Hive.count() < EnemiesConfig.MAX_ALIVE do
		local enemyType = queue[1]
		local around = crew[rng:NextInteger(1, #crew)]
		local stats = EnemiesConfig.STATS[enemyType]
		local point = Hive.emergePoint(around, stats.flying)
		if not point then
			return
		end
		table.remove(queue, 1)
		Hive.spawn(enemyType, point, { awake = true, emerge = true })
	end
end

-- Queues a swarm. `size` scales the base swarm (1 = a normal timed swarm).
function Spawner.swarm(size: number)
	local makeup = table.clone(EnemiesConfig.SWARM)
	for enemyType, base in makeup do
		for _ = 1, math.max(0, math.floor(base * size * countScale + 0.5)) do
			table.insert(queue, enemyType)
		end
	end
	if rng:NextNumber() < EnemiesConfig.RAVAGER_SWARM_CHANCE * size then
		table.insert(queue, "Ravager")
	end
	-- Shuffle so types arrive mixed.
	for index = #queue, 2, -1 do
		local other = rng:NextInteger(1, index)
		queue[index], queue[other] = queue[other], queue[index]
	end
	MissionState.set(MissionState.KEYS.Swarm, Workspace:GetServerTimeNow())
end

-- Queues exactly these Vrill as a swarm (the walkthrough's small practice swarm).
function Spawner.group(makeup: { [EnemiesConfig.EnemyType]: number })
	for enemyType, count in makeup do
		for _ = 1, count do
			table.insert(queue, enemyType)
		end
	end
	MissionState.set(MissionState.KEYS.Swarm, Workspace:GetServerTimeNow())
end

-- Vrill queued but not yet spawned.
function Spawner.pending(): number
	return #queue
end

local function scheduleSwarm()
	local band = EnemiesConfig.SWARM_INTERVAL
	nextSwarm = os.clock() + rng:NextNumber(band[1], band[2])
end

-- Places sleeping groups and Spitters in every cavern except the landing one.
local function placeAmbient()
	local world = Runtime.get()
	local placement = Random.new(world.launch.seed * 13 + 5)
	for index, cavern in world.layout.caverns do
		if index ~= world.layout.startCavern then
			local groups = EnemiesConfig.AMBIENT_PER_CAVERN
			for _ = 1, placement:NextInteger(groups[1], groups[2]) do
				local floor = Surface.scatter(placement, cavern, 1, { Floor = true })[1]
				if floor then
					local enemyType: EnemiesConfig.EnemyType = if placement:NextNumber() < 0.65
						then "Drone"
						else "Warrior"
					for _ = 1, placement:NextInteger(2, 3) do
						local jitter = Vector3.new(placement:NextNumber(-4, 4), 0, placement:NextNumber(-4, 4))
						Hive.spawn(enemyType, floor.position + jitter, { awake = false })
					end
				end
			end
			local spitters = EnemiesConfig.SPITTERS_PER_CAVERN
			for _ = 1, placement:NextInteger(spitters[1], spitters[2]) do
				local floor = Surface.scatter(placement, cavern, 1, { Floor = true })[1]
				if floor then
					Hive.spawn("Spitter", floor.position, { awake = false })
				end
			end
		end
	end
end

-- Stops timed swarms (mission over).
function Spawner.stop()
	paused = true
	table.clear(queue)
end

-- Starts spawning. A scripted run (the walkthrough) has no sleeping Vrill and no timed swarms;
-- only the swarms it asks for.
function Spawner.start(scripted: boolean)
	local partySize = Runtime.get().launch.partySize
	countScale = EnemiesConfig.COUNT_SCALE[partySize]
	Hive.setHealthScale(EnemiesConfig.HEALTH_SCALE[partySize])
	if not scripted then
		placeAmbient()
		scheduleSwarm()
	end
	-- Studio-only test hook: automated playtests call a swarm of a given size through this attribute.
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("DevSwarm"):Connect(function()
			local size = Workspace:GetAttribute("DevSwarm")
			if type(size) == "number" and size > 0 then
				Spawner.swarm(size)
			end
		end)
	end
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.5 or paused then
			return
		end
		accumulated = 0
		if os.clock() >= nextSwarm then
			scheduleSwarm()
			Spawner.swarm(1)
		end
		drainQueue()
	end)
end

return Spawner
