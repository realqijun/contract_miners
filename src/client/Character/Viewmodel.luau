--!strict
-- First-person viewmodel: the held item and a gloved forearm drawn in front of the camera,
-- with look sway, walk bob, and short procedural animations (swings, recoil, reloads).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.Build)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local CameraController = require(script.Parent.CameraController)

local Viewmodel = {}

-- Animation offset as a function of progress 0..1.
export type Animation = (alpha: number) -> CFrame

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Items are built at world size for third person; in first person the arm and item are shrunk
-- about the glove so they frame the view instead of filling it.
local VIEW_SCALE = 0.7

local holder: Model? = nil
local item: Model? = nil
local holdOffset = CFrame.new(1.1, -1.2, -2.2)
local swayYaw, swayPitch = 0, 0
local lastYaw, lastPitch = 0, 0
local bobTime = 0
local animation: Animation? = nil
local animationStart = 0
local animationDuration = 0
local recoil = CFrame.identity
local visible = true
-- Spinning parts of the held item (rotary barrels): each part's place in grip space, the axis they
-- turn about, and how fast they turn.
type Spinning = { part: BasePart, offset: CFrame }
local spinning: { Spinning } = {}
local spinAxis = CFrame.identity
local spinTarget, spinRate, spinAngle = 0, 0, 0
local SPIN_REVOLUTIONS_PER_SECOND = 4

local function buildArm(parent: Model, color: Color3)
	Build.part(parent, {
		name = "Sleeve",
		size = Vector3.new(0.5, 0.5, 2.2),
		cframe = CFrame.new(0.15, -0.35, 1.25) * CFrame.Angles(math.rad(12), 0, 0),
		color = color,
		material = Enum.Material.Fabric,
		collide = false,
		castShadow = false,
	})
	Build.part(parent, {
		name = "Cuff",
		size = Vector3.new(0.56, 0.56, 0.3),
		cframe = CFrame.new(0.12, -0.15, 0.25),
		color = Color3.fromRGB(44, 42, 52),
		material = Enum.Material.Metal,
		collide = false,
		castShadow = false,
	})
	Build.part(parent, {
		name = "Glove",
		size = Vector3.new(0.5, 0.48, 0.55),
		cframe = CFrame.new(0, -0.05, 0),
		color = Color3.fromRGB(58, 50, 44),
		material = Enum.Material.Leather,
		collide = false,
		castShadow = false,
	})
	for _, part in parent:GetChildren() do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function setTransparency(model: Instance, value: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = value
		end
	end
end

-- Shows `model` in hand (nil for empty hands). `gripOffset` places the item relative to the glove.
function Viewmodel.hold(model: Model?, gripOffset: CFrame?, offset: CFrame?)
	if item then
		item:Destroy()
		item = nil
	end
	animation = nil
	holdOffset = offset or CFrame.new(1.1, -1.2, -2.2)
	if not (model and holder) then
		return
	end
	local grip = model.PrimaryPart :: BasePart
	grip:SetAttribute("GripOffset", gripOffset or CFrame.identity)
	-- Viewmodel parts are posed every frame, never simulated.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CastShadow = false
		end
	end
	model:ScaleTo(VIEW_SCALE)
	model.Parent = holder
	item = model
	setTransparency(model, if visible then 0 else 1)
	table.clear(spinning)
	spinTarget, spinRate, spinAngle = 0, 0, 0
	local spinner = model:FindFirstChild("Spinner", true)
	if spinner and spinner:IsA("BasePart") then
		local gripFrame = grip.CFrame
		spinAxis = gripFrame:ToObjectSpace(CFrame.new(spinner.Position))
		local barrels = model:FindFirstChild("Barrels")
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part:GetAttribute("Spins") or (barrels and part:IsDescendantOf(barrels))) then
				table.insert(spinning, { part = part, offset = gripFrame:ToObjectSpace(part.CFrame) })
			end
		end
	end
end

-- Plays a procedural animation once over `duration` seconds.
function Viewmodel.play(clip: Animation, duration: number)
	animation = clip
	animationStart = os.clock()
	animationDuration = duration
end

