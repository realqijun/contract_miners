--!strict
-- Server authority for class tools, grenades and flares: charges, cooldowns, regeneration, and
-- what each tool does to the world. Movement tools (grapple, cable riding) move the player on
-- their own client; the server owns everything they build and everything that deals damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Build)
local Classes = require(Shared.Config.Classes)
local Kits = require(Shared.Config.Kits)
local Net = require(Shared.Net)
local Stats = require(Shared.Stats)
local ToolsConfig = require(Shared.Config.Tools)

local Server = script.Parent.Parent
local Damage = require(Server.Combat.Damage)
local Explosions = require(Server.Combat.Explosions)
local Projectiles = require(Server.Combat.Projectiles)
local Shields = require(Server.Combat.Shields)
local Digging = require(Server.Cave.Digging)
local Vitals = require(Server.Character.Vitals)
local Hive = require(Server.Enemies.Hive)
local Aim = require(script.Parent.Aim)

local Tools = {}

type PlayerState = {
	charges: { [string]: number },
	regen: { [string]: number },
	lastUse: { [string]: number },
	heat: number,
	overheatedUntil: number,
	pendingPylon: BasePart?,
	satchels: { BasePart },
}

local states: { [Player]: PlayerState } = {}
local structures: Folder
local pads: { BasePart } = {}

-- The tool's stats with this player's upgrades applied.
local function statsFor(player: Player, id: string): ToolsConfig.ToolStats
	return Stats.toolFor(player, id)
end

local function kitOf(player: Player): Kits.Kit?
	local classId = player:GetAttribute("Class")
	return if Classes.isClassId(classId) then Kits.BY_CLASS[classId :: Classes.ClassId] else nil
end

local function publish(player: Player, id: string, value: number)
	player:SetAttribute("Charges_" .. id, value)
end

local function folder(name: string): Folder
	local existing = Workspace:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = Workspace
	return created
end

-- Is `id` this player's tool in the slot they hold (or their grenade)?
local function owns(player: Player, id: string, requireHeld: boolean): boolean
	local kit = kitOf(player)
	if not kit then
		return false
	end
	if id == kit.grenade then
		return true
	end
	local slot = if kit.traversal == id then "Traversal" elseif kit.support == id then "Support" else nil
	if not slot then
		return false
	end
	return not requireHeld or player:GetAttribute("HeldSlot") == slot
end

-- Spends a charge if the tool is off cooldown and has one. Tools with no charges never spend.
local function spend(player: Player, state: PlayerState, id: string): boolean
	local stats = statsFor(player, id)
	local now = os.clock()
	if now - (state.lastUse[id] or 0) < stats.cooldown * 0.85 then
		return false
	end
	if stats.charges > 0 then
		local available = state.charges[id] or 0
		if available < 1 then
			return false
		end
		state.charges[id] = available - 1
		publish(player, id, state.charges[id])
	end
	state.lastUse[id] = now
	return true
end

local function neonPart(parent: Instance, props: Build.PartSpec): Part
	local part = Build.part(parent, props)
	part.CanCollide = false
	part.CanTouch = false
	return part
end

------------------------------------------------------------------------------------------------
-- Traversal and support tools

