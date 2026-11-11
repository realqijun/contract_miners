--!strict
-- The team status overlay: hold the team status key in a mission to see every crew member's class,
-- health, shield, state and haul. It refreshes a few times a second while held, and only then.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local MissionState = require(Shared.MissionState)
local PlayerConfig = require(Shared.Config.Player)
local Input = require(script.Parent.Parent.Input)
local Theme = require(script.Parent.Theme)

local TeamStatus = {}

local KEYS = MissionState.KEYS
local REFRESH_SECONDS = 0.2
local WIDTH = 720
local ROW_HEIGHT = 52

type Column = { title: string, x: number, width: number, mining: boolean? }

local COLUMNS: { [string]: Column } = {
	class = { title = "CLASS", x = 250, width = 130 },
	state = { title = "STATUS", x = 380, width = 120 },
	carrying = { title = "CARRYING", x = 500, width = 80, mining = true },
	delivered = { title = "DELIVERED", x = 580, width = 80, mining = true },
	kills = { title = "KILLS", x = 660, width = 60 },
}
local COLUMN_ORDER = { "class", "state", "carrying", "delivered", "kills" }

local player = Players.LocalPlayer
local panel: Frame
local list: Frame
local refresh: RBXScriptConnection? = nil

local function mining(): boolean
	return MissionState.get(KEYS.MissionType) == "Mining"
end

local function stateOf(member: Player): (string, Color3)
	if member:GetAttribute("Dead") == true then
		return "DEAD", Theme.WARNING
	end
	if member:GetAttribute("Downed") == true then
		local at = member:GetAttribute("BleedOutAt")
		local left = if type(at) == "number" then math.max(0, math.ceil(at - Workspace:GetServerTimeNow())) else nil
		return if left then `DOWN  {left}s` else "DOWN", Theme.WARNING
	end
	return "OK", Color3.fromRGB(120, 210, 130)
end

local function cell(row: Frame, key: string, props: { [string]: any }): TextLabel
	local column = COLUMNS[key]
	local label = Theme.label(row, {
		Name = key,
		Position = UDim2.fromOffset(column.x, 0),
		Size = UDim2.new(0, column.width, 1, 0),
		TextXAlignment = if key == "class" or key == "state"
			then Enum.TextXAlignment.Left
			else Enum.TextXAlignment.Right,
	})
	for name, value in props do
		(label :: any)[name] = value
	end
	return label
end

-- Builds one crew member's row and returns the function that brings it up to date.
local function addRow(member: Player, order: number): () -> ()
	local row = Instance.new("Frame")
	row.Name = member.Name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = order
	row.Parent = list
	local swatch = Instance.new("Frame")
	swatch.BorderSizePixel = 0
	swatch.Position = UDim2.fromOffset(0, 8)
	swatch.Size = UDim2.fromOffset(4, ROW_HEIGHT - 16)
	swatch.Parent = row
	Theme.label(row, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(220, 20),
		Font = Theme.FONT_BOLD,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = member.DisplayName .. (if member == player then "  (you)" else ""),
	})
	local health = Theme.bar(row, Theme.HEALTH, UDim2.fromOffset(14, 30), UDim2.fromOffset(210, 6))
	local shield = Theme.bar(row, Theme.SHIELD, UDim2.fromOffset(14, 39), UDim2.fromOffset(210, 4))
	local class = cell(row, "class", { TextSize = 15 })
	local state = cell(row, "state", { Font = Theme.FONT_BOLD, TextSize = 15 })
	local carrying = cell(row, "carrying", { TextSize = 15, TextColor3 = Theme.VOLTICITE })
	local delivered = cell(row, "delivered", { TextSize = 15, TextColor3 = Theme.VOLTICITE })
	local kills = cell(row, "kills", { TextSize = 15 })

	return function()
		local classId = member:GetAttribute("Class")
		local info = if Classes.isClassId(classId) then Classes.INFO[classId :: Classes.ClassId] else nil
		swatch.BackgroundColor3 = if info then info.color else Theme.TEXT_DIM
		class.Text = if info then info.displayName else "-"
		local stateText, stateColor = stateOf(member)
		state.Text = stateText
		state.TextColor3 = stateColor
		local humanoid = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
		health.set(if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0)
		local maxShield = member:GetAttribute("MaxShield") or PlayerConfig.MAX_SHIELD
		shield.set(if humanoid then (member:GetAttribute("Shield") or 0) / maxShield else 0)
		local showHaul = mining()
		carrying.Visible = showHaul
		delivered.Visible = showHaul
		carrying.Text = tostring(member:GetAttribute("Volticite") or 0)
		delivered.Text = tostring(member:GetAttribute("Delivered") or 0)
		kills.Text = tostring(member:GetAttribute("Kills") or 0)
	end
end

local function hide()
	panel.Visible = false
	if refresh then
		refresh:Disconnect()
		refresh = nil
	end
end

-- Menus and the Results screen pause input, which releases the key and hides the overlay.
local function show()
	hide()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, key in COLUMN_ORDER do
		local header = panel:FindFirstChild("Header") :: Frame
		local label = header:FindFirstChild(key) :: TextLabel
		label.Visible = not COLUMNS[key].mining or mining()
	end
	local members = Players:GetPlayers()
	table.sort(members, function(a, b)
		return a.UserId < b.UserId
	end)
	local updates = {}
	for index, member in members do
		table.insert(updates, addRow(member, index))
	end
	local function update()
		for _, apply in updates do
			apply()
		end
	end
	update()
	panel.Visible = true
	local elapsed = 0
	refresh = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= REFRESH_SECONDS then
			elapsed = 0
			update()
		end
	end)
end

function TeamStatus.start()
	-- The overlay takes the key Roblox uses for its own player list.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	-- Its own layer, drawn over the HUD and under menus.
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeamStatus"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Theme.panel("TeamStatus", gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(WIDTH + 48, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 0
	panel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	Theme.label(panel, {
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Font = Theme.FONT_HEAVY,
		TextSize = 26,
		TextColor3 = Theme.ACCENT,
		Text = "CREW",
	})
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 18)
	header.LayoutOrder = 2
	header.Parent = panel
	Theme.label(header, {
		Size = UDim2.fromOffset(220, 18),
		Position = UDim2.fromOffset(14, 0),
		Font = Theme.FONT_BOLD,
		TextSize = 13,
		TextColor3 = Theme.TEXT_DIM,
		Text = "MINER",
	})
	for _, key in COLUMN_ORDER do
		local column = COLUMNS[key]
		Theme.label(header, {
			Name = key,
			Position = UDim2.fromOffset(column.x, 0),
			Size = UDim2.fromOffset(column.width, 18),
			Font = Theme.FONT_BOLD,
			TextSize = 13,
			TextColor3 = Theme.TEXT_DIM,
			TextXAlignment = if key == "class" or key == "state"
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Right,
			Text = column.title,
		})
	end
	list = Instance.new("Frame")
	list.Name = "Crew"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 3
	list.Parent = panel
	local rows = Instance.new("UIListLayout")
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = list

	Input.onBegan("TeamStatus", show)
	Input.onEnded("TeamStatus", hide)
end

return TeamStatus
