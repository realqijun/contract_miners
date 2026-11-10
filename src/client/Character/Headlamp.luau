--!strict
-- The local player's headlamp follows the camera so it lights exactly where they aim.
-- The helmet lamp other players see is hidden locally to avoid double lighting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)

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
	fill.Range = 12
	fill.Brightness = 0.35
	fill.Color = PlayerConfig.HEADLAMP_COLOR
	fill.Shadows = false
	fill.Parent = holder

	RunService:BindToRenderStep("ContractMinersHeadlamp", Enum.RenderPriority.Camera.Value + 2, function()
		local character = player.Character
		local alive = character ~= nil and (character:FindFirstChildOfClass("Humanoid") :: Humanoid?) ~= nil
		lamp.Enabled = alive
		fill.Enabled = alive
		-- Slightly above and behind the eye so the beam edge is visible on nearby walls.
		holder.CFrame = Workspace.CurrentCamera.CFrame * CFrame.new(0.4, 0.3, 0.2)
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
