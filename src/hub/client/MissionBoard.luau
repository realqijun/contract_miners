--!strict
-- A launch bay's mission board: the pad leader picks Mining or Refinery (optionally a seed to
-- replay a cave), which starts the countdown for everyone on the pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Missions = require(Shared.Config.Missions)
local Net = require(Shared.Net)

local Client = ReplicatedStorage.Client
local Menu = require(Client.UI.Menu)
local Theme = require(Client.UI.Theme)

local MissionBoard = {}

local DESCRIPTIONS: { [Missions.MissionType]: string } = {
	Mining = "Mine Volticite from the cave walls and deposit it at the Dropcan. When the quota is met, fight your way to the Lift Pod.",
	Refinery = "Call down the Refinery, walk pipelines back from three slurry wells, and defend the pipes while it pumps. Then launch the rocket and reach the Lift Pod.",
}

function MissionBoard.open(padIndex: number)
	local content = Menu.open("Mission board", 760, 380)
	local state = ReplicatedStorage:WaitForChild("LaunchPads"):FindFirstChild(`Pad{padIndex}`)
	local crew = Theme.label(content, {
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Theme.TEXT_DIM,
		TextSize = 14,
	})
	local function refreshCrew()
		local members = state and state:GetAttribute("Members")
		crew.Text = if type(members) == "string" and members ~= ""
			then `On the pad: {members}`
			else "Nobody is on this pad yet"
	end
	if state then
		local connection = state:GetAttributeChangedSignal("Members"):Connect(refreshCrew)
		crew.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end
	refreshCrew()

	local seedBox = Instance.new("TextBox")
	seedBox.PlaceholderText = "Seed (optional, replays a cave)"
	seedBox.Text = ""
	seedBox.ClearTextOnFocus = false
	seedBox.Font = Theme.FONT
	seedBox.TextSize = 15
	seedBox.TextColor3 = Theme.TEXT
	seedBox.PlaceholderColor3 = Theme.TEXT_DIM
	seedBox.BackgroundColor3 = Theme.TRACK
	seedBox.BorderSizePixel = 0
	seedBox.Position = UDim2.new(0, 0, 1, -40)
	seedBox.Size = UDim2.new(0.5, -6, 0, 36)
	seedBox.Parent = content
	Theme.corner(seedBox)
	local status = Theme.label(content, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -40),
		Size = UDim2.new(0.5, -6, 0, 36),
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Theme.WARNING,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	for index, missionType in Missions.TYPES do
		local card = Theme.panel(missionType, content)
		card.BackgroundColor3 = Color3.fromRGB(28, 24, 38)
		card.Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 6, 0, 30)
		card.Size = UDim2.new(0.5, -6, 1, -84)
		Theme.label(card, {
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.new(1, -28, 0, 26),
			Font = Theme.FONT_HEAVY,
			TextSize = 22,
			TextColor3 = Theme.ACCENT,
			Text = string.upper(Missions.DISPLAY_NAME[missionType]),
		})
		Theme.label(card, {
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.new(1, -28, 1, -110),
			TextSize = 14,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = DESCRIPTIONS[missionType],
		})
		local launch = Menu.button(card, "Launch", function()
			local seedText = seedBox.Text:gsub("%s", "")
			local seed = if seedText ~= "" then tonumber(seedText) else nil
			if seedText ~= "" and not seed then
				status.Text = "Seeds are whole numbers"
				return
			end
			local ok, reason = Net.func("ChooseMission"):InvokeServer(missionType, seed)
			if ok then
				Menu.close()
			else
				status.Text = reason or "Could not launch"
			end
		end, "Primary")
		launch.AnchorPoint = Vector2.new(0.5, 1)
		launch.Position = UDim2.new(0.5, 0, 1, -14)
		launch.Size = UDim2.new(1, -28, 0, 40)
	end
end

return MissionBoard
