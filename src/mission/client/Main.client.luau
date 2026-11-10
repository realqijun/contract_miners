--!strict
-- Mission place client entry point.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Client = ReplicatedStorage.Client
local CameraController = require(Client.Character.CameraController)
local Headlamp = require(Client.Character.Headlamp)
local Movement = require(Client.Character.Movement)

-- The game draws its own HUD; the default backpack and health bar would duplicate it.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
-- The View button is the ping key, not the UI selection toggle.
GuiService.AutoSelectGuiEnabled = false

CameraController.start()
Movement.start()
Headlamp.start()
