--!strict
-- Every live Vrill: spawning (emerging from burrows), thinking, moving, attacking, taking damage
-- and dying. AI decisions run at a fixed rate; Humanoid physics handles walking between them.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EnemiesConfig = require(Shared.Config.Enemies)
local Net = require(Shared.Net)

local Server = script.Parent.Parent
local Damage = require(Server.Combat.Damage)
local Projectiles = require(Server.Combat.Projectiles)
local Surface = require(Server.Cave.Surface)
local Vitals = require(Server.Character.Vitals)
local Vrill = require(Server.Models.Vrill)

local Hive = {}

local THINK_INTERVAL = 0.1
local PATH_INTERVAL = 1.4
local STUCK_SECONDS = 4
local DIRECT_CHASE_RANGE = 30
local FREEZE_DAMAGE_BONUS = 1.5

export type Enemy = {
	model: Model,
	type: EnemiesConfig.EnemyType,
	stats: EnemiesConfig.Stats,
	humanoid: Humanoid,
	root: BasePart,
	health: number,
	maxHealth: number,
	awake: boolean,
	dead: boolean,
	target: Player?,
	nextAttack: number,
	nextPath: number,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathing: boolean,
	stuckSince: number,
	stuckFrom: Vector3,
	charging: number,
	chargeHit: boolean,
	slow: number,
	burn: number,
	burnUntil: number,
	frozenUntil: number,
	stunnedUntil: number,
	burrowing: boolean,
	lastAttacker: Player?,
	hover: AlignPosition?,
}

local folder: Folder
local enemies: { [Model]: Enemy } = {}
local alive = 0
local healthScale = 1
local decoy: { position: Vector3, untilTime: number }? = nil
local deathListeners: { (Enemy) -> () } = {}

local function aliveCrew(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Vitals.isAlive(player) and player.Character and player.Character.PrimaryPart then
			table.insert(list, player)
		end
	end
	return list
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

local function nearestCrew(position: Vector3): (Player?, number)
	local best, bestDistance = nil, math.huge
	for _, player in aliveCrew() do
		local root = rootOf(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include

local function lineOfSight(from: Vector3, to: Vector3): boolean
	terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(from, to - from, terrainOnly) == nil
end

-- A burrow point on the cave surface some distance from `around`, with floor beneath for walkers.
function Hive.emergePoint(around: Vector3, flying: boolean?): Vector3?
	local band = EnemiesConfig.EMERGE_DISTANCE
	local rng = Random.new()
	for _ = 1, 16 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.35, 0.25), rng:NextNumber(-1, 1)).Unit
		local hit = Surface.raycast(around + Vector3.yAxis * 2, direction * band[2])
		if hit and (hit.position - around).Magnitude >= band[1] then
			local out = hit.position + hit.normal * 3
			if flying then
				return out
			end
			local floor = Surface.floorBelow(out + Vector3.yAxis * 2, 30)
			if floor and lineOfSight(floor + Vector3.yAxis * 3, around + Vector3.yAxis * 2) then
				return floor + Vector3.yAxis * 0.5
			end
		end
	end
	return nil
end

local function setSpeed(enemy: Enemy, now: number)
	local speed = enemy.stats.speed
	if enemy.charging > now then
		speed = enemy.stats.chargeSpeed or speed
	end
	if enemy.frozenUntil > now or enemy.stunnedUntil > now or enemy.burrowing then
		speed = 0
	end
	enemy.humanoid.WalkSpeed = speed * math.max(0.35, 1 - enemy.slow)
	enemy.model:SetAttribute("Frozen", enemy.frozenUntil > now)
	enemy.model:SetAttribute("Burning", enemy.burnUntil > now)
end

local function die(enemy: Enemy)
	if enemy.dead then
		return
	end
	enemy.dead = true
	alive -= 1
	enemies[enemy.model] = nil
	CollectionService:RemoveTag(enemy.model, "Enemy")
	if enemy.lastAttacker then
		enemy.lastAttacker:SetAttribute("Kills", (enemy.lastAttacker:GetAttribute("Kills") or 0) + 1)
	end
	for _, listener in deathListeners do
		task.spawn(listener, enemy)
	end
	Net.unreliable("EnemyDied"):FireAllClients(enemy.root.Position, enemy.stats.size)
	enemy.model:Destroy()
end