-- Adds a recoil kick that settles back over time.
function Viewmodel.kick(offset: CFrame)
	recoil = recoil * offset
end

-- World CFrame of the item's muzzle or tip attachment, for tracers that start at the gun.
function Viewmodel.point(name: string): Vector3?
	if not item then
		return nil
	end
	local marker = item:FindFirstChild(name, true)
	if marker and marker:IsA("Attachment") then
		return marker.WorldPosition
	elseif marker and marker:IsA("BasePart") then
		return marker.Position
	end
	return nil
end

local function update(dt: number)
	local current = holder
	if not current then
		return
	end
	local shouldShow = CameraController.getMode() == "First" and player.Character ~= nil
	if shouldShow ~= visible then
		visible = shouldShow
		setTransparency(current, if visible then 0 else 1)
	end

	-- Sway lags behind look motion.
	local yaw, pitch = CameraController.getLook()
	local dYaw, dPitch = yaw - lastYaw, pitch - lastPitch
	lastYaw, lastPitch = yaw, pitch
	swayYaw = math.clamp(swayYaw * math.exp(-dt * 10) + dYaw * 0.6, -0.12, 0.12)
	swayPitch = math.clamp(swayPitch * math.exp(-dt * 10) + dPitch * 0.6, -0.12, 0.12)

	-- Bob while walking.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = if humanoid then humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed else 0
	bobTime += dt * speed * 0.55
	local bobAmount = math.min(speed / 20, 1)
	local bob = CFrame.new(math.sin(bobTime) * 0.06 * bobAmount, -math.abs(math.cos(bobTime)) * 0.06 * bobAmount, 0)

	recoil = recoil:Lerp(CFrame.identity, math.min(1, dt * 14))

	local animated = CFrame.identity
	if animation then
		local alpha = (os.clock() - animationStart) / animationDuration
		if alpha >= 1 then
			animation = nil
		else
			animated = animation(alpha)
		end
	end

	local hand = camera.CFrame
		* CFrame.Angles(swayPitch * 0.5, swayYaw * 0.5, swayYaw * -0.3)
		* holdOffset
		* bob
		* animated
		* recoil
	local arm = current:FindFirstChild("Arm") :: Model?
	if arm then
		arm:PivotTo(hand)
	end
	if item and item.PrimaryPart then
		local gripOffset = item.PrimaryPart:GetAttribute("GripOffset") :: CFrame?
		local gripFrame = hand * (gripOffset or CFrame.identity)
		item:PivotTo(gripFrame)
		if #spinning > 0 then
			-- Spin up and down smoothly rather than snapping.
			spinRate += (spinTarget - spinRate) * math.min(1, dt * 4)
			spinAngle = (spinAngle + spinRate * SPIN_REVOLUTIONS_PER_SECOND * math.pi * 2 * dt) % (math.pi * 2)
			local turn = spinAxis * CFrame.Angles(0, 0, spinAngle) * spinAxis:Inverse()
			for _, entry in spinning do
				entry.part.CFrame = gripFrame * turn * entry.offset
			end
		end
	end
end

-- How fast the held item's spinning parts turn, 0 (still) to 1 (full speed).
function Viewmodel.setSpin(amount: number)
	spinTarget = math.clamp(amount, 0, 1)
end

function Viewmodel.start()
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local arm = Build.model("Arm", model)
	buildArm(arm, Color3.new(1, 1, 1))
	local function recolor()
		local classId = player:GetAttribute("Class")
		if Classes.isClassId(classId) then
			(arm:FindFirstChild("Sleeve") :: BasePart).Color = Classes.INFO[classId :: Classes.ClassId].color
		end
	end
	recolor()
	player:GetAttributeChangedSignal("Class"):Connect(recolor)
	arm.PrimaryPart = arm:FindFirstChild("Glove") :: BasePart
	for _, part in arm:GetChildren() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	arm:ScaleTo(VIEW_SCALE)
	model.Parent = camera
	holder = model
	RunService:BindToRenderStep("ContractMinersViewmodel", Enum.RenderPriority.Camera.Value + 3, update)
end

return Viewmodel
