--!strict
-- A traversal or support tool in hand. The server builds and damages; this side sends uses,
-- shows charges and heat, draws the cutter beam, and moves the player for the grapple.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Items = require(Shared.Models.Items)
local Net = require(Shared.Net)
local Stats = require(Shared.Stats)

local Client = script.Parent.Parent
local CameraController = require(Client.Character.CameraController)
local Viewmodel = require(Client.Character.Viewmodel)
local Effects = require(Client.Effects)
local EquipmentHud = require(Client.UI.EquipmentHud)
local Loadout = require(script.Parent.Loadout)

local player = Players.LocalPlayer

local HOLD = CFrame.new(1.0, -1.25, -1.9)
-- Tools fired repeatedly while the trigger is held.
local HELD_TOOLS = { FoamProjector = true, PlasmaCutter = true }

local function aimHit(range: number): RaycastResult?
	local origin, direction = CameraController.aimRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { Workspace.CurrentCamera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, name in { "Effects", "Shields" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(origin, direction * (range + 12), params)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if result and head and (result.Position - head.Position).Magnitude <= range then
		return result
	end
	return nil
end

-- Reels the character towards `point`, then lets go.
local function pull(point: Vector3, speed: number)
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local offset = point - root.Position
		if offset.Magnitude < 3.5 or os.clock() - started > 1.4 or player:GetAttribute("Downed") == true then
			connection:Disconnect()
			-- A little hop at the end so players land on ledges instead of sliding off.
			root.AssemblyLinearVelocity = offset.Unit * 8 + Vector3.yAxis * 18
			return
		end
		root.AssemblyLinearVelocity = offset.Unit * speed
	end)
end

return function(toolId: string): Loadout.Item
	local stats = Stats.toolFor(player, toolId)
	local equipped = false
	local triggerHeld = false
	local lastUse = 0
	local beam: Part? = nil

	local function charges(): number?
		if stats.charges == 0 then
			return nil
		end
		local value = player:GetAttribute("Charges_" .. toolId)
		return if type(value) == "number" then value else stats.charges
	end

	local function refreshHud()
		if not equipped then
			return
		end
		local heat = player:GetAttribute("Heat_PlasmaCutter")
		local note: string? = nil
		if toolId == "SatchelCharge" and (player:GetAttribute("SatchelsPlaced") or 0) > 0 then
			note = "FIRE AGAIN TO DETONATE"
		elseif toolId == "PlasmaCutter" and type(heat) == "number" and heat >= 0.99 then
			note = "OVERHEATED"
		elseif charges() == 0 then
			note = "EMPTY"
		end
		EquipmentHud.show({
			name = stats.displayName,
			primary = charges(),
			bar = if toolId == "PlasmaCutter" then (if type(heat) == "number" then heat else 0) else nil,
			barColor = Color3.fromRGB(255, 120, 60),
			note = note,
		})
	end
	for _, attribute in { "Charges_" .. toolId, "Heat_PlasmaCutter", "SatchelsPlaced" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshHud)
	end

	local function send(action: string)
		local origin, direction = CameraController.aimRay()
		Net.event("ToolUse"):FireServer(toolId, action, origin, direction)
	end

	local function clearBeam()
		if beam then
			beam:Destroy()
			beam = nil
		end
	end

	local function drawCutter()
		local origin, direction = CameraController.aimRay()
		local hit = aimHit(stats.range)
		local from = Viewmodel.point("Muzzle") or origin
		local to = if hit then hit.Position else origin + direction * stats.range
		if not beam then
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(255, 130, 70)
			local light = Instance.new("PointLight")
			light.Color = part.Color
			light.Range = 14
			light.Brightness = 2
			light.Parent = part
			part.Parent = Workspace.CurrentCamera
			beam = part
		end
		local length = (to - from).Magnitude
		local current = beam :: Part
		current.Size = Vector3.new(0.25, 0.25, length)
		current.CFrame = CFrame.lookAt((from + to) / 2, to)
		if hit and math.random() < 0.5 then
			Effects.impact(hit.Position, hit.Normal, "Rock")
		end
	end

	local function useOnce()
		local now = os.clock()
		if now - lastUse < stats.cooldown then
			return
		end
		local available = charges()
		if available == 0 then
			return
		end
		if toolId == "GrappleLine" then
			local hit = aimHit(stats.range)
			if not hit then
				return
			end
			lastUse = now
			send("Use")
			pull(hit.Position + hit.Normal * 2, stats.pullSpeed)
			Effects.rope(Viewmodel.point("Muzzle") or CameraController.aimRay(), hit.Position)
			return
		end
		if toolId == "SatchelCharge" and (player:GetAttribute("SatchelsPlaced") or 0) > 0 then
			lastUse = now
			send("Detonate")
			return
		end
		lastUse = now
		send("Use")
		Viewmodel.kick(CFrame.new(0, 0, 0.12) * CFrame.Angles(math.rad(4), 0, 0))
	end

	local function holdLoop()
		while equipped and triggerHeld do
			local heat = player:GetAttribute("Heat_PlasmaCutter")
			if toolId == "PlasmaCutter" and type(heat) == "number" and heat >= 0.99 then
				clearBeam()
				task.wait(0.1)
				continue
			end
			useOnce()
			if toolId == "PlasmaCutter" then
				drawCutter()
			end
			task.wait(stats.cooldown)
		end
		clearBeam()
	end

	local item: Loadout.Item = {
		equip = function()
			equipped = true
			stats = Stats.toolFor(player, toolId)
			local classId = player:GetAttribute("Class")
			local accent = if Classes.isClassId(classId)
				then Classes.INFO[classId :: Classes.ClassId].color
				else Color3.new(1, 1, 1)
			Viewmodel.hold(Items.build(toolId, accent), CFrame.identity, HOLD)
			refreshHud()
		end,
		unequip = function()
			equipped = false
			triggerHeld = false
			clearBeam()
		end,
		fire = function(down)
			triggerHeld = down
			if not down then
				return
			end
			if HELD_TOOLS[toolId] then
				task.spawn(holdLoop)
			else
				useOnce()
			end
		end,
		altFire = function(down)
			if down and toolId == "SatchelCharge" then
				send("Detonate")
			end
		end,
	}
	return item
end
