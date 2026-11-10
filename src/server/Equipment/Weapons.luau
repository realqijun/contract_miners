--!strict
-- Server authority for class weapons: ammo, fire rate, heat, and validating every claimed hit
-- before damage is applied. Clients fire instantly for feel; the server decides what landed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Kits = require(Shared.Config.Kits)
local Net = require(Shared.Net)
local Stats = require(Shared.Stats)
local WeaponsConfig = require(Shared.Config.Weapons)

local Server = script.Parent.Parent
local Damage = require(Server.Combat.Damage)
local Explosions = require(Server.Combat.Explosions)
local Projectiles = require(Server.Combat.Projectiles)
local Vitals = require(Server.Character.Vitals)
local Aim = require(script.Parent.Aim)

local Weapons = {}

-- How far a claimed hit may be from where the server sees the target (latency and movement).
local HIT_TOLERANCE = 7
-- Maximum angle between the shot direction and the claimed hit, in degrees.
local MAX_HIT_ANGLE = 4
-- Shots allowed to arrive early in one batch, absorbing network bunching.
local RATE_BURST = 4
local STREAM_TICK = 0.1

type WeaponState = {
	mag: number,
	reserve: number,
	-- Shot budget refilled at the weapon's fire rate.
	tokens: number,
	lastRefill: number,
	reloadingUntil: number,
	heat: number,
	overheatedUntil: number,
}

local states: { [Player]: { [string]: WeaponState } } = {}

local function kitOf(player: Player): Kits.Kit?
	local classId = player:GetAttribute("Class")
	return if Classes.isClassId(classId) then Kits.BY_CLASS[classId :: Classes.ClassId] else nil
end

local function slotOf(kit: Kits.Kit, weaponId: string): string?
	if kit.primary == weaponId then
		return "Primary"
	elseif kit.secondary == weaponId then
		return "Secondary"
	end
	return nil
end

local function publish(player: Player, weaponId: string, state: WeaponState)
	player:SetAttribute("Mag_" .. weaponId, state.mag)
	player:SetAttribute("Reserve_" .. weaponId, state.reserve)
	player:SetAttribute("Heat_" .. weaponId, math.floor(state.heat * 100 + 0.5) / 100)
end

local function stateFor(player: Player, weaponId: WeaponsConfig.WeaponId): WeaponState
	local byWeapon = states[player]
	if not byWeapon then
		byWeapon = {}
		states[player] = byWeapon
	end
	local state = byWeapon[weaponId]
	if not state then
		local stats = Stats.weaponFor(player, weaponId)
		state = {
			mag = stats.magazine,
			reserve = stats.reserve,
			tokens = RATE_BURST,
			lastRefill = os.clock(),
			reloadingUntil = 0,
			heat = 0,
			overheatedUntil = 0,
		}
		byWeapon[weaponId] = state
		publish(player, weaponId, state)
	end
	return state
end

-- Validates that the player holds this weapon and returns its stats and state.
local function armed(player: Player, weaponId: unknown): (WeaponsConfig.Stats?, WeaponState?)
	if type(weaponId) ~= "string" or not WeaponsConfig.STATS[weaponId :: WeaponsConfig.WeaponId] then
		return nil, nil
	end
	local kit = kitOf(player)
	local slot = kit and slotOf(kit, weaponId)
	if not slot or player:GetAttribute("HeldSlot") ~= slot or not Vitals.isAlive(player) then
		return nil, nil
	end
	local id = weaponId :: WeaponsConfig.WeaponId
	return Stats.weaponFor(player, id), stateFor(player, id)
end

local function refill(state: WeaponState, stats: WeaponsConfig.Stats)
	local now = os.clock()
	local perSecond = stats.rpm / 60
	state.tokens = math.min(RATE_BURST + (stats.burstCount or 0), state.tokens + (now - state.lastRefill) * perSecond)
	state.lastRefill = now
end

