--!strict
-- Places Volticite veins, Ferrin nodes and health crystals in the cave, and handles mining them
-- and depositing Volticite at the Dropcan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Cave.Layout)
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)
local Resources = require(Shared.Config.Resources)

local Server = script.Parent.Parent
local Surface = require(Server.Cave.Surface)
local Minerals = require(Server.Models.Minerals)
local Vitals = require(Server.Character.Vitals)
local Runtime = require(script.Parent.Runtime)

local Deposits = {}

local KEYS = MissionState.KEYS
local MIN_SPACING = 9
local DROPCAN_CLEARANCE = 14

local folder: Folder

local placed: { Vector3 } = {}

local function spacedFrom(position: Vector3, clearOf: Vector3): boolean
	if (position - clearOf).Magnitude < DROPCAN_CLEARANCE then
		return false
	end
	for _, other in placed do
		if (position - other).Magnitude < MIN_SPACING then
			return false
		end
	end
	return true
end

-- Finds a free surface spot in `cavern`, trying a few random rays.
local function findSpot(
	rng: Random,
	cavern: Layout.Cavern,
	kinds: { [Surface.Kind]: boolean },
	dropcan: Vector3
): Surface.Hit?
	for _ = 1, 12 do
		local hit = Surface.scatter(rng, cavern, 1, kinds)[1]
		if hit and spacedFrom(hit.position, dropcan) then
			table.insert(placed, hit.position)
			return hit
		end
	end
	return nil
end

local function weightedCavern(
	rng: Random,
	caverns: { Layout.Cavern },
	weights: { number },
	total: number
): Layout.Cavern
	local roll = rng:NextNumber(0, total)
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return caverns[index]
		end
	end
	return caverns[#caverns]
end

local function placeVolticite(rng: Random, world: Runtime.World, dropcan: Vector3)
	local target = Missions.MINING_TARGET[world.launch.partySize]
	local total = math.ceil(target * Missions.MINING_SURPLUS)
	local veins = math.ceil(total / Resources.VOLTICITE_PER_VEIN)
	-- Bigger caverns hold more; the landing cavern holds little so the team has to explore.
	local weights, weightTotal = {}, 0
	for index, cavern in world.layout.caverns do
		local volume = cavern.radii.X * cavern.radii.Y * cavern.radii.Z
		local weight = if index == world.layout.startCavern then volume * 0.15 else volume
		weights[index] = weight
		weightTotal += weight
	end
	local everywhere = { Wall = true, Ceiling = true, Floor = true }
	local remaining = total
	local attempts = 0
	while remaining > 0 and attempts < veins * 8 do
		attempts += 1
		local cavern = weightedCavern(rng, world.layout.caverns, weights, weightTotal)
		local spot = findSpot(rng, cavern, everywhere, dropcan)
		if spot then
			local amount = math.min(Resources.VOLTICITE_PER_VEIN, remaining)
			Minerals.volticite(folder, spot.position, spot.normal, rng, amount)
			remaining -= amount
		end
	end
	MissionState.set(KEYS.Target, target)
	MissionState.set(KEYS.Deposited, 0)
end

local function placePerCavern(rng: Random, world: Runtime.World, dropcan: Vector3)
	local walls = { Wall = true, Floor = true }
	local low = { Floor = true, Wall = true }
	for _, cavern in world.layout.caverns do
		local ferrinRange = Resources.FERRIN_NODES_PER_CAVERN
		for _ = 1, rng:NextInteger(ferrinRange[1], ferrinRange[2]) do
			local spot = findSpot(rng, cavern, walls, dropcan)
			if spot then
				Minerals.ferrin(folder, spot.position, spot.normal, rng, Resources.FERRIN_PER_NODE)
			end
		end
		local healthRange = Resources.HEALTH_CRYSTALS_PER_CAVERN
		for _ = 1, rng:NextInteger(healthRange[1], healthRange[2]) do
			local spot = findSpot(rng, cavern, low, dropcan)
			if spot then
				Minerals.health(folder, spot.position, spot.normal, rng)
			end
		end
	end
end

local function updateDropcanDisplay()
	local world = Runtime.get()
	if world.launch.missionType == "Mining" then
		local deposited = MissionState.get(KEYS.Deposited) or 0
		local target = MissionState.get(KEYS.Target) or 0
		world.dropcan.setDisplay(`VOLTICITE\n{deposited} / {target}`)
	else
		world.dropcan.setDisplay("STANDING BY")
	end
end

local function setupDepositPrompt(world: Runtime.World)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = "Deposit Volticite"
	prompt.ObjectText = "Dropcan"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = world.dropcan.depositPoint
	prompt.Triggered:Connect(function(player)
		if not Vitals.isAlive(player) then
			return
		end
		local carried = player:GetAttribute("Volticite") or 0
		if carried <= 0 then
			return
		end
		player:SetAttribute("Volticite", 0)
		MissionState.set(KEYS.Deposited, (MissionState.get(KEYS.Deposited) or 0) + carried)
		player:SetAttribute("Delivered", (player:GetAttribute("Delivered") or 0) + carried)
	end)
end

function Deposits.populate()
	local world = Runtime.get()
	folder = Instance.new("Folder")
	folder.Name = "Minerals"
	folder.Parent = Workspace
	local rng = Random.new(world.launch.seed * 7 + 3)
	local dropcan = world.dropcan.model:GetPivot().Position
	if world.launch.missionType == "Mining" then
		placeVolticite(rng, world, dropcan)
		setupDepositPrompt(world)
	end
	placePerCavern(rng, world, dropcan)
	MissionState.set(KEYS.Ferrin, 0)
	MissionState.observe(KEYS.Deposited, updateDropcanDisplay)
end

-- The mineral Model a hit part belongs to, if any.
function Deposits.mineralOf(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model.Parent == folder and model:GetAttribute("Kind") then
		return model
	end
	return nil
end

-- One pickaxe strike on a deposit. Returns the kind and amount gathered.
function Deposits.strike(player: Player, mineral: Model): (Resources.Kind?, number)
	local kind = mineral:GetAttribute("Kind") :: Resources.Kind
	local remaining = mineral:GetAttribute("Remaining") :: number
	if remaining <= 0 then
		return nil, 0
	end
	if kind == "Volticite" then
		local amount = math.min(Resources.VOLTICITE_PER_HIT, remaining)
		player:SetAttribute("Volticite", (player:GetAttribute("Volticite") or 0) + amount)
		Minerals.setRemaining(mineral, remaining - amount)
		return kind, amount
	elseif kind == "Ferrin" then
		local amount = math.min(Resources.FERRIN_PER_HIT, remaining)
		MissionState.set(KEYS.Ferrin, (MissionState.get(KEYS.Ferrin) or 0) + amount)
		Minerals.setRemaining(mineral, remaining - amount)
		return kind, amount
	else
		Vitals.heal(player, Resources.HEALTH_PER_CRYSTAL)
		Minerals.setRemaining(mineral, 0)
		return kind, Resources.HEALTH_PER_CRYSTAL
	end
end

return Deposits
