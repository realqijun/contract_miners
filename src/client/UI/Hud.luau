--!strict
-- The in-mission HUD: crosshair, vitals, objective tracker and team status.
-- Every element updates from attribute and humanoid change events, never by polling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)
local PlayerConfig = require(Shared.Config.Player)
local Resources = require(Shared.Config.Resources)
local Theme = require(script.Parent.Theme)
local Input = require(script.Parent.Parent.Input)

local Hud = {}
Hud._hitToken = nil :: {}?

local KEYS = MissionState.KEYS
local player = Players.LocalPlayer

local gui: ScreenGui
local crosshairTicks: { Frame } = {}

local function crosshair()
	local holder = Instance.new("Frame")
	holder.Name = "Crosshair"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(28, 28)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local function tick(position: UDim2, size: UDim2)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = position
		line.Size = size
		line.BackgroundColor3 = Theme.TEXT
		line.BackgroundTransparency = 0.15
		line.BorderSizePixel = 0
		line.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.6
		stroke.Parent = line
		table.insert(crosshairTicks, line)
	end
	tick(UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(3, 3))
	tick(UDim2.new(0.5, 0, 0, 2), UDim2.fromOffset(2, 6))
	tick(UDim2.new(0.5, 0, 1, -2), UDim2.fromOffset(2, 6))
	tick(UDim2.new(0, 2, 0.5, 0), UDim2.fromOffset(6, 2))
	tick(UDim2.new(1, -2, 0.5, 0), UDim2.fromOffset(6, 2))
end

