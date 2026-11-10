--!strict
-- The local player's saved progress as replicated by the server, for menus to display.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)

local ProgressView = {}

local player = Players.LocalPlayer

function ProgressView.get(): Progress.Data?
	local raw = player:GetAttribute("Progress")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then data else nil
end

-- Calls `callback` with fresh data now (if loaded) and whenever it changes.
function ProgressView.observe(callback: (Progress.Data) -> ()): RBXScriptConnection
	local function fire()
		local data = ProgressView.get()
		if data then
			callback(data)
		end
	end
	fire()
	return player:GetAttributeChangedSignal("Progress"):Connect(fire)
end

return ProgressView