local function onDamage(target: Instance, info: Damage.Info)
	local enemy = enemies[target :: Model]
	if not enemy or enemy.dead or enemy.burrowing then
		return
	end
	local amount = info.amount
	local part = info.part
	if part and part:GetAttribute("Weakspot") then
		amount *= (info.weakspotMultiplier or 1) * enemy.stats.weakspotBonus
	elseif part and part:GetAttribute("Armor") and not info.piercesArmor then
		amount *= enemy.stats.armorFactor
	end
	local now = os.clock()
	if enemy.frozenUntil > now and info.kind ~= "Cold" then
		amount *= FREEZE_DAMAGE_BONUS
	end
	if info.slow then
		enemy.slow = math.min(0.65, enemy.slow + info.slow)
	end
	if info.burn then
		enemy.burn = math.max(enemy.burn, info.burn)
		enemy.burnUntil = now + 4
	end
	if info.freeze then
		enemy.frozenUntil = now + info.freeze
	end
	if info.stun then
		enemy.stunnedUntil = now + info.stun
	end
	if info.attacker then
		enemy.lastAttacker = info.attacker
	end
	enemy.awake = true
	enemy.health -= amount
	if enemy.health <= 0 then
		die(enemy)
	end
end

local function meleeAttack(enemy: Enemy, player: Player)
	Vitals.damage(player, enemy.stats.damage)
	Net.unreliable("EnemyAttack"):FireAllClients(enemy.model, "Melee")
end

local function spit(enemy: Enemy, targetRoot: BasePart)
	local muzzle = enemy.model:FindFirstChild("Mouth") or enemy.model:FindFirstChild("Tail") or enemy.root
	local origin = (muzzle :: BasePart).Position
	local speed = 70
	local gravity = 30
	-- Lead the target a little and loft the shot against gravity.
	local aimAt = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.3
	local flat = aimAt - origin
	local time = flat.Magnitude / speed
	local velocity = flat / time + Vector3.yAxis * gravity * time * 0.5
	Projectiles.launch({
		origin = origin,
		velocity = velocity,
		gravity = gravity,
		lifetime = 4,
		ignore = { folder, Workspace:FindFirstChild("Effects") or folder },
		style = "Acid",
		onImpact = function(position)
			for _, other in aliveCrew() do
				local root = rootOf(other)
				if root and (root.Position - position).Magnitude <= 4 then
					Vitals.damage(other, enemy.stats.damage)
				end
			end
		end,
	})
	Net.unreliable("EnemyAttack"):FireAllClients(enemy.model, "Spit")
end

local function burrowTo(enemy: Enemy, around: Vector3)
	if enemy.burrowing then
		return
	end
	local destination = Hive.emergePoint(around, enemy.stats.flying)
	if not destination then
		return
	end
	enemy.burrowing = true
	Net.unreliable("Burrow"):FireAllClients(enemy.root.Position)
	enemy.model.Parent = nil
	task.delay(1.6, function()
		if enemy.dead then
			return
		end
		Net.unreliable("Burrow"):FireAllClients(destination)
		task.wait(EnemiesConfig.EMERGE_SECONDS * 0.4)
		if enemy.dead then
			return
		end
		enemy.model:PivotTo(
			CFrame.new(destination + Vector3.yAxis * (enemy.humanoid.HipHeight + enemy.root.Size.Y / 2))
		)
		enemy.model.Parent = folder
		enemy.root:SetNetworkOwner(nil)
		enemy.burrowing = false
		enemy.waypoints = {}
		enemy.stuckSince = os.clock()
		enemy.stuckFrom = destination
	end)
end

local function requestPath(enemy: Enemy, goal: Vector3)
	if enemy.pathing then
		return
	end
	enemy.pathing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(1.5, enemy.stats.size * 0.5),
			AgentHeight = math.max(3, enemy.stats.size),
			AgentCanJump = true,
			WaypointSpacing = 6,
		})
		local ok = pcall(function()
			path:ComputeAsync(enemy.root.Position, goal)
		end)
		enemy.pathing = false
		if enemy.dead then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			enemy.waypoints = path:GetWaypoints()
			enemy.waypointIndex = math.min(2, #enemy.waypoints)
		else
			enemy.waypoints = {}
			-- No route: dig through to them.
			burrowTo(enemy, goal)
		end
	end)
end

