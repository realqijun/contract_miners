--!strict
-- Health and shield for crew members. All damage to players goes through Vitals.damage.
-- Health never reaches zero through damage: a player at zero is "downed" instead, which the
-- revive system handles. Shield absorbs damage first and recharges after a quiet spell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)

local Vitals = {}

type State = {
	character: Model,
	humanoid: Humanoid,
	shield: number,
	lastDamaged: number,
}

local states: { [Player]: State } = {}
local downedListeners: { (Player) -> () } = {}
local damagedListeners: { (Player, number) -> () } = {}

-- Shield is replicated as a whole number so regeneration does not send an update every frame.
local function publish(player: Player, state: State)
	local shown = math.ceil(state.shield)
	if player:GetAttribute("Shield") ~= shown then
		player:SetAttribute("Shield", shown)
	end
	player:SetAttribute("MaxShield", PlayerConfig.MAX_SHIELD)
end

-- Starts tracking a freshly spawned character at full health and shield.
function Vitals.track(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- The default regeneration script would heal players outside the game's rules.
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = PlayerConfig.MAX_HEALTH
	humanoid.Health = PlayerConfig.MAX_HEALTH
	local state = { character = character, humanoid = humanoid, shield = PlayerConfig.MAX_SHIELD, lastDamaged = 0 }
	states[player] = state
	player:SetAttribute("Downed", false)
	publish(player, state)
end

function Vitals.isDowned(player: Player): boolean
	return player:GetAttribute("Downed") == true
end

function Vitals.isAlive(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.character.Parent ~= nil and not Vitals.isDowned(player)
end

-- Applies damage to shield then health. Downs the player instead of killing them.
function Vitals.damage(player: Player, amount: number)
	local state = states[player]
	if not state or amount <= 0 or not Vitals.isAlive(player) then
		return
	end
	state.lastDamaged = os.clock()
	local absorbed = math.min(state.shield, amount)
	state.shield -= absorbed
	local remaining = amount - absorbed
	local health = state.humanoid.Health - remaining
	if health <= 0 then
		-- Hold at a sliver of health so the Humanoid never enters its Dead state.
		state.humanoid.Health = 1
		state.shield = 0
		player:SetAttribute("Downed", true)
		publish(player, state)
		for _, listener in downedListeners do
			task.spawn(listener, player)
		end
		return
	end
	state.humanoid.Health = health
	publish(player, state)
	for _, listener in damagedListeners do
		task.spawn(listener, player, amount)
	end
end

function Vitals.heal(player: Player, amount: number)
	local state = states[player]
	if not state or not Vitals.isAlive(player) then
		return
	end
	state.humanoid.Health = math.min(state.humanoid.MaxHealth, state.humanoid.Health + amount)
end

-- Brings a downed player back up with a fraction of their health.
function Vitals.revive(player: Player, healthFraction: number)
	local state = states[player]
	if not state or not Vitals.isDowned(player) then
		return
	end
	player:SetAttribute("Downed", false)
	state.humanoid.Health = math.max(1, state.humanoid.MaxHealth * healthFraction)
	state.lastDamaged = os.clock()
	publish(player, state)
end

-- Full health and shield (resupply pods).
function Vitals.restore(player: Player)
	local state = states[player]
	if not state or not Vitals.isAlive(player) then
		return
	end
	state.humanoid.Health = state.humanoid.MaxHealth
	state.shield = PlayerConfig.MAX_SHIELD
	publish(player, state)
end

function Vitals.onDowned(callback: (Player) -> ())
	table.insert(downedListeners, callback)
end

function Vitals.onDamaged(callback: (Player, number) -> ())
	table.insert(damagedListeners, callback)
end

function Vitals.forget(player: Player)
	states[player] = nil
end

function Vitals.start()
	Players.PlayerRemoving:Connect(Vitals.forget)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, state in states do
			if
				state.shield < PlayerConfig.MAX_SHIELD
				and Vitals.isAlive(player)
				and now - state.lastDamaged >= PlayerConfig.SHIELD_REGEN_DELAY
			then
				state.shield =
					math.min(PlayerConfig.MAX_SHIELD, state.shield + PlayerConfig.SHIELD_REGEN_PER_SECOND * dt)
				publish(player, state)
			end
		end
	end)
end

return Vitals
