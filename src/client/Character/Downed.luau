--!strict
-- The local player's downed and dead states: no equipment, no walking, third-person camera,
-- and an overlay with the bleed-out countdown or what teammates need to do.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Hud = require(Client.UI.Hud)
local Loadout = require(Client.Equipment.Loadout)
local CameraController = require(script.Parent.CameraController)

local Downed = {}

local player = Players.LocalPlayer

function Downed.start()
	local overlay = Instance.new("Frame")
	overlay.Name = "DownedOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(80, 0, 10)
	overlay.BackgroundTransparency = 0.75
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 0
	overlay.Parent = Hud.gui()
	local title = Theme.label(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(700, 50),
		Font = Theme.FONT_HEAVY,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local detail = Theme.label(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.38, 44),
		Size = UDim2.fromOffset(700, 26),
		TextSize = 20,
		TextColor3 = Theme.TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local previousMode: CameraController.Mode = "First"
	local wasIncapacitated = false

	local function refresh()
		local downed = player:GetAttribute("Downed") == true
		local dead = player:GetAttribute("Dead") == true
		local incapacitated = downed or dead
		overlay.Visible = incapacitated
		if incapacitated ~= wasIncapacitated then
			wasIncapacitated = incapacitated
			Loadout.setEnabled(not incapacitated)
			if incapacitated then
				previousMode = CameraController.getMode()
				CameraController.setMode("Third")
			else
				CameraController.setMode(previousMode)
			end
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Falling over sells being down; standing back up when revived.
			humanoid.PlatformStand = downed
		end
		if dead then
			title.Text = "YOUR TAG IS DOWN THERE"
			title.TextColor3 = Theme.TEXT
			detail.Text = "A teammate can carry it to a resupply pod to bring you back"
		elseif downed then
			title.TextColor3 = Theme.WARNING
		end
	end
	player:GetAttributeChangedSignal("Downed"):Connect(refresh)
	player:GetAttributeChangedSignal("Dead"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)
	refresh()

	RunService.Heartbeat:Connect(function()
		if player:GetAttribute("Downed") ~= true then
			return
		end
		local function secondsUntil(at: any): number
			return if type(at) == "number" then math.ceil(math.max(0, at - Workspace:GetServerTimeNow())) else 0
		end
		title.Text = "YOU'RE DOWN"
		-- The walkthrough stands players back up on its own; everywhere else a teammate must.
		local standUpAt = player:GetAttribute("StandUpAt")
		detail.Text = if standUpAt ~= nil
			then string.format("Practice run  ·  back on your feet in %d", secondsUntil(standUpAt))
			else string.format(
				"Bleeding out in %d  ·  hold on for a teammate to revive you",
				secondsUntil(player:GetAttribute("BleedOutAt"))
			)
	end)
end

return Downed
