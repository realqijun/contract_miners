--!strict
-- The mission's ending: success or failure, rewards, the results screen, and the trip home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Missions = require(Shared.Config.Missions)
local MissionState = require(Shared.MissionState)
local Places = require(Shared.Config.Places)
local Progression = require(Shared.Config.Progression)

local Runtime = require(script.Parent.Runtime)

local Flow = {}

local KEYS = MissionState.KEYS

export type Reward = { credits: number, xp: number, leftBehind: boolean }

local endedListeners: { (Progression.Outcome, { [Player]: Reward }) -> () } = {}
local finished = false

function Flow.begin()
	MissionState.set(KEYS.StartedAt, Workspace:GetServerTimeNow())
	MissionState.set(KEYS.Phase, "Active")
end

function Flow.isOver(): boolean
	return finished
end

local function sendHome()
	if RunService:IsStudio() or not Places.published() then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Places.HUB, players)
	end)
	if not ok then
		warn("Returning crew to the hub failed:", err)
	end
end

-- Ends the mission. `escaped` lists who made it aboard the Lift Pod (success only).
local function finish(outcome: Progression.Outcome, reason: string, escaped: { [Player]: boolean }?)
	if finished then
		return
	end
	finished = true
	local missionType = Runtime.get().launch.missionType
	local delivered = MissionState.get(KEYS.Deposited) or 0
	local rewards: { [Player]: Reward } = {}
	for _, player in Players:GetPlayers() do
		local leftBehind = outcome == "Success" and not (escaped and escaped[player])
		local credits, xp = Progression.reward(missionType, outcome, delivered, leftBehind)
		-- The walkthrough is practice and pays nothing.
		if Runtime.get().launch.walkthrough then
			credits, xp = 0, 0
		end
		rewards[player] = { credits = credits, xp = xp, leftBehind = leftBehind }
		player:SetAttribute("RewardCredits", credits)
		player:SetAttribute("RewardXP", xp)
		player:SetAttribute("LeftBehind", leftBehind)
	end
	local now = Workspace:GetServerTimeNow()
	MissionState.set(KEYS.Outcome, outcome)
	MissionState.set(KEYS.OutcomeReason, reason)
	MissionState.set(KEYS.EndedAt, now)
	MissionState.set(KEYS.ReturnAt, now + Missions.RESULTS_SECONDS)
	MissionState.set(KEYS.Phase, "Ended")
	for _, listener in endedListeners do
		task.spawn(listener, outcome, rewards)
	end
	task.delay(Missions.RESULTS_SECONDS, sendHome)
end

function Flow.fail(reason: string)
	finish("Failure", reason, nil)
end

function Flow.succeed(escaped: { [Player]: boolean })
	finish("Success", "Extraction complete", escaped)
end

-- Called with the outcome and every player's reward once the mission ends (saving progress).
function Flow.onEnded(callback: (Progression.Outcome, { [Player]: Reward }) -> ())
	table.insert(endedListeners, callback)
end

return Flow