local function walkTowards(enemy: Enemy, goal: Vector3, now: number)
	local position = enemy.root.Position
	if (goal - position).Magnitude < DIRECT_CHASE_RANGE and lineOfSight(position, goal) then
		enemy.waypoints = {}
		enemy.humanoid:MoveTo(goal)
		return
	end
	if now >= enemy.nextPath then
		enemy.nextPath = now + PATH_INTERVAL
		requestPath(enemy, goal)
	end
	local waypoint = enemy.waypoints[enemy.waypointIndex]
	if waypoint then
		if (waypoint.Position - position).Magnitude < 4 then
			enemy.waypointIndex += 1
			waypoint = enemy.waypoints[enemy.waypointIndex]
		end
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				enemy.humanoid.Jump = true
			end
			enemy.humanoid:MoveTo(waypoint.Position)
		end
	end
end

local function hoverNear(enemy: Enemy, targetRoot: BasePart, now: number)
	local hover = enemy.hover
	if not hover then
		return
	end
	-- Circle the target at a comfortable height, keeping out of melee reach.
	local angle = now * 0.6 + (enemy.model:GetAttribute("Orbit") :: number? or 0)
	local offset = Vector3.new(math.cos(angle) * 18, 12, math.sin(angle) * 18)
	local goal = targetRoot.Position + offset
	if not lineOfSight(targetRoot.Position, goal) then
		goal = targetRoot.Position + Vector3.new(0, 8, 0)
	end
	hover.Position = goal
	local align = enemy.root:FindFirstChildOfClass("AlignOrientation")
	if align then
		align.CFrame = CFrame.lookAt(enemy.root.Position, targetRoot.Position)
	end
end

local function think(enemy: Enemy, now: number, dt: number)
	if enemy.burrowing then
		return
	end
	if enemy.burnUntil > now then
		onDamage(enemy.model, { amount = enemy.burn * dt, kind = "Fire", piercesArmor = true })
		if enemy.dead then
			return
		end
	end
	enemy.slow = math.max(0, enemy.slow - dt * 0.25)
	setSpeed(enemy, now)
	if enemy.frozenUntil > now or enemy.stunnedUntil > now then
		enemy.humanoid:Move(Vector3.zero)
		return
	end

	local position = enemy.root.Position
	local player, distance = nearestCrew(position)
	if not enemy.awake then
		local notice = if enemy.stats.ranged then enemy.stats.attackRange else EnemiesConfig.AGGRO_RANGE
		if player and distance <= notice then
			enemy.awake = true
		else
			return
		end
	end
	if not player then
		enemy.humanoid:Move(Vector3.zero)
		return
	end
	local targetRoot = rootOf(player) :: BasePart
	local goal = targetRoot.Position
	if decoy and decoy.untilTime > now and (decoy.position - position).Magnitude < 60 then
		goal = decoy.position
	end
	enemy.target = player

	if enemy.stats.ranged then
		if enemy.stats.flying then
			hoverNear(enemy, targetRoot, now)
		end
		if
			distance <= enemy.stats.attackRange
			and now >= enemy.nextAttack
			and lineOfSight(position, targetRoot.Position)
		then
			enemy.nextAttack = now + enemy.stats.attackCooldown
			spit(enemy, targetRoot)
		end
		return
	end

	-- Ravager charge: a straight sprint through the target.
	local chargeRange = enemy.stats.chargeRange
	if
		chargeRange
		and enemy.charging <= now
		and now >= enemy.nextAttack
		and distance >= chargeRange[1]
		and distance <= chargeRange[2]
		and lineOfSight(position, goal)
	then
		enemy.charging = now + 1.3
		enemy.chargeHit = false
		enemy.nextAttack = now + 5
		local through = position + (goal - position).Unit * (distance + 12)
		enemy.humanoid:MoveTo(through)
		Net.unreliable("EnemyAttack"):FireAllClients(enemy.model, "Charge")
		return
	end
	if enemy.charging > now then
		if not enemy.chargeHit then
			for _, other in aliveCrew() do
				local root = rootOf(other)
				if root and (root.Position - position).Magnitude <= enemy.stats.size then
					enemy.chargeHit = true
					Vitals.damage(other, enemy.stats.chargeDamage or enemy.stats.damage)
				end
			end
		end
		return
	end

	local reach = enemy.stats.attackRange + enemy.stats.size * 0.5
	if goal == targetRoot.Position and distance <= reach then
		enemy.humanoid:MoveTo(goal)
		if now >= enemy.nextAttack then
			enemy.nextAttack = now + enemy.stats.attackCooldown
			meleeAttack(enemy, player)
		end
		return
	end
	walkTowards(enemy, goal, now)

	-- Stuck detection: barely moved for a while despite chasing.
	if (position - enemy.stuckFrom).Magnitude > 3 then
		enemy.stuckFrom = position
		enemy.stuckSince = now
	elseif now - enemy.stuckSince > STUCK_SECONDS then
		enemy.stuckSince = now
		burrowTo(enemy, targetRoot.Position)
	end
