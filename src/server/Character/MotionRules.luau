--!strict
-- Pure rules for the server's view of crew movement: fall damage and the speed check.
-- Motion feeds them sampled root positions; nothing here touches the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)

local MotionRules = {}

export type Track = {
	-- Highest root height since the character last stood on something or rode a traversal tool.
	peakY: number?,
	-- The last position that passed the speed check.
	anchor: Vector3,
	-- Horizontal studs the character may still travel. It refills over time at the allowed speed,
	-- up to a cap, and every sample spends the distance moved.
	budget: number,
	checkedAt: number,
}

function MotionRules.new(position: Vector3, now: number): Track
	-- Starts full; the first check clamps it to the cap for the character's speed.
	return { peakY = nil, anchor = position, budget = math.huge, checkedAt = now }
end

function MotionRules.fallDamage(drop: number): number
	return math.max(0, drop - PlayerConfig.FALL_DAMAGE_HEIGHT) * PlayerConfig.FALL_DAMAGE_PER_STUD
end

-- Feeds one sample of root height. `grounded` means standing on something; `supported` means
-- held up by a grapple or cable, which restarts the fall from wherever it lets go.
-- Returns the fall damage to apply on this sample.
function MotionRules.fall(track: Track, y: number, grounded: boolean, supported: boolean): number
	if supported then
		track.peakY = nil
		return 0
	end
	if grounded then
		local peak = track.peakY
		track.peakY = nil
		return if peak then MotionRules.fallDamage(peak - y) else 0
	end
	track.peakY = math.max(track.peakY or y, y)
	return 0
end

-- The most travel budget a character can bank at `maxSpeed`.
function MotionRules.budgetCap(maxSpeed: number): number
	return maxSpeed * PlayerConfig.SPEED_CHECK_TOLERANCE * PlayerConfig.SPEED_CHECK_BUDGET_SECONDS
		+ PlayerConfig.SPEED_CHECK_SLACK
end

-- Feeds one sample of root position. Exempt samples (traversal tools) always pass.
-- Returns false when the character has travelled further than its budget allows; the caller then
-- puts it back at `track.anchor`. Average speed is held to the allowed speed, while a short burst,
-- such as positions arriving late after a lag spike, can spend what was banked.
function MotionRules.checkSpeed(
	track: Track,
	position: Vector3,
	now: number,
	maxSpeed: number,
	exempt: boolean
): boolean
	local rate = maxSpeed * PlayerConfig.SPEED_CHECK_TOLERANCE
	track.budget = math.min(MotionRules.budgetCap(maxSpeed), track.budget + rate * (now - track.checkedAt))
	track.checkedAt = now
	if exempt then
		track.anchor = position
		return true
	end
	local offset = position - track.anchor
	track.budget -= Vector3.new(offset.X, 0, offset.Z).Magnitude
	if track.budget < 0 then
		track.budget = 0
		return false
	end
	track.anchor = position
	return true
end

return MotionRules
