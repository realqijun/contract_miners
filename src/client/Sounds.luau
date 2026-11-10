--!strict
-- Plays the sounds in Config.Audio: one-shots in the world or straight to the listener, and loops.
-- Each sound goes through its Music or Effects group, so the volume settings apply.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Audio)
local Audio = require(script.Parent.Audio)

local Sounds = {}

local lastPlayed: { [string]: number } = {}
local rng = Random.new()

local function build(name: string, parent: Instance): Sound?
	local spec = AudioConfig.SOUNDS[name]
	if not spec then
		warn("Unknown sound", name)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	local vary = spec.vary or 0
	sound.PlaybackSpeed = (spec.speed or 1) * (1 + rng:NextNumber(-vary, vary))
	sound.SoundGroup = Audio.group(spec.group)
	if spec.reach then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = spec.reach
	end
	sound.Parent = parent
	return sound
end

local function ready(name: string): boolean
	local spec = AudioConfig.SOUNDS[name]
	local now = os.clock()
	if spec and spec.gap and now - (lastPlayed[name] or -math.huge) < spec.gap then
		return false
	end
	lastPlayed[name] = now
	return true
end

-- Plays a sound once. With a position it comes from that point in the world; without one it
-- plays straight to the listener. `volumeScale` adjusts this one playback.
function Sounds.play(name: string, position: Vector3?, volumeScale: number?)
	if not ready(name) then
		return
	end
	local parent: Instance
	if position then
		local holder = Instance.new("Attachment")
		holder.Name = "SoundAt"
		-- Terrain sits at the origin, so its attachments' positions are world positions.
		holder.Position = position
		holder.Parent = Workspace.Terrain
		parent = holder
	else
		parent = SoundService
	end
	local sound = build(name, parent)
	if not sound then
		return
	end
	sound.Volume *= volumeScale or 1
	sound.Ended:Connect(function()
		(if position then parent else sound):Destroy()
	end)
	-- In case the sound never loads or ends.
	Debris:AddItem(if position then parent else sound, 20)
	sound:Play()
end

-- A looping sound that plays straight to the listener; the caller fades and stops it.
function Sounds.loop(name: string): Sound?
	local sound = build(name, SoundService)
	if sound then
		sound.Looped = true
	end
	return sound
end

return Sounds
