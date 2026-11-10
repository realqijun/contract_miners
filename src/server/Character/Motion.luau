--!strict
-- The server's watch over crew movement. Characters are simulated by their owners' clients, so
-- the server samples where each crew root is and applies fall damage and a speed check itself.
-- Grapple pulls and cable rides are recognised from server-side facts (when the grapple fired,
-- where the cables are) rather than anything the client reports.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local ToolsConfig = require(ReplicatedStorage.Shared.Config.Tools)
local MotionRules = require(script.Parent.MotionRules)
local Vitals = require(script.Parent.Vitals)

local Motion = {}

-- Fast enough that the top of a fall is caught to within a stud or so.
local SAMPLE_SECONDS = 1 / 30
-- How far below the root's bottom the ground may be for the character to count as standing.
local GROUND_REACH = 1.5
-- Still falling faster than this means the next sample will be the landing.
local LANDED_SPEED = 8
-- One speed-check warning per player in this many seconds keeps the log readable.
local WARN_INTERVAL = 10

type Watched = { character: Model, track: MotionRules.Track, warnedAt: number }

local watched: { [Player]: Watched } = {}

local function nearCable(position: Vector3): boolean
	local hold = position + Vector3.yAxis * ToolsConfig.CABLE_HANG
	for _, cable in CollectionService:GetTagged("Cable") do
		local a = cable:GetAttribute("A")
		local b = cable:GetAttribute("B")
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local ab = b - a
			local t = math.clamp((hold - a):Dot(ab) / ab:Dot(ab), 0, 1)
			-- A little extra reach covers the delay before the server sees the rider move.
			if (a + ab * t - hold).Magnitude <= ToolsConfig.CABLE_GRAB_DISTANCE + 1.5 then
				return true
			end
		end
	end
	return false
end

local function grappling(player: Player): boolean
	local at = player:GetAttribute("GrappledAt")
	return type(at) == "number" and Workspace:GetServerTimeNow() - at <= PlayerConfig.GRAPPLE_GRACE_SECONDS
end

local function grounded(character: Model, root: BasePart, humanoid: Humanoid): boolean
	if root.AssemblyLinearVelocity.Y < -LANDED_SPEED then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local reach = root.Size.Y / 2 + humanoid.HipHeight + GROUND_REACH
	return Workspace:Raycast(root.Position, Vector3.yAxis * -reach, params) ~= nil
end

local function sample(player: Player, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and humanoid) or not CollectionService:HasTag(character, "Crew") then
		watched[player] = nil
		return
	end
	local entry = watched[player]
	if not entry or entry.character ~= character then
		entry = { character = character, track = MotionRules.new(root.Position, now), warnedAt = -math.huge }
		watched[player] = entry
	end
	local track = entry.track
	if not Vitals.isAlive(player) then
		-- Downed characters are moved by nobody; start fresh once they are back up.
		track.peakY = nil
		track.anchor = root.Position
		track.checkedAt = now
		return
	end
	local supported = grappling(player) or nearCable(root.Position)
	local damage = MotionRules.fall(track, root.Position.Y, grounded(character, root, humanoid), supported)
	if damage > 0 then
		Vitals.damage(player, damage)
	end
	if not MotionRules.checkSpeed(track, root.Position, now, PlayerConfig.SPRINT_SPEED, supported) then
		if now - entry.warnedAt > WARN_INTERVAL then
			entry.warnedAt = now
			warn(`Motion: {player.Name} moved faster than allowed; returning them to their last position`)
		end
		local back = track.anchor
		character:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
		track.peakY = nil
	end
end

-- Forgets where a character was, after the server itself moved it.
function Motion.reset(player: Player)
	watched[player] = nil
end

function Motion.start()
	Players.PlayerRemoving:Connect(function(player)
		watched[player] = nil
	end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < SAMPLE_SECONDS then
			return
		end
		accumulated %= SAMPLE_SECONDS
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			sample(player, now)
		end
	end)
end

return Motion
