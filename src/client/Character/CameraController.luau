--!strict
-- First-person and over-the-shoulder third-person camera with mouse and gamepad look.
-- The character always faces the camera's yaw so aiming is identical in both modes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Input = require(script.Parent.Parent.Input)
local Settings = require(script.Parent.Parent.Settings)

local CameraController = {}

export type Mode = "First" | "Third"

local MOUSE_RADIANS_PER_PIXEL = math.rad(0.22)
local GAMEPAD_RADIANS_PER_SECOND = math.rad(220)
local GAMEPAD_DEADZONE = 0.15
local PITCH_LIMIT = math.rad(82)
local EYE_ABOVE_ROOT = 1.6
local CROUCH_DROP = 1.6
local SHOULDER_OFFSET = Vector3.new(2.4, 0.8, 8.5)
local COLLISION_RADIUS = 0.6

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local mode: Mode = "First"
local yaw, pitch = 0, 0
local crouchAmount = 0
local crouching = false
local enabled = true
local shakeTime, shakeDuration, shakeStrength = 0, 0, 0
local modeListeners: { (Mode) -> () } = {}

local function character(): (Model?, BasePart?, Humanoid?)
	local model = player.Character
	if not model then
		return nil, nil, nil
	end
	return model, model:FindFirstChild("HumanoidRootPart") :: BasePart?, model:FindFirstChildOfClass("Humanoid")
end

local function setCharacterVisible(model: Model, visible: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

local function ensureAlign(root: BasePart): AlignOrientation
	local align = root:FindFirstChild("FacingAlign") :: AlignOrientation?
	if align then
		return align
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = root
	local created = Instance.new("AlignOrientation")
	created.Name = "FacingAlign"
	created.Mode = Enum.OrientationAlignmentMode.OneAttachment
	created.Attachment0 = attachment
	created.RigidityEnabled = true
	created.Parent = root
	return created
end

UserInputService.InputChanged:Connect(function(input, processed)
	if not enabled or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local settings = Settings.get()
		local scale = MOUSE_RADIANS_PER_PIXEL * settings.mouseSensitivity * (camera.FieldOfView / 80)
		yaw -= input.Delta.X * scale
		pitch -= input.Delta.Y * scale * (if settings.invertY then -1 else 1)
		pitch = math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	end
end)

local function gamepadLook(dt: number)
	local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, input in state do
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			if stick.Magnitude > GAMEPAD_DEADZONE then
				-- Rescale past the deadzone and curve it for fine aim near the centre.
				local magnitude = (stick.Magnitude - GAMEPAD_DEADZONE) / (1 - GAMEPAD_DEADZONE)
				local curved = stick.Unit * magnitude * magnitude
				local settings = Settings.get()
				local rate = GAMEPAD_RADIANS_PER_SECOND * settings.gamepadSensitivity * dt
				yaw -= curved.X * rate
				pitch += curved.Y * rate * (if settings.invertY then -1 else 1)
				pitch = math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
			end
		end
	end
end

local function shakeOffset(dt: number): CFrame
	if shakeTime <= 0 then
		return CFrame.identity
	end
	shakeTime = math.max(0, shakeTime - dt)
	local strength = shakeStrength * (shakeTime / shakeDuration)
	local t = os.clock() * 37
	return CFrame.Angles(math.noise(t, 0.3) * strength, math.noise(0.7, t) * strength, 0)
end

local function update(dt: number)
	local model, root, humanoid = character()
	if not (model and root and humanoid) then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if enabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		gamepadLook(dt)
	end

	humanoid.AutoRotate = false
	local align = ensureAlign(root)
	align.CFrame = CFrame.Angles(0, yaw, 0)
	align.Enabled = humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Physics

	local crouchTarget = if crouching then 1 else 0
	crouchAmount += (crouchTarget - crouchAmount) * math.min(1, dt * 12)

	local eye = root.Position + Vector3.yAxis * (humanoid.HipHeight + EYE_ABOVE_ROOT - crouchAmount * CROUCH_DROP)
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local shake = shakeOffset(dt)

	if mode == "First" then
		camera.CFrame = CFrame.new(eye) * rotation * shake
		setCharacterVisible(model, false)
	else
		local desired = (CFrame.new(eye) * rotation * CFrame.new(SHOULDER_OFFSET)).Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model }
		local offset = desired - eye
		local hit = Workspace:Spherecast(eye, COLLISION_RADIUS, offset, params)
		local position = if hit then eye + offset.Unit * math.max(0.5, hit.Distance) else desired
		camera.CFrame = CFrame.new(position) * rotation * shake
		setCharacterVisible(model, true)
	end
	camera.FieldOfView = Settings.get().fieldOfView
end

function CameraController.start()
	RunService:BindToRenderStep("ContractMinersCamera", Enum.RenderPriority.Camera.Value + 1, update)
	Input.onBegan("CameraToggle", function()
		CameraController.setMode(if mode == "First" then "Third" else "First")
	end)
	player.CharacterAdded:Connect(function(model)
		-- Start looking the way the character spawned facing.
		local root = model:WaitForChild("HumanoidRootPart") :: BasePart
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = 0
	end)
end

function CameraController.getMode(): Mode
	return mode
end

function CameraController.setMode(value: Mode)
	if value == mode then
		return
	end
	mode = value
	for _, listener in modeListeners do
		task.spawn(listener, mode)
	end
end

function CameraController.onModeChanged(callback: (Mode) -> ())
	table.insert(modeListeners, callback)
end

-- Freezes or resumes look input and mouse lock (menus, results screen).
function CameraController.setEnabled(value: boolean)
	enabled = value
	if not value then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.setCrouching(value: boolean)
	crouching = value
end

function CameraController.getLook(): (number, number)
	return yaw, pitch
end

function CameraController.addLook(deltaYaw: number, deltaPitch: number)
	yaw += deltaYaw
	pitch = math.clamp(pitch + deltaPitch, -PITCH_LIMIT, PITCH_LIMIT)
end

-- The ray every weapon and tool aims along: from the camera through the crosshair.
function CameraController.aimRay(): (Vector3, Vector3)
	return camera.CFrame.Position, camera.CFrame.LookVector
end

function CameraController.shake(strength: number, duration: number)
	if strength * duration >= shakeStrength * shakeTime then
		shakeStrength, shakeDuration, shakeTime = strength, duration, duration
	end
end

return CameraController
