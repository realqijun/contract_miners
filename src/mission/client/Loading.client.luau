--!strict
-- Loading screen shown while the mission server generates the cave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local MissionState = require(ReplicatedStorage.Shared.MissionState)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.new(0.8, 0, 0, 56)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 44
title.TextColor3 = Color3.fromRGB(236, 228, 255)
title.Text = "DESCENDING TO KESSRA"
title.Parent = backdrop

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0.45, 40)
subtitle.Size = UDim2.new(0.8, 0, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 20
subtitle.TextColor3 = Color3.fromRGB(176, 96, 255)
subtitle.Text = ""
subtitle.Parent = backdrop

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -48)
status.Size = UDim2.new(0.8, 0, 0, 24)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 18
status.TextColor3 = Color3.fromRGB(150, 140, 170)
status.Text = "Scanning the cave"
status.Parent = backdrop

gui.Parent = player:WaitForChild("PlayerGui")

local function updateSubtitle()
	local missionType = MissionState.get(MissionState.KEYS.MissionType)
	local seed = MissionState.get(MissionState.KEYS.Seed)
	if missionType and seed then
		subtitle.Text = `{string.upper(Missions.DISPLAY_NAME[missionType])} MISSION  ·  SEED {seed}`
	end
end
MissionState.observe(MissionState.KEYS.MissionType, updateSubtitle)
MissionState.observe(MissionState.KEYS.Seed, updateSubtitle)

local done = false
task.spawn(function()
	local dots = 0
	while not done do
		dots = dots % 3 + 1
		status.Text = "Scanning the cave" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)

local function finish()
	if done then
		return
	end
	done = true
	local fade = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, label in { title, subtitle, status } do
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	end
	local tween = TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		gui:Destroy()
	end)
	tween:Play()
end

-- Hide once the cave is ready and our character stands in it.
local function check()
	if MissionState.get(MissionState.KEYS.Phase) ~= "Loading" and player.Character then
		finish()
	end
end
MissionState.observe(MissionState.KEYS.Phase, check)
player.CharacterAdded:Connect(check)
