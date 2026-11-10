--!strict
-- Mission-wide state replicated to every client as attributes on ReplicatedStorage.Mission.
-- The server writes; clients read and listen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MissionState = {}

export type Phase = "Loading" | "Active" | "Extraction" | "Ended"

MissionState.KEYS = {
	Phase = "Phase",
	MissionType = "MissionType",
	Seed = "Seed",
	PartySize = "PartySize",
	-- Mining: Volticite deposited and the target.
	Deposited = "Deposited",
	Target = "Target",
	-- Team Ferrin pool, spent on resupply pods.
	Ferrin = "Ferrin",
	-- Server time the latest swarm was called, for the warning banner.
	Swarm = "Swarm",
	-- Server time the mission went active, and when it ended.
	StartedAt = "StartedAt",
	EndedAt = "EndedAt",
	-- "Success" or "Failure" once ended, with a short reason.
	Outcome = "Outcome",
	OutcomeReason = "OutcomeReason",
	-- Server time the crew returns to the hub.
	ReturnAt = "ReturnAt",
	-- Extraction: when the Lift Pod lands and when it launches, and how many are aboard.
	LiftLandsAt = "LiftLandsAt",
	LiftLaunchAt = "LiftLaunchAt",
	Aboard = "Aboard",
	-- Refinery: stage ("Site", "Dropping", "Pipes", "Pumping", "Launching", "Done"), wells hooked up,
	-- pumping progress 0..1 and how many pipe spans are broken.
	RefineryStage = "RefineryStage",
	WellsConnected = "WellsConnected",
	PumpProgress = "PumpProgress",
	PipesBroken = "PipesBroken",
}

local function holder(): Instance
	local existing = ReplicatedStorage:FindFirstChild("Mission")
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new("Configuration")
		created.Name = "Mission"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Mission")
end

function MissionState.get(key: string): any
	return holder():GetAttribute(key)
end

function MissionState.set(key: string, value: any)
	assert(RunService:IsServer(), "Only the server writes mission state")
	holder():SetAttribute(key, value)
end

-- Calls `callback` now and whenever the value changes. Returns the connection.
function MissionState.observe(key: string, callback: (value: any) -> ()): RBXScriptConnection
	local target = holder()
	callback(target:GetAttribute(key))
	return target:GetAttributeChangedSignal(key):Connect(function()
		callback(target:GetAttribute(key))
	end)
end

return MissionState
