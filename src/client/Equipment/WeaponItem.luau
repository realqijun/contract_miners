--!strict
-- A class weapon in hand. One implementation covers every fire mode in Config/Weapons:
-- shots fire instantly on this client (tracer, flash, recoil, hit marker) and are sent to the
-- server, which owns ammo, heat and damage. Server ammo attributes correct the local prediction.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Items = require(Shared.Models.Items)
local Net = require(Shared.Net)
local Stats = require(Shared.Stats)
local WeaponsConfig = require(Shared.Config.Weapons)

local Client = script.Parent.Parent
local CameraController = require(Client.Character.CameraController)
local Movement = require(Client.Character.Movement)
local Viewmodel = require(Client.Character.Viewmodel)
local Effects = require(Client.Effects)
local Sounds = require(Client.Sounds)
local EquipmentHud = require(Client.UI.EquipmentHud)
local Hud = require(Client.UI.Hud)
local Loadout = require(script.Parent.Loadout)

local player = Players.LocalPlayer

-- Where each weapon sits in first person; big guns hang lower and further out so they frame the view.
local HOLDS: { [string]: CFrame } = {
	RotaryCannon = CFrame.new(1.35, -1.75, -2.4),
	ArcMortar = CFrame.new(1.2, -1.6, -2.1),
	FlameProjector = CFrame.new(1.15, -1.5, -2.0),
	BurstCarbine = CFrame.new(1.0, -1.3, -1.9),
}
local DEFAULT_HOLD = CFrame.new(0.95, -1.2, -1.8)
local STREAM_TICK = 0.1
-- After firing, ignore server ammo updates briefly so in-flight shots do not make the count jump back.
local PREDICTION_GRACE = 0.35

local rng = Random.new()

