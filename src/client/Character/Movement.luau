--!strict
-- Sprint and crouch for the local character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local Input = require(script.Parent.Parent.Input)
local CameraController = require(script.Parent.CameraController)

local Movement = {}

local player = Players.LocalPlayer

local crouching = false
-- Set by weapons while firing; sprinting stops whenever the player shoots.
local sprintBlocked = false

local function humanoid(): Humanoid?
	local model = player.Character
	return if model then model:FindFirstChildOfClass("Humanoid") else nil
end

local function isSprinting(target: Humanoid): boolean
	if crouching or sprintBlocked or not Input.isHeld("Sprint") then
		return false
	end
	-- Only while moving forward relative to where the character faces.
	local root = target.RootPart
	if not root or target.MoveDirection.Magnitude < 0.1 then
		return false
	end
	return target.MoveDirection:Dot(root.CFrame.LookVector) > 0.5
end

function Movement.start()
	Input.onBegan("Crouch", function()
		crouching = not crouching
		CameraController.setCrouching(crouching)
	end)
	Input.onBegan("Sprint", function()
		if crouching then
			crouching = false
			CameraController.setCrouching(false)
		end
	end)
	player.CharacterAdded:Connect(function()
		crouching = false
		CameraController.setCrouching(false)
	end)
	RunService.Heartbeat:Connect(function()
		local target = humanoid()
		if not target or target.Health <= 0 then
			return
		end
		local speed = PlayerConfig.WALK_SPEED
		if crouching then
			speed = PlayerConfig.CROUCH_SPEED
		elseif isSprinting(target) then
			speed = PlayerConfig.SPRINT_SPEED
		end
		local slow = player:GetAttribute("SpeedMultiplier")
		if player:GetAttribute("Downed") == true then
			speed = 0
		end
		target.WalkSpeed = speed * (if type(slow) == "number" then slow else 1)
		target.UseJumpPower = true
		target.JumpPower = if crouching then 0 else PlayerConfig.JUMP_POWER
	end)
end

function Movement.setSprintBlocked(value: boolean)
	sprintBlocked = value
end

function Movement.isCrouching(): boolean
	return crouching
end

return Movement
