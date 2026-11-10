--!strict
-- Resupply pods bought with the team's Ferrin. A pod drills down through the rock to the pinged
-- spot, crushes any Vrill beneath it, and gives each crew member one refill of ammo and health.
-- Carriers hand in dog tags here to bring a teammate back.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Glide = require(Shared.Glide)
local MissionState = require(Shared.MissionState)
local Resources = require(Shared.Config.Resources)

local Server = script.Parent.Parent
local Digging = require(Server.Cave.Digging)
local Surface = require(Server.Cave.Surface)
local Vitals = require(Server.Character.Vitals)
local Explosions = require(Server.Combat.Explosions)
local Weapons = require(Server.Equipment.Weapons)
local ResupplyPod = require(Server.Models.ResupplyPod)
local Revive = require(script.Parent.Revive)

local Resupply = {}

local KEYS = MissionState.KEYS
local DROP_HEIGHT = 60
local DROP_SECONDS = 2.4

local refillListeners: { (Player) -> () } = {}
local calledListeners: { () -> () } = {}

-- Called with each player who takes a refill, so tools and grenades can restock too.
function Resupply.onRefill(callback: (Player) -> ())
	table.insert(refillListeners, callback)
end

-- Called whenever a pod is bought.
function Resupply.onCalled(callback: () -> ())
	table.insert(calledListeners, callback)
end

local function setupPrompts(model: Model, body: BasePart)
	local taken: { [Player]: boolean } = {}
	local refill = Instance.new("ProximityPrompt")
	refill.Name = "RefillPrompt"
	refill.ActionText = "Resupply"
	refill.ObjectText = "Ammo and health"
	refill.HoldDuration = 1
	refill.MaxActivationDistance = 9
	refill.RequiresLineOfSight = false
	refill.Parent = body
	refill.Triggered:Connect(function(player)
		if taken[player] or not Vitals.isAlive(player) then
			return
		end
		taken[player] = true
		Weapons.resupply(player)
		Vitals.restore(player)
		for _, listener in refillListeners do
			task.spawn(listener, player)
		end
		local remaining = 0
		for _, other in Players:GetPlayers() do
			if not taken[other] then
				remaining += 1
			end
		end
		model:SetAttribute("Remaining", remaining)
	end)

	local tag = Instance.new("ProximityPrompt")
	tag.Name = "TagPrompt"
	tag.ActionText = "Return tag"
	tag.ObjectText = "Bring a teammate back"
	tag.HoldDuration = 1
	tag.MaxActivationDistance = 9
	tag.RequiresLineOfSight = false
	tag.UIOffset = Vector2.new(0, 70)
	tag.Enabled = false
	tag.Parent = body
	tag.Triggered:Connect(function(player)
		Revive.deliverTag(player, body.Position)
	end)
	-- The tag prompt is only offered while someone carries a tag.
	local function refreshTag()
		local anyone = false
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("CarryingTagOf") ~= nil then
				anyone = true
			end
		end
		tag.Enabled = anyone
	end
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("CarryingTagOf"):Connect(refreshTag)
	end
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("CarryingTagOf"):Connect(refreshTag)
	end)
end

-- Spends Ferrin and drops a pod at `position`. Returns false if the team cannot afford it.
function Resupply.call(position: Vector3): boolean
	local pool = MissionState.get(KEYS.Ferrin) or 0
	if pool < Resources.RESUPPLY_COST then
		return false
	end
	local floor = Surface.floorBelow(position + Vector3.yAxis * 3, 12)
	if not floor then
		return false
	end
	MissionState.set(KEYS.Ferrin, pool - Resources.RESUPPLY_COST)
	for _, listener in calledListeners do
		task.spawn(listener)
	end
	-- Drill a shaft for it so it visibly comes through the ceiling.
	local top = floor + Vector3.yAxis * DROP_HEIGHT
	Digging.capsule(floor + Vector3.yAxis * 6, top, 3.4)
	local model, body = ResupplyPod.build(CFrame.new(floor))
	local landed = model:GetPivot()
	model:PivotTo(landed + Vector3.yAxis * DROP_HEIGHT)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:SetAttribute("Remaining", #Players:GetPlayers())
	model.Parent = Workspace
	Glide.move(model, landed, DROP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
		Explosions.detonate({ position = floor + Vector3.yAxis, radius = 6, damage = 400, style = "Blast" })
		setupPrompts(model, body)
		model:SetAttribute("MarkerLabel", "Resupply")
		model:SetAttribute("MarkerColor", Color3.fromRGB(120, 255, 170))
		CollectionService:AddTag(model, "Marker")
	end)
	return true
end

return Resupply
