--!strict
-- A small seeded random generator, so every simulation run is reproducible.
-- Park-Miller "minimal standard" generator: exact in double precision and fast in Luau.

export type Rng = {
	state: number,
	next: (self: Rng) -> number,
	range: (self: Rng, low: number, high: number) -> number,
	int: (self: Rng, low: number, high: number) -> number,
	normal: (self: Rng) -> number,
	chance: (self: Rng, probability: number) -> boolean,
	exponential: (self: Rng, mean: number) -> number,
}

local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Rng) :: any
end

-- Uniform in [0, 1).
function Rng.next(self: Rng): number
	self.state = (self.state * MULTIPLIER) % MODULUS
	return (self.state - 1) / (MODULUS - 1)
end

function Rng.range(self: Rng, low: number, high: number): number
	return low + (high - low) * self:next()
end

function Rng.int(self: Rng, low: number, high: number): number
	return math.min(high, low + math.floor(self:next() * (high - low + 1)))
end

-- Standard normal (Box-Muller).
function Rng.normal(self: Rng): number
	local u = math.max(1e-12, self:next())
	return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * self:next())
end

function Rng.chance(self: Rng, probability: number): boolean
	return self:next() < probability
end

function Rng.exponential(self: Rng, mean: number): number
	return -mean * math.log(math.max(1e-12, 1 - self:next()))
end

return Rng
