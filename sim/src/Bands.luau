--!strict
-- The three player skill bands. Each is a set of human factors the simulation layers over the
-- game's own weapon and enemy numbers. These are modelling assumptions, not game data: the second
-- audit run should recalibrate them from playtest telemetry (hit rate, weakspot share, time firing).

export type Band = {
	name: string,
	-- Aim error, one standard deviation per axis, in degrees, before spread and recoil.
	aim: number,
	-- Seconds of lag when tracking a target sideways (angular speed x lag = extra aim error).
	trackLag: number,
	-- Share of each recoil kick still uncorrected when the next shot leaves.
	recoilResidual: number,
	-- How often the player deliberately aims for an exposed weakspot (0..1).
	weakspotIntent: number,
	-- Share of combat time spent firing at a target (not moving, swapping, looking around).
	uptime: number,
	-- Seconds to acquire the next target after a kill.
	reaction: number,
	-- Share of the time a flame cone stays on its target.
	streamAim: number,
	-- Impact error of lobbed shots and grenades, in studs, before target movement.
	lobError: number,
	-- Share of a target's sideways motion the player fails to lead with lobbed shots.
	leadError: number,
	-- Share of melee swings that connect (kiting and backpedalling avoid the rest).
	meleeTaken: number,
	-- Share of acid spit (Wasp, Spitter) that splashes the player.
	spitTaken: number,
	-- Share of Ravager charges that connect.
	chargeTaken: number,
	-- Enemies close before a grenade or satchel is thrown into a crowd.
	grenadeCrowd: number,
	-- How well fences and domes are placed (share of the ideal coverage).
	placement: number,
	-- Travel and mining speed relative to an average player.
	pace: number,
}

local Bands = {}

Bands.LIST = {
	{
		name = "low",
		aim = 1.6,
		trackLag = 0.12,
		recoilResidual = 0.6,
		weakspotIntent = 0.15,
		uptime = 0.55,
		reaction = 0.6,
		streamAim = 0.8,
		lobError = 3.2,
		leadError = 0.7,
		meleeTaken = 0.95,
		spitTaken = 0.7,
		chargeTaken = 0.85,
		grenadeCrowd = 6,
		placement = 0.5,
		pace = 0.8,
	},
	{
		name = "mid",
		aim = 1.0,
		trackLag = 0.08,
		recoilResidual = 0.4,
		weakspotIntent = 0.5,
		uptime = 0.7,
		reaction = 0.4,
		streamAim = 0.9,
		lobError = 2.2,
		leadError = 0.45,
		meleeTaken = 0.8,
		spitTaken = 0.5,
		chargeTaken = 0.6,
		grenadeCrowd = 5,
		placement = 0.7,
		pace = 1,
	},
	{
		name = "high",
		aim = 0.6,
		trackLag = 0.05,
		recoilResidual = 0.25,
		weakspotIntent = 0.85,
		uptime = 0.85,
		reaction = 0.25,
		streamAim = 0.97,
		lobError = 1.4,
		leadError = 0.25,
		meleeTaken = 0.65,
		spitTaken = 0.35,
		chargeTaken = 0.4,
		grenadeCrowd = 4,
		placement = 0.9,
		pace = 1.15,
	},
} :: { Band }

Bands.BY_NAME = {} :: { [string]: Band }
for _, band in Bands.LIST do
	Bands.BY_NAME[band.name] = band
end

return Bands
