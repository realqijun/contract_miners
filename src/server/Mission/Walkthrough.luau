--!strict
-- The guided walkthrough: takes the player through the basics in the fixed cave, one step at a
-- time. Each step waits on something the server sees for itself; only the camera switch, which
-- never leaves the client, is reported by it. The run pays no rewards.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Build)
local Kits = require(Shared.Config.Kits)
local MissionState = require(Shared.MissionState)
local Net = require(Shared.Net)
local Resources = require(Shared.Config.Resources)
local WalkthroughCave = require(Shared.Cave.WalkthroughCave)
local WalkthroughConfig = require(Shared.Config.Walkthrough)

local Server = script.Parent.Parent
local Surface = require(Server.Cave.Surface)
local Motion = require(Server.Character.Motion)
local Vitals = require(Server.Character.Vitals)
local Hive = require(Server.Enemies.Hive)
local Spawner = require(Server.Enemies.Spawner)
local Extraction = require(script.Parent.Extraction)
local Flow = require(script.Parent.Flow)
local Resupply = require(script.Parent.Resupply)

local Walkthrough = {}

local KEYS = MissionState.KEYS
local BEACON_COLOR = Color3.fromRGB(255, 176, 64)
local POLL_SECONDS = 0.2
-- Seconds a player must stand on the ledge for the climb to count.
local LEDGE_HOLD_SECONDS = 1

local current: WalkthroughConfig.Step? = nil
-- Things the current step is waiting for that arrive as events.
local cameraToggled = false
local resupplyCalled = false
local restocked = false

local function setStep(step: WalkthroughConfig.Step)
	current = step
	MissionState.set(KEYS.WalkthroughStep, step)
	MissionState.set(KEYS.WalkthroughIndex, table.find(WalkthroughConfig.STEPS, step))
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

-- Yields until `check` passes or the mission ends. Returns whether it passed.
local function waitUntil(check: () -> boolean): boolean
	while not Flow.isOver() do
		if check() then
			return true
		end
		task.wait(POLL_SECONDS)
	end
	return false
end

-- A glowing ring on the floor below `position` with an on-screen marker.
local function beacon(position: Vector3): BasePart
	local floor = Surface.floorBelow(position + Vector3.yAxis * 4, 24) or position
	local ring = Build.part(Workspace, {
		name = "WalkthroughBeacon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(7, 0.2, 0),
		cframe = CFrame.new(floor + Vector3.yAxis * 0.15),
		color = BEACON_COLOR,
		material = Enum.Material.Neon,
		transparency = 0.35,
		collide = false,
		castShadow = false,
	})
	ring.CanQuery = false
	ring.CanTouch = false
	ring:SetAttribute("MarkerLabel", "Here")
	ring:SetAttribute("MarkerColor", BEACON_COLOR)
	CollectionService:AddTag(ring, "Marker")
	return ring
end

local function near(player: Player, position: Vector3, radius: number): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local offset = root.Position - position
	return Vector2.new(offset.X, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= 8
end

local function reach(player: Player, position: Vector3, radius: number): boolean
	local ring = beacon(position)
	local passed = waitUntil(function()
		return near(player, position, radius)
	end)
	ring:Destroy()
	return passed
end

-- Standing on something whose top is at least `floorY`, not just passing through that height.
local function standingAbove(player: Player, floorY: number): boolean
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and humanoid) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local reach = root.Size.Y / 2 + humanoid.HipHeight + 1
	local ground = Workspace:Raycast(root.Position, Vector3.yAxis * -reach, params)
	return ground ~= nil and ground.Position.Y >= floorY
end

local function climb(player: Player, spots: WalkthroughCave.Spots): boolean
	local ring = beacon(spots.ledge)
	local since: number? = nil
	local passed = waitUntil(function()
		local onLedge = Vitals.isAlive(player)
			and near(player, spots.ledge, 14)
			and standingAbove(player, spots.ledgeFloorY)
		if not onLedge then
			since = nil
			return false
		end
		since = since or os.clock()
		return os.clock() - (since :: number) >= LEDGE_HOLD_SECONDS
	end)
	ring:Destroy()
	return passed
end

local function grenadeCharges(player: Player): number
	local kit = Kits.BY_CLASS[player:GetAttribute("Class") :: any]
	local charges = kit and player:GetAttribute("Charges_" .. kit.grenade)
	return if type(charges) == "number" then charges else 0
