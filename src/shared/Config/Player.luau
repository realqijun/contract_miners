--!strict
-- Player movement and vitals tuning.

local Player = {}

Player.WALK_SPEED = 14
Player.SPRINT_SPEED = 21
Player.CROUCH_SPEED = 8
Player.JUMP_POWER = 42

Player.MAX_HEALTH = 100
Player.MAX_SHIELD = 30
-- Seconds without damage before the shield starts recharging.
Player.SHIELD_REGEN_DELAY = 5
Player.SHIELD_REGEN_PER_SECOND = 12

-- Falls longer than this many studs hurt; damage grows per stud beyond it.
Player.FALL_DAMAGE_HEIGHT = 25
Player.FALL_DAMAGE_PER_STUD = 3.2

-- Server movement check. Horizontal travel may not outpace sprinting by more than the tolerance,
-- plus a little slack for jitter. Time spent standing still banks travel budget, up to a cap, so
-- positions that arrive in a burst after a lag spike still pass.
Player.SPEED_CHECK_TOLERANCE = 1.2
Player.SPEED_CHECK_SLACK = 4
Player.SPEED_CHECK_BUDGET_SECONDS = 2.5
-- A grapple pull and the hop after it are exempt from the speed check and do not count as falling.
Player.GRAPPLE_GRACE_SECONDS = 2.5

Player.BLEED_OUT_SECONDS = 40
Player.REVIVE_SECONDS = 3
Player.REVIVE_HEALTH_FRACTION = 0.3
-- A revived miner takes no damage for this long, so the Vrill that downed them cannot drop them
-- again before they can act.
Player.REVIVE_PROTECTION_SECONDS = 2.5

Player.HEADLAMP_RANGE = 72
Player.HEADLAMP_ANGLE = 62
Player.HEADLAMP_BRIGHTNESS = 4.5
Player.HEADLAMP_COLOR = Color3.fromRGB(255, 240, 214)

return Player