-- Is `position` plausibly on `part` given latency, and visible from `origin`?
local function plausibleHit(
	origin: Vector3,
	direction: Vector3,
	part: BasePart,
	position: Vector3,
	range: number
): boolean
	if (position - origin).Magnitude > range + HIT_TOLERANCE then
		return false
	end
	local radius = part.Size.Magnitude / 2 + HIT_TOLERANCE
	if (position - part.Position).Magnitude > radius then
		return false
	end
	local toHit = position - origin
	if toHit.Magnitude > 1 and math.deg(math.acos(math.clamp(toHit.Unit:Dot(direction), -1, 1))) > MAX_HIT_ANGLE then
		return false
	end
	-- Terrain between the shooter and the hit means the client saw through a wall.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local blocked = Workspace:Raycast(origin, toHit - toHit.Unit * 1.5, params)
	return blocked == nil
end

local function hitInfo(player: Player, stats: WeaponsConfig.Stats, part: BasePart, position: Vector3): Damage.Info
	return {
		amount = stats.damage,
		kind = "Bullet",
		attacker = player,
		position = position,
		part = part,
		weakspotMultiplier = stats.weakspotMultiplier,
		piercesArmor = stats.piercesArmor,
		slow = stats.slowPerHit,
	}
end

local function fireHitscan(player: Player, stats: WeaponsConfig.Stats, state: WeaponState, ray: Aim.Ray, shots: { any })
	local ignore = Aim.ignoreList()
	local ends = {}
	for _, shot in shots do
		refill(state, stats)
		if state.tokens < 1 or state.mag <= 0 or state.overheatedUntil > os.clock() then
			break
		end
		if type(shot) ~= "table" or typeof(shot.direction) ~= "Vector3" then
			continue
		end
		local direction = shot.direction :: Vector3
		if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
			continue
		end
		direction = direction.Unit
		state.tokens -= 1
		if stats.mode == "Spin" then
			state.heat = math.min(1, state.heat + (stats.heatPerShot or 0))
			if state.heat >= 1 then
				state.overheatedUntil = os.clock() + (stats.overheatLockout or 2)
			end
		else
			state.mag -= 1
		end
		local part = shot.part
		local position = shot.position
		local landed = false
		if typeof(part) == "Instance" and (part :: Instance):IsA("BasePart") and typeof(position) == "Vector3" then
			local hitPart = part :: BasePart
			if
				hitPart:IsDescendantOf(Workspace)
				and plausibleHit(ray.origin, direction, hitPart, position, stats.range)
			then
				landed = Damage.apply(hitPart, hitInfo(player, stats, hitPart, position))
				table.insert(ends, position)
			end
		end
		if not landed then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			local result = Workspace:Raycast(ray.origin, direction * stats.range, params)
			table.insert(ends, if result then result.Position else ray.origin + direction * stats.range)
		end
	end
	publish(player, stats.id, state)
	Net.unreliable("WeaponShots"):FireAllClients(player, stats.id, ray.origin, ends)
end

local function fireLobbed(player: Player, stats: WeaponsConfig.Stats, state: WeaponState, ray: Aim.Ray)
	refill(state, stats)
	if state.tokens < 1 or state.mag <= 0 then
		return
	end
	state.tokens -= 1
	state.mag -= 1
	publish(player, stats.id, state)
	Projectiles.launch({
		origin = ray.origin + ray.direction * 2,
		velocity = ray.direction * (stats.projectileSpeed or 100),
		gravity = stats.gravity or 60,
		lifetime = 6,
		ignore = Aim.ignoreList(),
		style = "Mortar",
		onImpact = function(position)
			Explosions.detonate({
				position = position,
				radius = stats.splashRadius or 8,
				damage = stats.damage,
				attacker = player,
				digRadius = 3,
				style = "Mortar",
			})
		end,
	})
end