local function vitals()
	local panel = Theme.panel("Vitals", gui)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 24, 1, -24)
	panel.Size = UDim2.fromOffset(300, 66)
	local shieldBar = Theme.bar(panel, Theme.SHIELD, UDim2.fromOffset(14, 14), UDim2.new(1, -86, 0, 8))
	local healthBar = Theme.bar(panel, Theme.HEALTH, UDim2.fromOffset(14, 30), UDim2.new(1, -86, 0, 20))
	local shieldText = Theme.label(panel, {
		Position = UDim2.new(1, -66, 0, 8),
		Size = UDim2.fromOffset(56, 20),
		Font = Theme.FONT_BOLD,
		TextSize = 14,
		TextColor3 = Theme.SHIELD,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local healthText = Theme.label(panel, {
		Position = UDim2.new(1, -66, 0, 28),
		Size = UDim2.fromOffset(56, 24),
		Font = Theme.FONT_HEAVY,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function updateShield()
		local shield = player:GetAttribute("Shield") or 0
		local max = player:GetAttribute("MaxShield") or PlayerConfig.MAX_SHIELD
		shieldBar.set(shield / max)
		shieldText.Text = tostring(shield)
	end
	player:GetAttributeChangedSignal("Shield"):Connect(updateShield)
	updateShield()

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function updateHealth()
			healthBar.set(humanoid.Health / humanoid.MaxHealth)
			healthText.Text = tostring(math.ceil(humanoid.Health))
			healthText.TextColor3 = if humanoid.Health / humanoid.MaxHealth < 0.3 then Theme.WARNING else Theme.TEXT
		end
		humanoid.HealthChanged:Connect(updateHealth)
		updateHealth()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

local function objective()
	local panel = Theme.panel("Objective", gui)
	panel.Position = UDim2.fromOffset(24, 24)
	panel.Size = UDim2.fromOffset(300, 118)
	local title = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Theme.FONT_HEAVY,
		TextSize = 15,
		TextColor3 = Theme.ACCENT,
	})
	local goal = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 20),
	})
	local progress = Theme.bar(panel, Theme.VOLTICITE, UDim2.fromOffset(14, 56), UDim2.new(1, -28, 0, 6))
	local carrying = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 0, 18),
		TextSize = 14,
		TextColor3 = Theme.TEXT_DIM,
	})
	local ferrin = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 18),
		TextSize = 14,
		TextColor3 = Theme.FERRIN,
	})
	-- Long lines (a pipeline in progress, a resupply on offer) shrink to fit instead of running
	-- past the panel.
	for _, label in { goal, carrying, ferrin } do
		local size = label.TextSize
		label.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = size
		constraint.Parent = label
	end

	local function update()
		local missionType = MissionState.get(KEYS.MissionType)
		if not missionType then
			return
		end
		title.Text = if MissionState.get(KEYS.Walkthrough) == true
			then "WALKTHROUGH"
			else string.upper(Missions.DISPLAY_NAME[missionType]) .. " MISSION"
		carrying.TextColor3 = Theme.TEXT_DIM
		local phase = MissionState.get(KEYS.Phase)
		if phase == "Extraction" then
			local now = Workspace:GetServerTimeNow()
			local landsAt = MissionState.get(KEYS.LiftLandsAt) or 0
			local launchAt = MissionState.get(KEYS.LiftLaunchAt)
			title.TextColor3 = Theme.WARNING
			if launchAt then
				local remaining = math.max(0, math.ceil(launchAt - now))
				goal.Text = string.format("Board the Lift Pod  %d:%02d", remaining // 60, remaining % 60)
				carrying.Text = `{MissionState.get(KEYS.Aboard) or 0} / {#Players:GetPlayers()} aboard`
				progress.set(remaining / Missions.LIFT_POD_COUNTDOWN)
			else
				goal.Text = `Lift Pod landing in {math.max(0, math.ceil(landsAt - now))}`
				carrying.Text = "Follow the Lift Pod marker"
				progress.set(1)
			end
		elseif missionType == "Refinery" then
			title.TextColor3 = Theme.ACCENT
			local stage = MissionState.get(KEYS.RefineryStage)
			local laying = player:GetAttribute("LayingPipe")
			if stage == "Site" or stage == "Dropping" then
				goal.Text = if stage == "Site" then "Call down the Refinery at its site" else "Refinery inbound"
				carrying.Text = "Follow the Refinery site marker"
				progress.set(0)
			elseif stage == "Pipes" then
				local connected = MissionState.get(KEYS.WellsConnected) or 0
				goal.Text = `Connect the wells  {connected} / {Missions.REFINERY_WELLS}`
				carrying.Text = if laying
					then `Laying pipe from well {laying} back to the Refinery`
					else "Start a pipeline at a well"
				progress.set(connected / Missions.REFINERY_WELLS)
			elseif stage == "Pumping" then
				local broken = MissionState.get(KEYS.PipesBroken) or 0
				local pumped = MissionState.get(KEYS.PumpProgress) or 0
				goal.Text = string.format("Pumping slurry  %d%%", math.floor(pumped * 100))
				carrying.Text = if broken > 0 then `Repair broken pipes ({broken})` else "Defend the pipelines"
				carrying.TextColor3 = if broken > 0 then Theme.WARNING else Theme.TEXT_DIM
				progress.set(pumped)
			else
				goal.Text = "Rocket launch"
				carrying.Text = ""
				progress.set(1)
			end
		elseif missionType == "Mining" then
			title.TextColor3 = Theme.ACCENT
			local deposited = MissionState.get(KEYS.Deposited) or 0
			local target = MissionState.get(KEYS.Target) or 0
			goal.Text = `Deposit Volticite  {deposited} / {target}`
			progress.set(if target > 0 then deposited / target else 0)
			local carried = player:GetAttribute("Volticite") or 0
			if carried > 0 then
				carrying.Text = `Carrying {carried} Volticite`
			elseif target > 0 and deposited >= target then
				carrying.Text = "Volticite quota met"
			else
				carrying.Text = "Mine Volticite and bring it to the Dropcan"
			end
		end
		local pool = MissionState.get(KEYS.Ferrin) or 0
		ferrin.Text = `Ferrin  {pool % Resources.RESUPPLY_COST} / {Resources.RESUPPLY_COST}`
			.. (
				if pool >= Resources.RESUPPLY_COST
					then `   ·   hold {Input.label("Ping")} for resupply ({pool // Resources.RESUPPLY_COST})`
					else ""
			)
	end
	for _, key in
		{
			KEYS.MissionType,
			KEYS.Walkthrough,
			KEYS.Deposited,
			KEYS.Target,
			KEYS.Ferrin,
			KEYS.Phase,
			KEYS.Aboard,
			KEYS.LiftLaunchAt,
			KEYS.RefineryStage,
			KEYS.WellsConnected,
			KEYS.PumpProgress,
			KEYS.PipesBroken,
		}
	do
		MissionState.observe(key, update)
	end
	-- Countdowns tick once a second while extraction is under way.
	task.spawn(function()
		while true do
			task.wait(1)
			if MissionState.get(KEYS.Phase) == "Extraction" then
				update()
			end
		end
	end)
	player:GetAttributeChangedSignal("Volticite"):Connect(update)
	player:GetAttributeChangedSignal("LayingPipe"):Connect(update)
end

local function teamRow(list: Frame, member: Player): Frame
	local row = Instance.new("Frame")
	row.Name = member.Name
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = member.UserId
	row.Parent = list
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(4, 28)
	swatch.Position = UDim2.fromOffset(0, 3)
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	local name = Theme.label(row, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -12, 0, 18),
		Font = Theme.FONT_BOLD,
		TextSize = 14,
		Text = member.DisplayName,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local bar = Theme.bar(row, Theme.HEALTH, UDim2.fromOffset(12, 22), UDim2.new(1, -12, 0, 6))

	local function updateClass()
		local classId = member:GetAttribute("Class")
		swatch.BackgroundColor3 = if Classes.isClassId(classId)
			then Classes.INFO[classId :: Classes.ClassId].color
			else Theme.TEXT_DIM
	end
	member:GetAttributeChangedSignal("Class"):Connect(updateClass)
	updateClass()

	local function updateState()
		local dead = member:GetAttribute("Dead") == true
		local downed = member:GetAttribute("Downed") == true
		name.TextColor3 = if dead or downed then Theme.WARNING else Theme.TEXT
		name.Text = member.DisplayName .. (if dead then "  ·  DEAD" elseif downed then "  ·  DOWN" else "")
		if dead then
			bar.set(0)
		end
	end
	member:GetAttributeChangedSignal("Downed"):Connect(updateState)
	member:GetAttributeChangedSignal("Dead"):Connect(updateState)
	updateState()

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function update()
			bar.set(humanoid.Health / humanoid.MaxHealth)
		end
		humanoid.HealthChanged:Connect(update)
		update()
	end
	member.CharacterAdded:Connect(watch)
	if member.Character then
		task.spawn(watch, member.Character)
	end
	return row
end

local function team()
	local panel = Theme.panel("Team", gui)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -24, 0, 24)
	panel.Size = UDim2.fromOffset(220, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	local rows: { [Player]: Frame } = {}
	local function add(member: Player)
		rows[member] = teamRow(panel, member)
	end
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(member)
		local row = rows[member]
		if row then
			row:Destroy()
			rows[member] = nil
		end
	end)
	for _, member in Players:GetPlayers() do
		add(member)
	end