local function enemyOf(instance: Instance): Instance?
	local current: Instance? = instance
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, "Enemy") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function spreadDirection(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	-- Uniform within the cone.
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local spin = rng:NextNumber(0, math.pi * 2)
	local basis = CFrame.lookAlong(Vector3.zero, direction)
	return (basis * CFrame.Angles(0, 0, spin) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function aimParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { Workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "Effects", "Shields" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Where tracers start: the viewmodel muzzle in first person, the held gun's muzzle in third.
local function muzzlePosition(fallback: Vector3): Vector3
	if CameraController.getMode() == "First" then
		return Viewmodel.point("Muzzle") or fallback
	end
	local held = player.Character and player.Character:FindFirstChild("HeldItem")
	local marker = held and held:FindFirstChild("Muzzle", true)
	return if marker and marker:IsA("Attachment") then marker.WorldPosition else fallback
end

return function(weaponId: WeaponsConfig.WeaponId): Loadout.Item
	local stats = Stats.weaponFor(player, weaponId)
	local equipped = false
	local triggerHeld = false
	local firing = false
	local lastShot = 0
	local reloadingUntil = 0
	local mag = stats.magazine
	local reserve = stats.reserve
	local heat = 0
	local spin = 0
	local lastPredicted = 0

	local function refreshHud()
		if not equipped then
			return
		end
		local note: string? = nil
		if os.clock() < reloadingUntil then
			note = "RELOADING"
		elseif stats.mode == "Spin" and heat >= 0.99 then
			note = "OVERHEATED"
		elseif mag == 0 and reserve == 0 then
			note = "NO AMMO"
		end
		EquipmentHud.show({
			name = stats.displayName,
			primary = mag,
			secondary = if stats.mode == "Spin" then nil else reserve,
			bar = if stats.mode == "Spin" then heat else nil,
			barColor = Color3.fromRGB(255, 120, 60),
			note = note,
		})
	end

	local function syncFromServer()
		if os.clock() - lastPredicted < PREDICTION_GRACE then
			return
		end
		local serverMag = player:GetAttribute("Mag_" .. weaponId)
		local serverReserve = player:GetAttribute("Reserve_" .. weaponId)
		local serverHeat = player:GetAttribute("Heat_" .. weaponId)
		if type(serverMag) == "number" then
			mag = serverMag
		end
		if type(serverReserve) == "number" then
			reserve = serverReserve
		end
		if type(serverHeat) == "number" then
			heat = serverHeat
		end
		refreshHud()
	end
	for _, prefix in { "Mag_", "Reserve_", "Heat_" } do
		player:GetAttributeChangedSignal(prefix .. weaponId):Connect(syncFromServer)
	end

	local function reload()
		if os.clock() < reloadingUntil or stats.mode == "Spin" or mag >= stats.magazine or reserve <= 0 then
			return
		end
		reloadingUntil = os.clock() + stats.reloadTime
		Net.event("WeaponReload"):FireServer(weaponId)
		Viewmodel.play(function(alpha)
			local dip = math.sin(alpha * math.pi)
			return CFrame.new(0, -0.6 * dip, 0.3 * dip) * CFrame.Angles(math.rad(-25) * dip, 0, math.rad(20) * dip)
		end, stats.reloadTime)
		refreshHud()
		task.delay(stats.reloadTime, function()
			-- Predict the refill; the server's attributes confirm it moments later.
			local moved = math.min(stats.magazine - mag, reserve)
			mag += moved
			reserve -= moved
			lastPredicted = os.clock()
			refreshHud()
		end)
	end

	local function canShoot(): boolean
		if os.clock() < reloadingUntil then
			return false
		end
		if stats.mode == "Spin" then
			return heat < 0.99
		end
		return mag > 0
	end

	local function kick()
		local pitch = math.rad(stats.recoil) * rng:NextNumber(0.7, 1)
		local yaw = math.rad(stats.recoil) * rng:NextNumber(-0.35, 0.35)
		CameraController.addLook(yaw, pitch)
		Viewmodel.kick(CFrame.new(0, 0, 0.06 + stats.recoil * 0.02) * CFrame.Angles(math.rad(stats.recoil * 1.5), 0, 0))
	end

	-- One trigger pull's worth of bullets (or pellets) along the current aim.
	local function shoot()
		local origin, direction = CameraController.aimRay()
		local params = aimParams()
		local shots = {}
		local muzzle = muzzlePosition(origin + direction * 2)
		for _ = 1, stats.pellets do
			local shotDirection = spreadDirection(direction, stats.spread)
			local result = Workspace:Raycast(origin, shotDirection * stats.range, params)
			local finish = if result then result.Position else origin + shotDirection * stats.range
			local shot: { [string]: any } = { direction = shotDirection }
			if result then
				local enemy = enemyOf(result.Instance)
				if enemy then
					shot.part = result.Instance
					shot.position = result.Position
					Hud.hitMarker(result.Instance:GetAttribute("Weakspot") == true)
					Effects.impact(result.Position, result.Normal, "Flesh")
				else
					Effects.impact(result.Position, result.Normal, "Rock")
				end
			end
			Effects.tracer(muzzle, finish)
			table.insert(shots, shot)
		end
		Effects.muzzleFlash(muzzle, direction)
		Sounds.play(weaponId, muzzle)
		Net.event("WeaponFire"):FireServer(weaponId, origin, shots)
		lastShot = os.clock()
		lastPredicted = lastShot
		if stats.mode == "Spin" then
			heat = math.min(1, heat + (stats.heatPerShot or 0))
		else
			mag -= 1
		end
		kick()
		refreshHud()
	end

	local function lob()
		local origin, direction = CameraController.aimRay()
		Net.event("WeaponFire"):FireServer(weaponId, origin, { { direction = direction } })
		local muzzle = muzzlePosition(origin + direction * 2)
		Effects.muzzleFlash(muzzle, direction, Color3.fromRGB(255, 170, 70))
		Sounds.play(weaponId, muzzle)
		lastShot = os.clock()
		lastPredicted = lastShot
		mag -= 1
		kick()
		refreshHud()
		if mag == 0 then
			task.delay(0.25, reload)
		end
	end

	local function streamTick()
		local origin, direction = CameraController.aimRay()
		Net.event("WeaponFire"):FireServer(weaponId, origin, { { direction = direction } })
		local used = math.max(1, math.floor(stats.rpm / 60 * STREAM_TICK + 0.5))
		mag = math.max(0, mag - used)
		lastShot = os.clock()
		lastPredicted = lastShot
		local muzzle = muzzlePosition(origin + direction * 2)
		Effects.flame(muzzle, direction, stats.range)
		Sounds.play(weaponId, muzzle)
		refreshHud()
	end

	local function firingLoop()
		if firing then
			return
		end
		firing = true
		Movement.setSprintBlocked(true)
		local interval = WeaponsConfig.interval(stats)
		while equipped and triggerHeld do
			if not canShoot() then
				if stats.mode ~= "Spin" and mag == 0 then
					reload()
				end
				break
			end
			local wait = interval - (os.clock() - lastShot)
			if stats.mode == "Spin" then
				spin = math.min(1, spin + 1 / 30 / (stats.spinUp or 0.5))
				if spin < 1 then
					task.wait(1 / 30)
					continue
				end
			end
			if stats.mode == "Stream" then
				wait = STREAM_TICK - (os.clock() - lastShot)
			end
			if wait > 0 then
				task.wait(wait)
				if not (equipped and triggerHeld) then
					break
				end
			end
			if stats.mode == "Stream" then
				streamTick()
			elseif stats.mode == "Burst" then
				for _ = 1, stats.burstCount or 3 do
					if not (equipped and canShoot()) then
						break
					end
					shoot()
					task.wait(interval)
				end
				task.wait(stats.burstDelay or 0.25)
				break
			elseif stats.mode == "Semi" then
				shoot()
				break
			elseif stats.mode == "Lobbed" then
				lob()
				break
			else
				shoot()
			end
		end
		firing = false
		spin = 0
		Movement.setSprintBlocked(false)
	end

	local item: Loadout.Item = {
		equip = function()
			equipped = true
			stats = Stats.weaponFor(player, weaponId)
			local classId = player:GetAttribute("Class")
			local accent = if Classes.isClassId(classId)
				then Classes.INFO[classId :: Classes.ClassId].color
				else Color3.new(1, 1, 1)
			Viewmodel.hold(Items.build(weaponId, accent), CFrame.identity, HOLDS[weaponId] or DEFAULT_HOLD)
			Viewmodel.play(function(alpha)
				local rise = 1 - alpha
				return CFrame.new(0, -0.8 * rise, 0) * CFrame.Angles(math.rad(-30) * rise, 0, 0)
			end, 0.25)
			syncFromServer()
			refreshHud()
		end,
		unequip = function()
			equipped = false
			triggerHeld = false
		end,
		fire = function(down)
			triggerHeld = down
			if down then
				task.spawn(firingLoop)
			end
		end,
		reload = reload,
	}
	return item
end
