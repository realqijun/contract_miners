--!strict
-- The end-of-mission screen: outcome, seed, time, Volticite delivered, and each crew member's
-- credits and XP, with a countdown back to the ship.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local MissionState = require(Shared.MissionState)
local Theme = require(script.Parent.Theme)
local Hud = require(script.Parent.Hud)

local Client = script.Parent.Parent
local CameraController = require(Client.Character.CameraController)
local Loadout = require(Client.Equipment.Loadout)
local Input = require(Client.Input)

local Results = {}

local KEYS = MissionState.KEYS
local player = Players.LocalPlayer

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, math.floor(seconds % 60))
end

local function show()
	Loadout.setEnabled(false)
	Input.setEnabled(false)
	CameraController.setEnabled(false)
	Hud.gui().Enabled = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "Results"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	TweenService:Create(backdrop, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()

	local success = MissionState.get(KEYS.Outcome) == "Success"
	local card = Theme.panel("Card", backdrop)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(560, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 24)
	end
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = card

	local order = 0
	local function line(props: { [string]: any }): TextLabel
		order += 1
		props.LayoutOrder = order
		props.Size = props.Size or UDim2.new(1, 0, 0, 24)
		return Theme.label(card, props)
	end

	line({
		Text = if success then "MISSION COMPLETE" else "MISSION FAILED",
		Font = Theme.FONT_HEAVY,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = if success then Theme.ACCENT else Theme.WARNING,
	})
	line({ Text = MissionState.get(KEYS.OutcomeReason) or "", TextColor3 = Theme.TEXT_DIM })
	local started = MissionState.get(KEYS.StartedAt) or 0
	local ended = MissionState.get(KEYS.EndedAt) or started
	local summary = `Seed {MissionState.get(KEYS.Seed)}   ·   Time {formatTime(ended - started)}`
	if MissionState.get(KEYS.MissionType) == "Mining" then
		summary ..= `   ·   Volticite {MissionState.get(KEYS.Deposited) or 0} / {MissionState.get(KEYS.Target) or 0}`
	end
	line({ Text = summary, TextSize = 16, TextColor3 = Theme.TEXT_DIM })

	for _, member in Players:GetPlayers() do
		local classId = member:GetAttribute("Class")
		local info = if Classes.isClassId(classId) then Classes.INFO[classId :: Classes.ClassId] else nil
		local credits = member:GetAttribute("RewardCredits") or 0
		local xp = member:GetAttribute("RewardXP") or 0
		local suffix = if member:GetAttribute("LeftBehind") == true then "   (left behind)" else ""
		line({
			Text = `{member.DisplayName}   {if info then info.displayName else ""}{suffix}`,
			Font = Theme.FONT_BOLD,
			TextColor3 = if info then info.color else Theme.TEXT,
		})
		line({
			Text = `     +{credits} credits     +{xp} XP`,
			TextSize = 16,
		})
	end

	local countdown = line({ TextSize = 15, TextColor3 = Theme.TEXT_DIM })
	RunService.Heartbeat:Connect(function()
		local returnAt = MissionState.get(KEYS.ReturnAt) or 0
		local remaining = math.max(0, math.ceil(returnAt - Workspace:GetServerTimeNow()))
		countdown.Text = `Returning to the ship in {remaining}`
	end)
end

function Results.start()
	local shown = false
	MissionState.observe(KEYS.Phase, function(phase)
		if phase == "Ended" and not shown then
			shown = true
			show()
		end
	end)
end

return Results
