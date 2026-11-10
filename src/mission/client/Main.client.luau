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
local WeaponItem = require(Client.Equipment.WeaponItem)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Kits = require(ReplicatedStorage.Shared.Config.Kits)
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

local localPlayer = Players.LocalPlayer

-- Our own impacts and shots are predicted locally; only show other players' from the server.
Net.unreliable("Impact").OnClientEvent:Connect(function(position, normal, surface, source)
	if source ~= localPlayer then
		Effects.impact(position, normal, surface)
	end
end)
Net.unreliable("WeaponShots").OnClientEvent
	:Connect(function(shooter: Player, weaponId: string, origin: Vector3, ends: { Vector3 })
		if shooter == localPlayer then
			return
		end
		local held = shooter.Character and shooter.Character:FindFirstChild("HeldItem")
		local marker = held and held:FindFirstChild("Muzzle", true)
		local muzzle = if marker and marker:IsA("Attachment") then marker.WorldPosition else origin
		if weaponId == "FlameProjector" then
			Effects.flame(muzzle, ((ends[1] or origin) - origin).Unit, 20)
			return
		end
		for _, finish in ends do
			Effects.tracer(muzzle, finish)
		end
		Effects.muzzleFlash(muzzle, ((ends[1] or origin + Vector3.zAxis) - muzzle).Unit)
	end)
Net.unreliable("Projectile").OnClientEvent:Connect(Effects.projectile)
Net.unreliable("ProjectileEnd").OnClientEvent:Connect(Effects.endProjectile)
Net.unreliable("Explosion").OnClientEvent:Connect(function(position: Vector3, radius: number, style: string)
	Effects.explosion(position, radius, style)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local distance = (root.Position - position).Magnitude
		CameraController.shake(math.clamp(0.05 * (1 - distance / (radius * 6)), 0, 0.05), 0.4)
	end
end)

localPlayer.CharacterAdded:Wait()
local classId = localPlayer:GetAttribute("Class")
local kit = Kits.BY_CLASS[if Classes.isClassId(classId) then classId :: Classes.ClassId else "Scout"]
Loadout.start({
	Primary = WeaponItem(kit.primary),
	Secondary = WeaponItem(kit.secondary),
	Pickaxe = PickaxeItem(),
})
