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

Player.BLEED_OUT_SECONDS = 40
Player.REVIVE_SECONDS = 3
Player.REVIVE_HEALTH_FRACTION = 0.3

Player.HEADLAMP_RANGE = 72
Player.HEADLAMP_ANGLE = 62
Player.HEADLAMP_BRIGHTNESS = 4.5
Player.HEADLAMP_COLOR = Color3.fromRGB(255, 240, 214)

return Player
