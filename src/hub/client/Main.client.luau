--!strict
-- Hub place client entry point: terminal menus, the controls board, a small status HUD, launch
-- countdowns and the first-join walkthrough offer.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Missions = require(Shared.Config.Missions)
local Net = require(Shared.Net)
local Progress = require(Shared.Progress)

local Client = ReplicatedStorage.Client
local Audio = require(Client.Audio)
local Controls = require(Client.Controls)
local Input = require(Client.Input)
local Settings = require(Client.Settings)
local ProgressView = require(Client.ProgressView)
local Menu = require(Client.UI.Menu)
local SettingsMenu = require(Client.UI.SettingsMenu)
local Theme = require(Client.UI.Theme)

local ClassSelect = require(script.Parent.ClassSelect)
local UpgradesMenu = require(script.Parent.UpgradesMenu)
local MissionBoard = require(script.Parent.MissionBoard)

local player = Players.LocalPlayer

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
Audio.start()
Settings.bindToProfile(player, function(values)
	Net.event("SaveSettings"):FireServer(values)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "HubHud"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function walkthroughOffer()
	local content = Menu.open("Welcome aboard, miner", 620, 196)
	Theme.label(content, {
		Size = UDim2.new(1, 0, 0, 70),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Kessra's caves are rich in Volticite and crawling with Vrill. Want a five-minute walkthrough of mining, moving and fighting before your first contract?",
	})
	local play = Menu.button(content, "Play walkthrough", function()
		Net.event("Walkthrough"):FireServer(true)
		Menu.close()
	end, "Primary")
	play.AnchorPoint = Vector2.new(0, 1)
	play.Position = UDim2.fromScale(0, 1)
	play.Size = UDim2.fromOffset(260, 44)
	local skip = Menu.button(content, "Skip", function()
		Net.event("Walkthrough"):FireServer(false)
		Menu.close()
	end)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.fromScale(1, 1)
	skip.Size = UDim2.fromOffset(160, 44)
end

local function replayWalkthrough()
	local content = Menu.open("Walkthrough", 560, 200)
	Theme.label(content, {
		Size = UDim2.new(1, 0, 0, 50),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Replay the guided walkthrough in a small practice cave. It pays no rewards.",
	})
	local play = Menu.button(content, "Start walkthrough", function()
		Net.event("Walkthrough"):FireServer(true)
		Menu.close()
	end, "Primary")
	play.AnchorPoint = Vector2.new(0, 1)
	play.Position = UDim2.fromScale(0, 1)
	play.Size = UDim2.fromOffset(240, 44)
end

-- Terminal prompts open their menu on this client.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local opens = prompt:GetAttribute("Opens")
	if opens == "ClassSelect" then
		ClassSelect.open()
	elseif opens == "Upgrades" then
		UpgradesMenu.open()
	elseif opens == "MissionBoard" then
		MissionBoard.open(prompt:GetAttribute("Pad") :: number)
	elseif opens == "Settings" then
		SettingsMenu.open()
	elseif opens == "Walkthrough" then
		replayWalkthrough()
	end
end)
Input.onBegan("Menu", function()
	Menu.toggle(SettingsMenu.open)
end)

-- Status badge: class, level and credits.
local badge = Theme.panel("Badge", gui)
badge.Position = UDim2.fromOffset(24, 24)
badge.Size = UDim2.fromOffset(300, 64)
local classLine = Theme.label(badge, {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -28, 0, 24),
	Font = Theme.FONT_HEAVY,
	TextSize = 20,
})
local creditLine = Theme.label(badge, {
	Position = UDim2.fromOffset(14, 34),
	Size = UDim2.new(1, -28, 0, 20),
	TextSize = 15,
	TextColor3 = Theme.TEXT_DIM,
})
local offered = false
ProgressView.observe(function(data)
	local info = Classes.INFO[data.selectedClass]
	classLine.Text = `{string.upper(info.displayName)}  ·  LEVEL {Progress.level(data, data.selectedClass)}`
	classLine.TextColor3 = info.color
	creditLine.Text = `{data.credits} credits`
	if not data.walkthroughOffered and not offered then
		offered = true
		walkthroughOffer()
	end
end)

