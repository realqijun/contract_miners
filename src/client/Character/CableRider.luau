--!strict
-- Riding Heavy Weapons cables: press interact near a cable to slide along it towards the end you
-- face; jump to let go, or ride to the end to step off onto whatever it is anchored to.
-- Anyone can ride, whatever their class.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CableReach = require(ReplicatedStorage.Shared.CableReach)
local ToolsConfig = require(ReplicatedStorage.Shared.Config.Tools)
local Input = require(script.Parent.Parent.Input)

local CableRider = {}

local GRAB_DISTANCE = ToolsConfig.CABLE_GRAB_DISTANCE
local HANG = ToolsConfig.CABLE_HANG
-- Over the last stretch of a ride the rider climbs from hanging under the line to standing a
-- little above its end, then hops on towards the anchor, so a cable up to a ledge lands them on it.
local END_STRETCH = 5
local END_RISE = 3
local HOP_FORWARD = 14
local HOP_UP = 30
-- The Humanoid stays aside for the hop, or its air control would brake it straight away.
local HOP_SECONDS = 0.35

local player = Players.LocalPlayer

local riding: RBXScriptConnection? = nil

local function stop(humanoid: Humanoid?)
	if riding then
		riding:Disconnect()
		riding = nil
	end
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function dismount(root: BasePart, humanoid: Humanoid, along: Vector3)
	if riding then
		riding:Disconnect()
		riding = nil
	end
	local flat = Vector3.new(along.X, 0, along.Z)
	local forward = if flat.Magnitude > 0.1 then flat.Unit * HOP_FORWARD else Vector3.zero
	root.AssemblyLinearVelocity = forward + Vector3.yAxis * HOP_UP
	task.delay(HOP_SECONDS, function()
		stop(humanoid)
	end)
end

-- The cable within reach of the body, its ends, where along it the reach is closest, and its speed.
local function nearestCable(position: Vector3): (Vector3?, Vector3?, number, number)
	local bestA, bestB, bestT, bestDistance, bestSpeed = nil, nil, 0, GRAB_DISTANCE, 0
	for _, cable in CollectionService:GetTagged("Cable") do
		local a = cable:GetAttribute("A")
		local b = cable:GetAttribute("B")
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local distance, t = CableReach.measure(position, a, b)
			if distance < bestDistance then
				local speed = cable:GetAttribute("RideSpeed")
				bestA, bestB, bestT, bestDistance = a, b, t, distance
				bestSpeed = if type(speed) == "number" then speed else ToolsConfig.TOOLS.CableLauncher.rideSpeed
			end
		end
	end
	return bestA, bestB, bestT, bestSpeed
end

local function ride()
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if riding or not (root and humanoid) or player:GetAttribute("Downed") == true then
		return
	end
	local a, b, t, speed = nearestCable(root.Position)
	if not (a and b) then
		return
	end
	-- Head for whichever end the camera faces.
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local towardsB = (b - a).Unit:Dot(look) >= 0
	local from, to = if towardsB then a else b, if towardsB then b else a
	local length = (to - from).Magnitude
	local travelled = if towardsB then t * length else (1 - t) * length
	-- Over the first stretch the rider settles from wherever they caught the line (standing on
	-- its top end, say) to hanging under it.
	local grabbedAt = travelled
	local caught = from + (to - from).Unit * travelled
	local startHang = caught.Y - root.Position.Y
	humanoid.PlatformStand = true
	riding = RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt
		if humanoid.Health <= 0 or player:GetAttribute("Downed") == true then
			stop(humanoid)
			return
		elseif travelled >= length then
			dismount(root, humanoid, to - from)
			return
		end
		local remaining = length - travelled
		local settle = math.clamp((travelled - grabbedAt) / END_STRETCH, 0, 1)
		local climb = math.clamp(1 - remaining / END_STRETCH, 0, 1)
		local hang = startHang + (HANG - startHang) * settle
		hang += (-END_RISE - hang) * climb
		local point = from + (to - from).Unit * travelled - Vector3.yAxis * hang
		root.CFrame = CFrame.lookAlong(point, Vector3.new(to.X - from.X, 0, to.Z - from.Z))
		root.AssemblyLinearVelocity = (to - from).Unit * speed
	end)
	local jump
	jump = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump and riding then
			jump:Disconnect()
			stop(humanoid)
		end
	end)
end

function CableRider.start()
	Input.onBegan("Interact", ride)
end

return CableRider
