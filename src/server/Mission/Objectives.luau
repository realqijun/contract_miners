--!strict
-- Watches the main objective and calls the Lift Pod once it is done.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionState = require(ReplicatedStorage.Shared.MissionState)

local Extraction = require(script.Parent.Extraction)
local RefineryMission = require(script.Parent.RefineryMission)
local Runtime = require(script.Parent.Runtime)

local Objectives = {}

local KEYS = MissionState.KEYS

function Objectives.start()
	if Runtime.get().launch.missionType == "Mining" then
		MissionState.observe(KEYS.Deposited, function(deposited)
			local target = MissionState.get(KEYS.Target)
			if type(deposited) == "number" and type(target) == "number" and deposited >= target then
				Extraction.call(nil)
			end
		end)
	else
		RefineryMission.start()
	end
end

return Objectives
