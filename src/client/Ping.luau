--!strict
-- Tap ping to mark what you aim at; hold it to call a resupply pod there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Input = require(script.Parent.Input)
local CameraController = require(script.Parent.Character.CameraController)
local Markers = require(script.Parent.UI.Markers)

local Ping = {}

Ping.HOLD_FOR_RESUPPLY = 0.6

function Ping.start()
	local pressedAt: number? = nil
	Input.onBegan("Ping", function()
		pressedAt = os.clock()
	end)
	Input.onEnded("Ping", function()
		if not pressedAt then
			return
		end
		local held = os.clock() - pressedAt
		pressedAt = nil
		local origin, direction = CameraController.aimRay()
		Net.event("Ping"):FireServer(origin, direction, held >= Ping.HOLD_FOR_RESUPPLY)
	end)
	Net.event("PingShown").OnClientEvent:Connect(Markers.ping)
end

return Ping