local function foam(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "FoamProjector")
	local result = Aim.cast(player, ray, stats.range)
	if not result or not spend(player, state, "FoamProjector") then
		return
	end
	local normal = result.Normal
	local diameter = stats.padDiameter
	local center
	if normal.Y > 0.7 then
		center = result.Position + Vector3.yAxis * 0.4
	elseif normal.Y < -0.5 then
		center = result.Position - Vector3.yAxis * 0.6
	else
		-- On a wall the pad juts out horizontally, its edge sunk into the rock.
		local out = Vector3.new(normal.X, 0, normal.Z).Unit
		center = result.Position + out * (diameter / 2 - 0.4)
	end
	local classColor = Classes.INFO.Mechanic.color
	local pad = Build.part(structures, {
		name = "FoamPad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(diameter, 1, 0),
		cframe = CFrame.new(center) * CFrame.Angles(0, math.random() * math.pi, 0),
		color = classColor:Lerp(Color3.new(1, 1, 1), 0.55),
		material = Enum.Material.SmoothPlastic,
	})
	table.insert(pads, pad)
	if #pads > stats.maxPads then
		local oldest = table.remove(pads, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local function pylonModel(position: Vector3, color: Color3): BasePart
	local base = Build.part(structures, {
		name = "Pylon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 3.6, 0),
		cframe = CFrame.new(position + Vector3.yAxis * 1.8),
		color = Color3.fromRGB(58, 56, 66),
		material = Enum.Material.Metal,
	})
	local tip = neonPart(base, {
		name = "Coil",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(position + Vector3.yAxis * 3.8),
		color = color,
		material = Enum.Material.Neon,
		castShadow = false,
	})
	tip.Parent = base
	Build.light(tip, "PointLight", { Color = color, Range = 10, Brightness = 1.2, Shadows = false })
	local attachment = Instance.new("Attachment")
	attachment.Name = "Arc"
	attachment.WorldPosition = tip.Position
	attachment.Parent = base
	return base
end

local function pylons(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "ArcPylons")
	local result = Aim.cast(player, ray, stats.range)
	if not result or result.Normal.Y < 0.6 then
		return
	end
	local color = Color3.fromRGB(110, 200, 255)
	local first = state.pendingPylon
	if not first or not first.Parent then
		if (state.charges.ArcPylons or 0) < 1 then
			return
		end
		state.pendingPylon = pylonModel(result.Position, color)
		return
	end
	local gap = (result.Position - first.Position)
	if Vector3.new(gap.X, 0, gap.Z).Magnitude > stats.maxGap or not spend(player, state, "ArcPylons") then
		return
	end
	state.pendingPylon = nil
	local second = pylonModel(result.Position, color)
	local beam = Instance.new("Beam")
	beam.Attachment0 = first:FindFirstChild("Arc") :: Attachment
	beam.Attachment1 = second:FindFirstChild("Arc") :: Attachment
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.Segments = 12
	beam.CurveSize0 = 0.6
	beam.CurveSize1 = -0.6
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 4
	beam.Parent = first
	local a, b = first.Position, second.Position
	local untilTime = os.clock() + stats.lifetime
	local accumulated = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() >= untilTime or not first.Parent then
			connection:Disconnect()
			first:Destroy()
			second:Destroy()
			return
		end
		accumulated += dt
		if accumulated < 0.2 then
			return
		end
		local tick = accumulated
		accumulated = 0
		local ab = b - a
		for _, model in CollectionService:GetTagged("Enemy") do
			local root = (model :: Model).PrimaryPart
			if root then
				local t = math.clamp((root.Position - a):Dot(ab) / ab:Dot(ab), 0, 1)
				local closest = a + ab * t
				local offset = root.Position - closest
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < 2.5 and math.abs(offset.Y) < 6 then
					Damage.apply(root, {
						amount = stats.damagePerSecond * tick,
						kind = "Electric",
						attacker = player,
						piercesArmor = true,
						stun = 0.3,
					})
				end
			end
		end
	end)
end

local function grapple(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "GrappleLine")
	local result = Aim.cast(player, ray, stats.range)
	if not result or not spend(player, state, "GrappleLine") then
		return
	end
	player:SetAttribute("GrappledAt", Workspace:GetServerTimeNow())
	local head = Aim.head(player) or ray.origin
	Net.unreliable("ToolEffect"):FireAllClients(player, "Grapple", head, result.Position)
end

local function lumen(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "LumenDarts")
	if not spend(player, state, "LumenDarts") then
		return
	end
	Projectiles.launch({
		origin = ray.origin + ray.direction * 2,
		velocity = ray.direction * 140,
		gravity = 8,
		lifetime = 3,
		ignore = Aim.ignoreList(),
		style = "Lumen",
		onImpact = function(position, normal)
			local holder = neonPart(folder("Effects"), {
				name = "LumenDart",
				shape = Enum.PartType.Ball,
				size = Vector3.new(0.6, 0.6, 0.6),
				cframe = CFrame.new(position + normal * 0.3),
				color = Color3.fromRGB(200, 240, 255),
				material = Enum.Material.Neon,
				castShadow = false,
			})
			holder.CanQuery = false
			Build.light(holder, "PointLight", {
				Color = Color3.fromRGB(210, 235, 255),
				Range = stats.lightRange,
				Brightness = 1.8,
				Shadows = true,
			})
			task.delay(stats.lifetime, function()
				holder:Destroy()
			end)
			-- Reveal minerals around the dart.
			local minerals = Workspace:FindFirstChild("Minerals")
			if minerals then
				local until_ = Workspace:GetServerTimeNow() + stats.revealSeconds
				for _, mineral in minerals:GetChildren() do
					if
						mineral:IsA("Model")
						and (mineral:GetPivot().Position - position).Magnitude <= stats.revealRadius
					then
						mineral:SetAttribute("RevealedUntil", until_)
					end
				end
			end
		end,
	})