end

-- A banner across the top when a swarm is called.
local function swarmWarning()
	local banner = Theme.label(gui, {
		Name = "SwarmWarning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(600, 40),
		Font = Theme.FONT_HEAVY,
		TextSize = 30,
		TextColor3 = Theme.WARNING,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "THE HIVE IS COMING",
		TextTransparency = 1,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = banner
	local shown: number? = nil
	MissionState.observe(KEYS.Swarm, function(value)
		if value == nil or value == shown then
			return
		end
		local first = shown == nil
		shown = value
		if first and Workspace:GetServerTimeNow() - value > 5 then
			return
		end
		banner.TextTransparency = 0
		stroke.Transparency = 0.4
		task.delay(3.5, function()
			if shown == value then
				TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end)
	end)
end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	crosshair()
	vitals()
	objective()
	team()
	swarmWarning()
end

function Hud.gui(): ScreenGui
	return gui
end

-- Flashes the crosshair to confirm a hit; weakspot hits flash brighter and longer.
function Hud.hitMarker(weakspot: boolean)
	local color = if weakspot then Theme.ACCENT else Theme.WARNING
	for _, line in crosshairTicks do
		line.BackgroundColor3 = color
	end
	local token = {}
	Hud._hitToken = token
	task.delay(if weakspot then 0.16 else 0.09, function()
		if Hud._hitToken == token then
			for _, line in crosshairTicks do
				line.BackgroundColor3 = Theme.TEXT
			end
		end
	end)
end

return Hud
