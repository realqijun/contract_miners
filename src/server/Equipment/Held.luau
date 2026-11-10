--!strict
-- What each player visibly holds: the item model welded into their right hand, with the arm raised
-- so other players (and third-person views) see them carrying it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Kits = require(Shared.Config.Kits)
local Items = require(Shared.Models.Items)
local Net = require(Shared.Net)

local Held = {}

local SLOTS = { Primary = true, Secondary = true, Traversal = true, Support = true, Pickaxe = true }

-- Which item model a class shows for each slot. Filled in as items are added.
local itemFor: { [string]: (Classes.ClassId) -> Items.ItemId? } = {
	Pickaxe = function()
		return "Pickaxe"
	end,
	Primary = function(classId)
		return Kits.BY_CLASS[classId].primary
	end,
	Secondary = function(classId)
		return Kits.BY_CLASS[classId].secondary
	end,
	Traversal = function(classId)
		return Kits.BY_CLASS[classId].traversal
	end,
	Support = function(classId)
		return Kits.BY_CLASS[classId].support
	end,
}

-- Where the right hand is held, relative to the upper torso: out front, palm-down axis forward.
local HOLD_TARGET = CFrame.new(0.75, 0.05, -1.5) * CFrame.Angles(math.rad(90), 0, 0)
local GRIP_IN_HAND = CFrame.new(0, -0.15, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)

-- Poses the right arm out in front with inverse kinematics, layered over the avatar's animations.
local function raiseArm(character: Model, raised: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local upperArm = character:FindFirstChild("RightUpperArm")
	local hand = character:FindFirstChild("RightHand")
	if not (humanoid and torso and upperArm and hand) then
		return
	end
	local ik = humanoid:FindFirstChild("HoldIK") :: IKControl?
	if not ik then
		local target = Instance.new("Attachment")
		target.Name = "HoldTarget"
		target.CFrame = HOLD_TARGET
		target.Parent = torso
		local created = Instance.new("IKControl")
		created.Name = "HoldIK"
		created.Type = Enum.IKControlType.Transform
		created.ChainRoot = upperArm
		created.EndEffector = hand
		created.Target = target
		created.Weight = 1
		created.Parent = humanoid
		ik = created
	end
	(ik :: IKControl).Enabled = raised
end

function Held.show(player: Player, slot: string)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("HeldItem")
	if existing then
		existing:Destroy()
	end
	local classId = player:GetAttribute("Class")
	local pick = itemFor[slot]
	local id = if pick and Classes.isClassId(classId) then pick(classId :: Classes.ClassId) else nil
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	if not (id and hand) then
		raiseArm(character, false)
		return
	end
	local model = Items.build(id, Classes.INFO[classId :: Classes.ClassId].color)
	model.Name = "HeldItem"
	local grip = model.PrimaryPart :: BasePart
	model:PivotTo(hand.CFrame * GRIP_IN_HAND)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = grip
	weld.Parent = grip
	model.Parent = character
	raiseArm(character, true)
end

function Held.start()
	Net.event("EquipSlot").OnServerEvent:Connect(function(player, slot)
		if type(slot) == "string" and SLOTS[slot] then
			player:SetAttribute("HeldSlot", slot)
			Held.show(player, slot)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("HeldSlot", nil)
		end)
	end)
end

return Held