end

local function cable(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "CableLauncher")
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return
	end
	local result = Aim.cast(player, ray, stats.range)
	if not result then
		return
	end
	local start = root.Position + Vector3.yAxis * 1.5
	local finish = result.Position + result.Normal * 1.2
	local span = finish - start
	if span.Magnitude < 6 or math.deg(math.asin(math.clamp(math.abs(span.Unit.Y), 0, 1))) > stats.maxAngle then
		return
	end
	if not spend(player, state, "CableLauncher") then
		return
	end
	local model = Build.model("Cable", structures)
	local function anchor(position: Vector3): BasePart
		local part = Build.part(model, {
			name = "Anchor",
			size = Vector3.new(0.8, 0.8, 0.8),
			cframe = CFrame.new(position),
			color = Color3.fromRGB(214, 70, 58),
			material = Enum.Material.Metal,
		})
		part.CanCollide = false
		local attachment = Instance.new("Attachment")
		attachment.Name = "Line"
		attachment.Parent = part
		return part
	end
	local a, b = anchor(start), anchor(finish)
	local rope = Instance.new("Beam")
	rope.Attachment0 = a:FindFirstChild("Line") :: Attachment
	rope.Attachment1 = b:FindFirstChild("Line") :: Attachment
	rope.Width0 = 0.18
	rope.Width1 = 0.18
	rope.Color = ColorSequence.new(Color3.fromRGB(230, 220, 200))
	rope.LightInfluence = 1
	rope.FaceCamera = true
	rope.Parent = a
	model:SetAttribute("A", start)
	model:SetAttribute("B", finish)
	model:SetAttribute("RideSpeed", stats.rideSpeed)
	CollectionService:AddTag(model, "Cable")
end

local function dome(player: Player, state: PlayerState)
	local stats = statsFor(player, "AegisDome")
	local root = player.Character and player.Character.PrimaryPart
	if not root or not spend(player, state, "AegisDome") then
		return
	end
	local part = Build.part(Shields.folder(), {
		name = "AegisDome",
		shape = Enum.PartType.Ball,
		size = Vector3.one * stats.radius * 2,
		cframe = CFrame.new(root.Position),
		color = Color3.fromRGB(255, 120, 100),
		material = Enum.Material.ForceField,
		transparency = 0.2,
		castShadow = false,
	})
	part.CanCollide = false
	part.CanTouch = false
	Shields.add(part, stats.radius, stats.meleeReduction)
	task.delay(stats.lifetime, function()
		part:Destroy()
	end)
end

local function cutter(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "PlasmaCutter")
	local now = os.clock()
	if now < state.overheatedUntil or not spend(player, state, "PlasmaCutter") then
		return
	end
	state.heat = math.min(1, state.heat + stats.heatPerTick)
	if state.heat >= 1 then
		state.overheatedUntil = now + stats.overheatLockout
	end
	player:SetAttribute("Heat_PlasmaCutter", math.floor(state.heat * 100) / 100)
	local head = Aim.head(player) or ray.origin
	local result = Aim.cast(player, ray, stats.range)
	local finish = if result then result.Position else head + ray.direction * stats.range
	if result then
		if
			not Damage.apply(result.Instance, {
				amount = stats.damagePerTick,
				kind = "Fire",
				attacker = player,
				position = result.Position,
				piercesArmor = true,
			})
		then
			Digging.sphere(result.Position + ray.direction * 1.2, stats.digRadius)
		end
	end
	Net.unreliable("ToolEffect"):FireAllClients(player, "Cutter", head, finish)
end

