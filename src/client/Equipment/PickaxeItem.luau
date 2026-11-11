--!strict
-- The pickaxe in hand: hold fire to keep swinging, alt-fire for the heavy swing on its cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Items = require(Shared.Models.Items)
local Net = require(Shared.Net)
local PickaxeConfig = require(Shared.Config.Pickaxe)

local Client = script.Parent.Parent
local CameraController = require(Client.Character.CameraController)
local Viewmodel = require(Client.Character.Viewmodel)
local Effects = require(Client.Effects)
local Sounds = require(Client.Sounds)
local EquipmentHud = require(Client.UI.EquipmentHud)
local Loadout = require(script.Parent.Loadout)

local player = Players.LocalPlayer

-- Handle angled up and away from the camera, head leaning forward.
local GRIP = CFrame.Angles(math.rad(-25), math.rad(8), math.rad(-12))
local HOLD = CFrame.new(1.2, -1.6, -2.3)

local function swingClip(heavy: boolean): Viewmodel.Animation
	local reach = if heavy then 1.6 else 1
	return function(alpha)
		-- Wind up, strike through, then settle.
		local angle
		if alpha < 0.3 then
			angle = (alpha / 0.3) * math.rad(45) * reach
		elseif alpha < 0.55 then
			angle = math.rad(45) * reach - ((alpha - 0.3) / 0.25) * math.rad(100) * reach
		else
			angle = -math.rad(55) * reach * (1 - (alpha - 0.55) / 0.45)
		end
		return CFrame.new(0, 0, -math.max(0, -angle) * 0.4) * CFrame.Angles(angle, 0, 0)
	end
end

return function(): Loadout.Item
	local swinging = false
	local lastSwing = 0
	local lastHeavy = -math.huge
	local equipped = false
	local statusConnection: RBXScriptConnection? = nil

	-- The equipment panel shows the heavy swing's cooldown while the pickaxe is in hand.
	local function showStatus()
		local elapsed = os.clock() - lastHeavy
		local cooldown = math.clamp(elapsed / PickaxeConfig.HEAVY_COOLDOWN, 0, 1)
		EquipmentHud.show({
			name = "Pickaxe",
			bar = cooldown,
			note = if cooldown >= 1
				then "Heavy swing ready"
				else `Heavy swing in {math.ceil(PickaxeConfig.HEAVY_COOLDOWN - elapsed)}s`,
		})
	end

	local function predictImpact()
		local origin, direction = CameraController.aimRay()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, Workspace.CurrentCamera }
		local result = Workspace:Raycast(origin, direction * (PickaxeConfig.RANGE + 6), params)
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if result and head and (result.Position - head.Position).Magnitude <= PickaxeConfig.RANGE then
			Effects.impact(result.Position, result.Normal, "Rock")
			Sounds.play("PickaxeHit", result.Position)
			CameraController.shake(0.012, 0.12)
		end
	end

	local function strike(heavy: boolean)
		local origin, direction = CameraController.aimRay()
		lastSwing = os.clock()
		local duration = if heavy then PickaxeConfig.HEAVY_WINDUP + 0.35 else PickaxeConfig.SWING_INTERVAL
		Viewmodel.play(swingClip(heavy), duration)
		Net.event("PickaxeSwing"):FireServer(origin, direction, heavy)
		task.delay(if heavy then PickaxeConfig.HEAVY_WINDUP else duration * 0.4, function()
			if equipped then
				predictImpact()
			end
		end)
	end

	local function swingLoop()
		if swinging then
			return
		end
		swinging = true
		while swinging and equipped do
			local wait = PickaxeConfig.SWING_INTERVAL - (os.clock() - lastSwing)
			if wait > 0 then
				task.wait(wait)
			end
			if not (swinging and equipped) then
				break
			end
			strike(false)
		end
		swinging = false
	end

	local item: Loadout.Item = {
		equip = function()
			equipped = true
			local classId = player:GetAttribute("Class")
			local accent = if Classes.isClassId(classId)
				then Classes.INFO[classId :: Classes.ClassId].color
				else Color3.new(1, 1, 1)
			Viewmodel.hold(Items.build("Pickaxe", accent), GRIP, HOLD)
			showStatus()
			statusConnection = RunService.Heartbeat:Connect(showStatus)
		end,
		unequip = function()
			equipped = false
			swinging = false
			if statusConnection then
				statusConnection:Disconnect()
				statusConnection = nil
			end
		end,
		fire = function(down)
			if down then
				task.spawn(swingLoop)
			else
				swinging = false
			end
		end,
		altFire = function(down)
			local now = os.clock()
			if
				down
				and now - lastHeavy >= PickaxeConfig.HEAVY_COOLDOWN
				and now - lastSwing >= PickaxeConfig.SWING_INTERVAL
			then
				lastHeavy = now
				player:SetAttribute("HeavySwingReadyAt", Workspace:GetServerTimeNow() + PickaxeConfig.HEAVY_COOLDOWN)
				strike(true)
			end
		end,
	}
	return item
end
