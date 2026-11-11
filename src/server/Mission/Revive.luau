--!strict
-- What happens when crew members go down: bleed-out timers, teammate revives, dog tags carried
-- back to a resupply pod for a respawn, and failing the mission when nobody is left standing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Build)
local Classes = require(Shared.Config.Classes)
local PlayerConfig = require(Shared.Config.Player)
local WalkthroughConfig = require(Shared.Config.Walkthrough)

local Server = script.Parent.Parent
local Vitals = require(Server.Character.Vitals)
local Crew = require(script.Parent.Crew)
local Flow = require(script.Parent.Flow)
local Runtime = require(script.Parent.Runtime)

local Revive = {}

local bleedOutAt: { [Player]: number } = {}
local prompts: { [Player]: ProximityPrompt } = {}
-- Dog tag models lying in the cave, keyed by whose tag it is.
local tags: { [Player]: Model } = {}
-- Who is carrying whose tag.
local carrying: { [Player]: Player } = {}

local function checkWipe()
	if Flow.isOver() then
		return
	end
	-- The walkthrough gets players back up on its own instead of ending.
	local launch = Runtime.get().launch
	if #Crew.standing() == 0 and not launch.walkthrough then
		Flow.fail(if launch.partySize == 1 then "You went down" else "The whole crew went down")
	end
end

local function clearPrompt(player: Player)
	local prompt = prompts[player]
	if prompt then
		prompt:Destroy()
		prompts[player] = nil
	end
end

local dropTag: (owner: Player, position: Vector3) -> ()

local function pickUp(owner: Player, carrier: Player)
	if not Vitals.isAlive(carrier) or carrying[carrier] then
		return
	end
	local tag = tags[owner]
	if not tag then
		return
	end
	tag:Destroy()
	tags[owner] = nil
	carrying[carrier] = owner
	carrier:SetAttribute("CarryingTagOf", owner.UserId)
end

dropTag = function(owner: Player, position: Vector3)
	local classId = owner:GetAttribute("Class")
	local color = if Classes.isClassId(classId)
		then Classes.INFO[classId :: Classes.ClassId].color
		else Color3.new(1, 1, 1)
	local model = Build.model("DogTag")
	local plate = Build.part(model, {
		name = "Tag",
		size = Vector3.new(0.9, 1.3, 0.12),
		cframe = CFrame.new(position + Vector3.yAxis * 1.2) * CFrame.Angles(0, 0, math.rad(15)),
		color = Color3.fromRGB(200, 200, 210),
		material = Enum.Material.Metal,
		collide = false,
	})
	Build.part(model, {
		name = "Stripe",
		size = Vector3.new(0.92, 0.25, 0.14),
		cframe = plate.CFrame * CFrame.new(0, 0.3, 0),
		color = color,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	Build.light(plate, "PointLight", { Color = color, Range = 10, Brightness = 1.5, Shadows = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up tag"
	prompt.ObjectText = owner.DisplayName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	prompt.Triggered:Connect(function(carrier)
		pickUp(owner, carrier)
	end)
	model:SetAttribute("Owner", owner.UserId)
	model.Parent = Workspace
	tags[owner] = model
end

local function bleedOut(player: Player)
	bleedOutAt[player] = nil
	clearPrompt(player)
	player:SetAttribute("BleedOutAt", nil)
	player:SetAttribute("Downed", false)
	player:SetAttribute("Dead", true)
	local character = player.Character
	local root = character and character.PrimaryPart
	local position = if root then root.Position else Vector3.zero
	-- Anyone carrying a tag drops it where they fell.
	local carried = carrying[player]
	if carried then
		carrying[player] = nil
		player:SetAttribute("CarryingTagOf", nil)
		dropTag(carried, position)
	end
	dropTag(player, position)
	if character then
		character:Destroy()
	end
	player.Character = nil
	checkWipe()
end

-- Brings a downed player back up and clears their bleed-out timer and revive prompt.
local function standUp(player: Player)
	bleedOutAt[player] = nil
	player:SetAttribute("BleedOutAt", nil)
	clearPrompt(player)
	Vitals.revive(player, PlayerConfig.REVIVE_HEALTH_FRACTION)
end

local function onDowned(player: Player)
	if Flow.isOver() then
		return
	end
	local deadline = os.clock() + PlayerConfig.BLEED_OUT_SECONDS
	bleedOutAt[player] = deadline
	player:SetAttribute("BleedOutAt", Workspace:GetServerTimeNow() + PlayerConfig.BLEED_OUT_SECONDS)
	local root = player.Character and player.Character.PrimaryPart
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = PlayerConfig.REVIVE_SECONDS
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(reviver)
			if reviver ~= player and Vitals.isAlive(reviver) and Vitals.isDowned(player) then
				standUp(player)
			end
		end)
		prompts[player] = prompt
	end
	if Runtime.get().launch.walkthrough then
		-- The walkthrough's practice run puts players back on their feet after a moment.
		task.delay(WalkthroughConfig.SELF_REVIVE_SECONDS, function()
			if Vitals.isDowned(player) and not Flow.isOver() then
				standUp(player)
			end
		end)
	end
	checkWipe()
end

-- A carrier hands in a tag at a resupply pod; its owner respawns there.
function Revive.deliverTag(carrier: Player, at: Vector3): boolean
	local owner = carrying[carrier]
	if not owner or not Vitals.isAlive(carrier) or owner.Parent == nil then
		return false
	end
	carrying[carrier] = nil
	carrier:SetAttribute("CarryingTagOf", nil)
	task.spawn(Crew.spawn, owner, Crew.ringSpot(at, 1, 6))
	return true
end

function Revive.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function Revive.start()
	Vitals.onDowned(onDowned)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, deadline in bleedOutAt do
			if now >= deadline then
				bleedOut(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		bleedOutAt[player] = nil
		clearPrompt(player)
		local carried = carrying[player]
		if carried then
			carrying[player] = nil
			local root = player.Character and player.Character.PrimaryPart
			if root then
				dropTag(carried, root.Position)
			end
		end
		local tag = tags[player]
		if tag then
			tag:Destroy()
			tags[player] = nil
		end
		-- Leaving players stop counting; the rest may now be all down.
		task.defer(checkWipe)
	end)
end

return Revive