-- One tick of a stream weapon: damages every enemy inside the cone with line of sight.
local function fireStream(player: Player, stats: WeaponsConfig.Stats, state: WeaponState, ray: Aim.Ray)
	refill(state, stats)
	local ammoPerTick = math.max(1, math.floor(stats.rpm / 60 * STREAM_TICK + 0.5))
	if state.tokens < ammoPerTick * 0.8 or state.mag <= 0 then
		return
	end
	state.tokens -= ammoPerTick
	state.mag = math.max(0, state.mag - ammoPerTick)
	publish(player, stats.id, state)
	local head = Aim.head(player)
	if not head then
		return
	end
	local cosine = math.cos(math.rad(stats.spread))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	for _, enemy in CollectionService:GetTagged("Enemy") do
		if enemy:IsA("Model") and enemy.PrimaryPart then
			local offset = enemy.PrimaryPart.Position - head
			local distance = offset.Magnitude
			if distance <= stats.range and (distance < 3 or offset.Unit:Dot(ray.direction) >= cosine) then
				if not Workspace:Raycast(head, offset, params) then
					Damage.apply(enemy.PrimaryPart, {
						amount = stats.damage * STREAM_TICK,
						kind = "Fire",
						attacker = player,
						position = enemy.PrimaryPart.Position,
						piercesArmor = true,
						burn = stats.burnPerSecond,
					})
				end
			end
		end
	end
	Net.unreliable("WeaponShots")
		:FireAllClients(player, stats.id, ray.origin, { ray.origin + ray.direction * stats.range })
end

local function onFire(player: Player, weaponId: unknown, origin: unknown, shots: unknown)
	local stats, state = armed(player, weaponId)
	if not (stats and state) or state.reloadingUntil > os.clock() then
		return
	end
	if type(shots) ~= "table" or #(shots :: { any }) == 0 or #(shots :: { any }) > 16 then
		return
	end
	local first = (shots :: { any })[1]
	local ray = Aim.validate(player, origin, if type(first) == "table" then first.direction else nil)
	if not ray then
		return
	end
	if stats.mode == "Lobbed" then
		fireLobbed(player, stats, state, ray)
	elseif stats.mode == "Stream" then
		fireStream(player, stats, state, ray)
	else
		fireHitscan(player, stats, state, ray, shots :: { any })
	end
end

local function onReload(player: Player, weaponId: unknown)
	local stats, state = armed(player, weaponId)
	if not (stats and state) or stats.mode == "Spin" then
		return
	end
	if state.reloadingUntil > os.clock() or state.mag >= stats.magazine or state.reserve <= 0 then
		return
	end
	state.reloadingUntil = os.clock() + stats.reloadTime
	task.delay(stats.reloadTime, function()
		if states[player] == nil then
			return
		end
		local needed = stats.magazine - state.mag
		local moved = math.min(needed, state.reserve)
		state.mag += moved
		state.reserve -= moved
		publish(player, stats.id, state)
	end)
end

-- Refills every weapon to full (resupply pods). Returns nothing if the player has no weapons yet.
function Weapons.resupply(player: Player)
	local byWeapon = states[player]
	if not byWeapon then
		return
	end
	for weaponId, state in byWeapon do
		local stats = Stats.weaponFor(player, weaponId :: WeaponsConfig.WeaponId)
		state.mag = stats.magazine
		state.reserve = stats.reserve
		publish(player, weaponId, state)
	end
end

-- Fresh ammo for a new character (mission start).
function Weapons.arm(player: Player)
	states[player] = nil
	local kit = kitOf(player)
	if kit then
		stateFor(player, kit.primary)
		stateFor(player, kit.secondary)
	end
end

function Weapons.start()
	Net.event("WeaponFire").OnServerEvent:Connect(onFire)
	Net.event("WeaponReload").OnServerEvent:Connect(onReload)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	-- Spin weapons cool down whenever they are not firing.
	RunService.Heartbeat:Connect(function(dt)
		for player, byWeapon in states do
			for weaponId, state in byWeapon do
				-- Spin weapons only cool once the trigger is released.
				if state.heat > 0 and os.clock() - state.lastRefill > 0.25 then
					local stats = WeaponsConfig.STATS[weaponId :: WeaponsConfig.WeaponId]
					local before = math.floor(state.heat * 20)
					state.heat = math.max(0, state.heat - (stats.coolPerSecond or 0.5) * dt)
					if math.floor(state.heat * 20) ~= before then
						publish(player, weaponId, state)
					end
				end
			end
		end
	end)
end

return Weapons