-- Launch countdown banner for whichever pad we stand on, below the badge so they never overlap.
local banner = Theme.label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.fromOffset(700, 36),
	Font = Theme.FONT_HEAVY,
	TextSize = 26,
	TextColor3 = Theme.ACCENT,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local stroke = Instance.new("UIStroke")
stroke.Transparency = 0.4
stroke.Parent = banner
task.spawn(function()
	local pads = ReplicatedStorage:WaitForChild("LaunchPads")
	while true do
		task.wait(0.2)
		local text = ""
		for _, pad in pads:GetChildren() do
			local members = pad:GetAttribute("Members")
			if type(members) == "string" and string.find(members, player.DisplayName, 1, true) then
				local launchAt = pad:GetAttribute("LaunchAt") or 0
				local missionType = pad:GetAttribute("MissionType")
				if launchAt > 0 then
					local name = if Missions.isMissionType(missionType) then Missions.DISPLAY_NAME[missionType] else ""
					text = `{string.upper(name)} MISSION  ·  LAUNCHING IN {math.max(
						0,
						math.ceil(launchAt - Workspace:GetServerTimeNow())
					)}`
				elseif pad:GetAttribute("LeaderId") == player.UserId then
					text = "YOU LEAD THIS PAD  ·  PICK A MISSION AT THE BOARD"
				else
					text = "WAITING FOR THE PAD LEADER TO PICK A MISSION"
				end
			end
		end
		banner.Text = text
	end
end)

-- Brief notices from the server, on a panel sized to the text so they read over any floor.
local noticePanel = Theme.panel("Notice", gui)
noticePanel.AnchorPoint = Vector2.new(0.5, 1)
noticePanel.Position = UDim2.new(0.5, 0, 1, -40)
noticePanel.Size = UDim2.fromOffset(0, 40)
noticePanel.AutomaticSize = Enum.AutomaticSize.X
noticePanel.Visible = false
local noticePadding = Instance.new("UIPadding")
noticePadding.PaddingLeft = UDim.new(0, 18)
noticePadding.PaddingRight = UDim.new(0, 18)
noticePadding.Parent = noticePanel
local noticeLabel = Theme.label(noticePanel, {
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Theme.FONT_BOLD,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
})
Net.event("Notice").OnClientEvent:Connect(function(text: string)
	noticeLabel.Text = text
	noticePanel.Visible = true
	task.delay(4, function()
		if noticeLabel.Text == text then
			noticeLabel.Text = ""
			noticePanel.Visible = false
		end
	end)
end)

-- Fill in the controls board on the back wall: two columns of eight.
local function fillBoard(board: Instance)
	local surface = board:WaitForChild("Controls") :: SurfaceGui
	local title = Theme.label(surface, {
		Position = UDim2.fromOffset(40, 24),
		Size = UDim2.new(1, -80, 0, 70),
		Font = Theme.FONT_HEAVY,
		TextSize = 56,
		TextColor3 = Theme.ACCENT,
		Text = "CONTROLS",
	})
	title.TextXAlignment = Enum.TextXAlignment.Left
	for index, row in Controls.rows() do
		local x = 40 + (index - 1) // 8 * 630
		local y = 110 + (index - 1) % 8 * 66
		local cells = {
			{ text = row.label, offset = 0, width = 390, color = Theme.TEXT, font = Theme.FONT },
			{ text = row.keyboard, offset = 395, width = 95, color = Theme.ACCENT, font = Theme.FONT_BOLD },
			{ text = row.gamepad, offset = 495, width = 105, color = Theme.TEXT_DIM, font = Theme.FONT },
		}
		for _, cell in cells do
			Theme.label(surface, {
				Position = UDim2.fromOffset(x + cell.offset, y),
				Size = UDim2.fromOffset(cell.width, 60),
				TextSize = 28,
				Font = cell.font,
				TextColor3 = cell.color,
				Text = cell.text,
			})
		end
	end
end
for _, board in CollectionService:GetTagged("ControlsBoard") do
	task.spawn(fillBoard, board)
end
CollectionService:GetInstanceAddedSignal("ControlsBoard"):Connect(fillBoard)