end

local function makeFlying(enemy: Enemy)
	enemy.humanoid.PlatformStand = true
	enemy.humanoid.EvaluateStateMachine = false
	local attachment = Instance.new("Attachment")
	attachment.Parent = enemy.root
	local hover = Instance.new("AlignPosition")
	hover.Mode = Enum.PositionAlignmentMode.OneAttachment
	hover.Attachment0 = attachment
	hover.MaxVelocity = enemy.stats.speed
	hover.MaxForce = 1e6
	hover.Responsiveness = 12
	hover.Position = enemy.root.Position
	hover.Parent = enemy.root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 15
	align.MaxTorque = 1e6
	align.CFrame = enemy.root.CFrame
	align.Parent = enemy.root
	enemy.hover = hover
	enemy.model:SetAttribute("Orbit", Random.new():NextNumber(0, math.pi * 2))
end

export type SpawnOptions = {
	awake: boolean?,
	-- Burst out of the ground with an effect first.
	emerge: boolean?,
}

-- Spawns a Vrill standing on `position`. Returns nil if the hive is at capacity.
function Hive.spawn(enemyType: EnemiesConfig.EnemyType, position: Vector3, options: SpawnOptions?): Enemy?
	if alive >= EnemiesConfig.MAX_ALIVE then
		return nil
	end
	local stats = EnemiesConfig.STATS[enemyType]
	local model = Vrill.build(enemyType)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart
	local health = stats.health * healthScale
	local enemy: Enemy = {
		model = model,
		type = enemyType,
		stats = stats,
		humanoid = humanoid,
		root = root,
		health = health,
		maxHealth = health,
		awake = options ~= nil and options.awake == true,
		dead = false,
		target = nil,
		nextAttack = os.clock() + 1,
		nextPath = 0,
		waypoints = {},
		waypointIndex = 1,
		pathing = false,
		stuckSince = os.clock(),
		stuckFrom = position,
		charging = 0,
		chargeHit = false,
		slow = 0,
		burn = 0,
		burnUntil = 0,
		frozenUntil = 0,
		stunnedUntil = 0,
		burrowing = false,
		lastAttacker = nil,
		hover = nil,
	}
	alive += 1
	enemies[model] = enemy
	local facing = Random.new():NextNumber(0, math.pi * 2)
	local lift = if stats.flying then 6 else humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.new(position + Vector3.yAxis * lift) * CFrame.Angles(0, facing, 0))
	if stats.rooted then
		root.Anchored = true
	end
	local function place()
		if enemy.dead then
			return
		end
		model.Parent = folder
		CollectionService:AddTag(model, "Enemy")
		if not root.Anchored then
			root:SetNetworkOwner(nil)
		end
		if stats.flying then
			makeFlying(enemy)
		end
	end
	if options and options.emerge then
		Net.unreliable("Burrow"):FireAllClients(position)
		task.delay(EnemiesConfig.EMERGE_SECONDS * 0.5, place)
	else
		place()
	end
	return enemy
end

function Hive.count(): number
	return alive
end

function Hive.setHealthScale(scale: number)
	healthScale = scale
end

-- Pulls nearby Vrill to a point until `untilTime` (os.clock()).
function Hive.setDecoy(position: Vector3, untilTime: number)
	decoy = { position = position, untilTime = untilTime }
end

function Hive.onDeath(callback: (Enemy) -> ())
	table.insert(deathListeners, callback)
end

function Hive.all(): { [Model]: Enemy }
	return enemies
end

function Hive.start()
	folder = Instance.new("Folder")
	folder.Name = "Vrill"
	folder.Parent = Workspace
	Damage.register("Enemy", onDamage)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < THINK_INTERVAL then
			return
		end
		local step = accumulated
		accumulated = 0
		local now = os.clock()
		for _, enemy in enemies do
			if not enemy.dead then
				think(enemy, now, step)
			end
		end
	end)
end

return Hive