end

-- What each step waits for. Each returns false if the mission ended first.
local function stepRunners(player: Player, spots: WalkthroughCave.Spots): { [WalkthroughConfig.Step]: () -> boolean }
	local target = WalkthroughConfig.VOLTICITE_TARGET
	return {
		Move = function()
			return reach(player, spots.move, 6)
		end,
		Camera = function()
			cameraToggled = false
			return waitUntil(function()
				return cameraToggled
			end)
		end,
		Mine = function()
			return waitUntil(function()
				local carried = player:GetAttribute("Volticite") or 0
				return carried + (MissionState.get(KEYS.Deposited) or 0) >= target
			end)
		end,
		Deposit = function()
			return waitUntil(function()
				return (MissionState.get(KEYS.Deposited) or 0) >= target
			end)
		end,
		Tunnel = function()
			return reach(player, spots.tunnelEnd, 8)
		end,
		Climb = function()
			return climb(player, spots)
		end,
		Ferrin = function()
			return waitUntil(function()
				return (MissionState.get(KEYS.Ferrin) or 0) >= Resources.RESUPPLY_COST
			end)
		end,
		CallResupply = function()
			resupplyCalled = false
			return waitUntil(function()
				return resupplyCalled
			end)
		end,
		Restock = function()
			restocked = false
			return waitUntil(function()
				return restocked
			end)
		end,
		Grenade = function()
			local charges = grenadeCharges(player)
			Spawner.group(WalkthroughConfig.SWARM)
			return charges <= 0 or waitUntil(function()
				return grenadeCharges(player) < charges
			end)
		end,
		Swarm = function()
			return waitUntil(function()
				return Spawner.pending() == 0 and Hive.count() == 0
			end)
		end,
		Revive = function()
			task.wait(WalkthroughConfig.REVIVE_SECONDS)
			return not Flow.isOver()
		end,
		LiftPod = function()
			Extraction.call(spots.liftPod)
			return true
		end,
	}
end

-- Studio-only test hook: DevWalkthroughStep on Workspace starts the run at that step, with the
-- player moved to where it begins.
local function studioStartStep(): WalkthroughConfig.Step?
	local step = Workspace:GetAttribute("DevWalkthroughStep")
	if RunService:IsStudio() and type(step) == "string" and table.find(WalkthroughConfig.STEPS, step :: any) then
		return step :: WalkthroughConfig.Step
	end
	return nil
end

local function startAt(player: Player, spots: WalkthroughCave.Spots, step: WalkthroughConfig.Step)
	local index = table.find(WalkthroughConfig.STEPS, step) :: number
	local function after(other: WalkthroughConfig.Step): boolean
		return index > (table.find(WalkthroughConfig.STEPS, other) :: number)
	end
	local at = if after("Climb") then spots.upper elseif after("Tunnel") then spots.tunnelEnd else spots.move
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(at + Vector3.yAxis * 4))
		Motion.reset(player)
	end
	if step == "CallResupply" or step == "Restock" then
		MissionState.set(KEYS.Ferrin, Resources.RESUPPLY_COST)
	end
	if step == "Restock" then
		task.wait(1)
		Resupply.call(at + Vector3.new(6, 2, 0))
	end
end

local function run(player: Player, spots: WalkthroughCave.Spots)
	waitUntil(function()
		return Vitals.isAlive(player)
	end)
	local runners = stepRunners(player, spots)
	local first = studioStartStep()
	for _, step in WalkthroughConfig.STEPS do
		if first and step ~= first then
			continue
		elseif first then
			first = nil
			startAt(player, spots, step)
		end
		setStep(step)
		if not runners[step]() then
			return
		end
	end
end

function Walkthrough.start(spots: WalkthroughCave.Spots)
	MissionState.set(KEYS.Walkthrough, true)
	Net.event("WalkthroughAction").OnServerEvent:Connect(function(_player, action)
		if action == "CameraToggle" and current == "Camera" then
			cameraToggled = true
		end
	end)
	Resupply.onCalled(function()
		resupplyCalled = true
	end)
	Resupply.onRefill(function()
		restocked = true
	end)
	task.spawn(function()
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		run(player, spots)
	end)
end

return Walkthrough