local function satchel(player: Player, state: PlayerState, ray: Aim.Ray)
	local stats = statsFor(player, "SatchelCharge")
	if not spend(player, state, "SatchelCharge") then
		return
	end
	Projectiles.launch({
		origin = ray.origin + ray.direction * 2,
		velocity = ray.direction * stats.throwSpeed,
		gravity = ToolsConfig.THROW_GRAVITY,
		lifetime = 6,
		ignore = Aim.ignoreList(),
		style = "Satchel",
		onImpact = function(position, normal)
			local pack = Build.part(structures, {
				name = "Satchel",
				size = Vector3.new(1.4, 0.8, 1.1),
				cframe = CFrame.new(position + normal * 0.4),
				color = Color3.fromRGB(122, 196, 72),
				material = Enum.Material.Fabric,
			})
			pack.CanCollide = false
			local light = neonPart(pack, {
				name = "Blinker",
				size = Vector3.new(0.3, 0.3, 0.3),
				cframe = pack.CFrame * CFrame.new(0, 0.45, 0),
				color = Color3.fromRGB(255, 60, 40),
				material = Enum.Material.Neon,
				castShadow = false,
			})
			light.Parent = pack
			table.insert(state.satchels, pack)
			player:SetAttribute("SatchelsPlaced", #state.satchels)
		end,
	})
end

local function detonate(player: Player, state: PlayerState)
	local stats = statsFor(player, "SatchelCharge")
	local placed = state.satchels
	state.satchels = {}
	player:SetAttribute("SatchelsPlaced", 0)
	for _, pack in placed do
		if pack.Parent then
			local position = pack.Position
			pack:Destroy()
			Explosions.detonate({
				position = position,
				radius = stats.radius,
				damage = stats.damage,
				attacker = player,
				digRadius = stats.digRadius,
				friendlyFire = true,
				style = "Satchel",
			})
		end
	end
end

------------------------------------------------------------------------------------------------
-- Grenades and flares

local function grenadeImpact(player: Player, id: string, position: Vector3)
	local stats = statsFor(player, id)
	if id == "DecoyBeacon" then
		local beacon = neonPart(structures, {
			name = "Decoy",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.2, 1.2, 1.2),
			cframe = CFrame.new(position + Vector3.yAxis * 0.6),
			color = Color3.fromRGB(255, 200, 80),
			material = Enum.Material.Neon,
			castShadow = false,
		})
		Build.light(
			beacon,
			"PointLight",
			{ Color = Color3.fromRGB(255, 200, 80), Range = 16, Brightness = 2, Shadows = false }
		)
		Hive.setDecoy(position, os.clock() + stats.lure)
		task.delay(stats.lure, function()
			beacon:Destroy()
			Explosions.detonate({
				position = position,
				radius = stats.radius,
				damage = stats.damage,
				attacker = player,
				style = "Decoy",
			})
		end)
	elseif id == "CryoBomb" then
		Explosions.detonate({
			position = position,
			radius = stats.radius,
			damage = stats.damage,
			attacker = player,
			kind = "Cold",
			freeze = stats.freeze,
			style = "Cryo",
		})
	elseif id == "ClusterBomb" then
		Explosions.detonate({
			position = position,
			radius = stats.radius,
			damage = stats.damage,
			attacker = player,
			style = "Blast",
		})
		local rng = Random.new()
		for _ = 1, stats.bomblets do
			local scatter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.2), rng:NextNumber(-1, 1)).Unit
				* rng:NextNumber(18, 28)
			Projectiles.launch({
				origin = position + Vector3.yAxis,
				velocity = scatter,
				gravity = ToolsConfig.THROW_GRAVITY,
				lifetime = 1.5,
				ignore = Aim.ignoreList(),
				style = "Grenade",
				onImpact = function(at)
					Explosions.detonate({
						position = at,
						radius = stats.bombletRadius,
						damage = stats.bombletDamage,
						attacker = player,
						style = "Blast",
					})
				end,
			})
		end
	elseif id == "SeismicGrenade" then
		Explosions.detonate({
			position = position,
			radius = stats.radius,
			damage = stats.damage,
			attacker = player,
			digRadius = stats.digRadius,
			stun = stats.stun,
			style = "Seismic",
		})
	end
end

local function flareImpact(position: Vector3, normal: Vector3)
	local flare = neonPart(folder("Effects"), {
		name = "Flare",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.35, 1, 0),
		cframe = CFrame.new(position + normal * 0.3),
		color = Color3.fromRGB(255, 120, 60),
		material = Enum.Material.Neon,
		castShadow = false,
	})
	flare.CanQuery = false
	Build.light(flare, "PointLight", {
		Color = Color3.fromRGB(255, 150, 90),
		Range = ToolsConfig.FLARES.lightRange,
		Brightness = 2.2,
		Shadows = true,
	})
	task.delay(ToolsConfig.FLARES.lifetime, function()
		flare:Destroy()
	end)
end

