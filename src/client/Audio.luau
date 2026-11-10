--!strict
-- Music and effects sound groups, kept at the volumes the player set. Every sound the client
-- plays goes into one of these groups.

local SoundService = game:GetService("SoundService")

local Settings = require(script.Parent.Settings)

local Audio = {}

export type Group = "Music" | "Effects"

local groups: { [Group]: SoundGroup } = {}

local function ensure(name: Group): SoundGroup
	local group = groups[name]
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
		groups[name] = group
	end
	return group :: SoundGroup
end

function Audio.group(name: Group): SoundGroup
	return ensure(name)
end

function Audio.start()
	local music, effects = ensure("Music"), ensure("Effects")
	Settings.observe(function(values)
		music.Volume = values.masterVolume * values.musicVolume
		effects.Volume = values.masterVolume * values.sfxVolume
	end)
end

return Audio
