--!strict
-- Riding Heavy Weapons cables: press interact near a cable to slide along it towards the end you
-- face; jump to let go. Anyone can ride, whatever their class.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ToolsConfig = require(ReplicatedStorage.Shared.Config.Tools)
local Input = require(script.Parent.Parent.Input)

local CableRider = {}

local GRAB_DISTANCE = 4.5
local HANG = 3.2

local player = Players.LocalPlayer

local riding: RBXScriptConnection? = nil

local function stop(root: BasePart?, humanoid: Humanoid?)
	if riding then
		riding:Disconnect()
		riding = nil
	end
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	if root then
		player:SetAttribute("CableReleasedAt", Workspace:GetServerTimeNow())
	end
end

local function nearestCable(position: Vector3): (Vector3?, Vector3?, number)
	local bestA, bestB, bestT, bestDistance = nil, nil, 0, GRAB_DISTANCE
	for _, cable in CollectionService:GetTagged("Cable") do
		local a = cable:GetAttribute("A")
		local b = cable:GetAttribute("B")
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local ab = b - a
			local t = math.clamp((position + Vector3.yAxis * HANG - a):Dot(ab) / ab:Dot(ab), 0, 1)
			local distance = (a + ab * t - (position + Vector3.yAxis * HANG)).Magnitude
			if distance < bestDistance then
				bestA, bestB, bestT, bestDistance = a, b, t, distance
			end
		end
	end
	return bestA, bestB, bestT
end

local function ride()
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if riding or not (root and humanoid) or player:GetAttribute("Downed") == true then
		return
	end
	local a, b, t = nearestCable(root.Position)
	if not (a and b) then
		return
	end
	-- Head for whichever end the camera faces.
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local towardsB = (b - a).Unit:Dot(look) >= 0
	local from, to = if towardsB then a else b, if towardsB then b else a
	local length = (to - from).Magnitude
	local travelled = if towardsB then t * length else (1 - t) * length
	humanoid.PlatformStand = true
	local speed = ToolsConfig.TOOLS.CableLauncher.rideSpeed
	riding = RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt
		if travelled >= length - 1 or humanoid.Health <= 0 or player:GetAttribute("Downed") == true then
			stop(root, humanoid)
			return
		end
		local point = from + (to - from).Unit * travelled - Vector3.yAxis * HANG
		root.CFrame = CFrame.lookAlong(point, Vector3.new(to.X - from.X, 0, to.Z - from.Z))
		root.AssemblyLinearVelocity = (to - from).Unit * speed
	end)
	local jump
	jump = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump and riding then
			jump:Disconnect()
			stop(root, humanoid)
		end
	end)
end

function CableRider.start()
	Input.onBegan("Interact", ride)
end

return CableRider
