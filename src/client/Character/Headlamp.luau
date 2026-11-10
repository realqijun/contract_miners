--!strict
-- The local player's headlamp follows the camera so it lights exactly where they aim.
-- The helmet lamp other players see is hidden locally to avoid double lighting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local CameraController = require(script.Parent.CameraController)

local Headlamp = {}

local player = Players.LocalPlayer

function Headlamp.start()
	local holder = Instance.new("Part")
	holder.Name = "LocalHeadlamp"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = Workspace

	local lamp = Instance.new("SpotLight")
	lamp.Face = Enum.NormalId.Front
	lamp.Range = PlayerConfig.HEADLAMP_RANGE
	lamp.Angle = PlayerConfig.HEADLAMP_ANGLE
	lamp.Brightness = PlayerConfig.HEADLAMP_BRIGHTNESS
	lamp.Color = PlayerConfig.HEADLAMP_COLOR
	lamp.Shadows = true
	lamp.Parent = holder

	-- A faint fill so the player's immediate surroundings never go fully black.
	local fill = Instance.new("PointLight")
	fill.Range = 18
	fill.Brightness = 0.7
	fill.Color = PlayerConfig.HEADLAMP_COLOR
	fill.Shadows = false
	fill.Parent = holder

	RunService:BindToRenderStep("ContractMinersHeadlamp", Enum.RenderPriority.Camera.Value + 2, function()
		local character = player.Character
		local alive = character ~= nil and (character:FindFirstChildOfClass("Humanoid") :: Humanoid?) ~= nil
		lamp.Enabled = alive
		fill.Enabled = alive
		-- Just ahead of the face, aimed along the crosshair: any closer and the player's own helmet
		-- would shadow the beam. In third person the camera is behind the shoulder, so use the head.
		local view = Workspace.CurrentCamera.CFrame
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local eye = if CameraController.getMode() == "Third" and head then head.Position else view.Position
		holder.CFrame = view.Rotation * CFrame.new(0.3, 0.25, -1.6) + eye
		if character then
			local gear = character:FindFirstChild("ClassGear")
			local lens = gear and gear:FindFirstChild("HeadlampLens")
			local remote = lens and lens:FindFirstChild("Headlamp")
			if remote and remote:IsA("SpotLight") then
				remote.Enabled = false
			end
		end
	end)
end

return Headlamp
