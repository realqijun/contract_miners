--!strict
-- Mission place client entry point.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

local Client = ReplicatedStorage.Client
local CameraController = require(Client.Character.CameraController)
local Headlamp = require(Client.Character.Headlamp)
local Movement = require(Client.Character.Movement)
local Viewmodel = require(Client.Character.Viewmodel)
local Effects = require(Client.Effects)
local Loadout = require(Client.Equipment.Loadout)
local PickaxeItem = require(Client.Equipment.PickaxeItem)
local Hud = require(Client.UI.Hud)

-- The game draws its own HUD; the default backpack and health bar would duplicate it.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
-- The View button is the ping key, not the UI selection toggle.
GuiService.AutoSelectGuiEnabled = false

CameraController.start()
Movement.start()
Headlamp.start()
Viewmodel.start()
Hud.start()

-- Our own impacts are predicted locally; only show other players' from the server.
Net.unreliable("Impact").OnClientEvent:Connect(function(position, normal, surface, source)
	if source ~= Players.LocalPlayer then
		Effects.impact(position, normal, surface)
	end
end)

Players.LocalPlayer.CharacterAdded:Wait()
Loadout.start({
	Pickaxe = PickaxeItem(),
})
