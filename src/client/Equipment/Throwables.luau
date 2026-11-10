--!strict
-- Grenades and flares: thrown instantly on keypress without switching what is in hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Kits = require(Shared.Config.Kits)
local Net = require(Shared.Net)
local ToolsConfig = require(Shared.Config.Tools)

local Client = script.Parent.Parent
local Input = require(Client.Input)
local CameraController = require(Client.Character.CameraController)
local Viewmodel = require(Client.Character.Viewmodel)
local Theme = require(Client.UI.Theme)
local Hud = require(Client.UI.Hud)

local Throwables = {}

local player = Players.LocalPlayer

local function throwClip(alpha: number): CFrame
	local swing = math.sin(alpha * math.pi)
	return CFrame.new(0, -1.2 * swing, 0.4 * swing) * CFrame.Angles(math.rad(-35) * swing, 0, 0)
end

local function counters(grenadeId: string)
	local panel = Theme.panel("Throwables", Hud.gui())
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -24, 1, -124)
	panel.Size = UDim2.fromOffset(260, 30)
	local label = Theme.label(panel, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		TextSize = 14,
		TextColor3 = Theme.TEXT_DIM,
	})
	local grenadeName = ToolsConfig.GRENADES[grenadeId].displayName
	local function update()
		local grenades = player:GetAttribute("Charges_" .. grenadeId) or 0
		local flares = player:GetAttribute("Charges_Flares") or 0
		label.Text =
			`{Input.label("Grenade")}  {grenadeName} ×{grenades}      {Input.label("Flare")}  Flares ×{flares}`
	end
	player:GetAttributeChangedSignal("Charges_" .. grenadeId):Connect(update)
	player:GetAttributeChangedSignal("Charges_Flares"):Connect(update)
	update()
end

function Throwables.start()
	local classId = player:GetAttribute("Class")
	local kit = Kits.BY_CLASS[if Classes.isClassId(classId) then classId :: Classes.ClassId else "Scout"]
	counters(kit.grenade)
	local enabled = true
	local function throw(kind: "Grenade" | "Flare")
		if not enabled or player:GetAttribute("Downed") == true then
			return
		end
		local id = if kind == "Flare" then "Flares" else kit.grenade
		if (player:GetAttribute("Charges_" .. id) or 0) < 1 then
			return
		end
		local origin, direction = CameraController.aimRay()
		Net.event("Throw"):FireServer(kind, origin, direction)
		Viewmodel.play(throwClip, 0.4)
	end
	Input.onBegan("Grenade", function()
		throw("Grenade")
	end)
	Input.onBegan("Flare", function()
		throw("Flare")
	end)
end

return Throwables