local function onThrow(player: Player, kind: unknown, origin: unknown, direction: unknown)
	local state = states[player]
	local kit = kitOf(player)
	if not (state and kit) or not Vitals.isAlive(player) then
		return
	end
	local ray = Aim.validate(player, origin, direction)
	if not ray then
		return
	end
	local id = if kind == "Flare" then "Flares" elseif kind == "Grenade" then kit.grenade else nil
	if not id then
		return
	end
	local now = os.clock()
	if now - (state.lastUse[id] or 0) < 0.8 or (state.charges[id] or 0) < 1 then
		return
	end
	state.lastUse[id] = now
	state.charges[id] -= 1
	publish(player, id, state.charges[id])
	local throwOrigin = (Aim.head(player) or ray.origin) + ray.direction * 1.5
	Projectiles.launch({
		origin = throwOrigin,
		velocity = ray.direction * ToolsConfig.THROW_SPEED + Vector3.yAxis * 8,
		gravity = ToolsConfig.THROW_GRAVITY,
		lifetime = 5,
		ignore = Aim.ignoreList(),
		style = if kind == "Flare" then "Flare" else "Grenade",
		onImpact = function(position, normal)
			if kind == "Flare" then
				flareImpact(position, normal)
			else
				grenadeImpact(player, id, position)
			end
		end,
	})
end

------------------------------------------------------------------------------------------------

local function onToolUse(player: Player, id: unknown, action: unknown, origin: unknown, direction: unknown)
	local state = states[player]
	if not state or type(id) ~= "string" or not ToolsConfig.TOOLS[id] or not owns(player, id, true) then
		return
	end
	if not Vitals.isAlive(player) then
		return
	end
	if id == "AegisDome" then
		dome(player, state)
		return
	end
	if id == "SatchelCharge" and action == "Detonate" then
		detonate(player, state)
		return
	end
	local ray = Aim.validate(player, origin, direction)
	if not ray then
		return
	end
	if id == "FoamProjector" then
		foam(player, state, ray)
	elseif id == "ArcPylons" then
		pylons(player, state, ray)
	elseif id == "GrappleLine" then
		grapple(player, state, ray)
	elseif id == "LumenDarts" then
		lumen(player, state, ray)
	elseif id == "CableLauncher" then
		cable(player, state, ray)
	elseif id == "PlasmaCutter" then
		cutter(player, state, ray)
	elseif id == "SatchelCharge" then
		satchel(player, state, ray)
	end
end

-- Full charges for the class's tools, grenade and flares (mission start and resupply).
function Tools.arm(player: Player)
	local kit = kitOf(player)
	if not kit then
		return
	end
	local state = states[player]
		or {
			charges = {},
			regen = {},
			lastUse = {},
			heat = 0,
			overheatedUntil = 0,
			pendingPylon = nil,
			satchels = {},
		}
	states[player] = state
	for _, id in { kit.traversal, kit.support, kit.grenade } do
		state.charges[id] = statsFor(player, id).charges
		publish(player, id, state.charges[id])
	end
	state.charges.Flares = ToolsConfig.FLARES.charges
	publish(player, "Flares", state.charges.Flares)
end

Tools.refill = Tools.arm

function Tools.start()
	structures = folder("Structures")
	Net.event("ToolUse").OnServerEvent:Connect(onToolUse)
	Net.event("Throw").OnServerEvent:Connect(onThrow)
	-- Satchels hurt the crew; nothing else the crew does can.
	Damage.register("Crew", function(target, info)
		local player = Players:GetPlayerFromCharacter(target)
		if player and info.friendlyFire then
			Vitals.damage(player, info.amount * 0.4)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		for player, state in states do
			local kit = kitOf(player)
			if not kit then
				continue
			end
			for _, id in { kit.traversal, kit.support } do
				local stats = statsFor(player, id)
				if stats.regenPerSecond > 0 and (state.charges[id] or 0) < stats.charges then
					state.regen[id] = (state.regen[id] or 0) + stats.regenPerSecond * dt
					if state.regen[id] >= 1 then
						state.regen[id] -= 1
						state.charges[id] += 1
						publish(player, id, state.charges[id])
					end
				end
			end
			if (state.charges.Flares or 0) < ToolsConfig.FLARES.charges then
				state.regen.Flares = (state.regen.Flares or 0) + ToolsConfig.FLARES.regenPerSecond * dt
				if state.regen.Flares >= 1 then
					state.regen.Flares -= 1
					state.charges.Flares += 1
					publish(player, "Flares", state.charges.Flares)
				end
			end
			-- The cutter only cools while it is not cutting.
			if state.heat > 0 and os.clock() - (state.lastUse.PlasmaCutter or 0) > 0.3 then
				local before = math.floor(state.heat * 20)
				state.heat = math.max(0, state.heat - statsFor(player, "PlasmaCutter").coolPerSecond * dt)
				if math.floor(state.heat * 20) ~= before then
					player:SetAttribute("Heat_PlasmaCutter", math.floor(state.heat * 100) / 100)
				end
			end
		end
	end)
end

return Tools
