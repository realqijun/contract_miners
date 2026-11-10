--!strict
-- The data the hub sends with a party teleport, and its validation on arrival.
-- Teleport data passes through the client, so the Mission server never trusts it unchecked.

local Classes = require(script.Parent.Config.Classes)
local Missions = require(script.Parent.Config.Missions)

export type LaunchData = {
	missionType: Missions.MissionType,
	seed: number,
	-- Number of players on the launch pad; locks difficulty scaling.
	partySize: number,
	-- Chosen class per party member, keyed by UserId as a string.
	classes: { [string]: Classes.ClassId },
	-- True for the guided walkthrough.
	walkthrough: boolean,
}

local LaunchData = {}

LaunchData.MAX_SEED = 2 ^ 31 - 2

function LaunchData.validate(raw: unknown): LaunchData?
	if type(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: any }
	if not Missions.isMissionType(data.missionType) then
		return nil
	end
	local seed = data.seed
	if type(seed) ~= "number" or seed ~= math.floor(seed) or seed < 1 or seed > LaunchData.MAX_SEED then
		return nil
	end
	local partySize = data.partySize
	if
		type(partySize) ~= "number"
		or partySize ~= math.floor(partySize)
		or partySize < 1
		or partySize > Missions.MAX_PARTY
	then
		return nil
	end
	if type(data.classes) ~= "table" then
		return nil
	end
	local classes = {}
	local count = 0
	for userId, classId in data.classes do
		if type(userId) ~= "string" or not tonumber(userId) or not Classes.isClassId(classId) then
			return nil
		end
		count += 1
		classes[userId] = classId
	end
	if count == 0 or count > Missions.MAX_PARTY then
		return nil
	end
	return {
		missionType = data.missionType,
		seed = seed,
		partySize = partySize,
		classes = classes,
		walkthrough = data.walkthrough == true,
	}
end

return LaunchData
