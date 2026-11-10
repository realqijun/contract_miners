--!strict
-- Hub place entry point: the crew ship's deck, saved progress, class gear, terminals and launch bays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)
local Progress = require(Shared.Progress)

local Server = ServerScriptService.Server
local PlayerData = require(Server.Data.PlayerData)
local Gear = require(Server.Character.Gear)
local Deck = require(script.Parent.Deck)
local LaunchPads = require(script.Parent.LaunchPads)

-- The walkthrough runs in its own fixed cave; the seed only labels it.
local WALKTHROUGH_SEED = 1

Net.createAll()
PlayerData.start()
local built = Deck.build()
LaunchPads.start(built)

local function dress(player: Player)
	local character = player.Character
	local data = PlayerData.get(player)
	if character and data then
		player:SetAttribute("Class", data.selectedClass)
		Gear.equip(character, data.selectedClass)
	end
end

local function arrive(player: Player)
	-- Selecting a class at the terminal re-dresses the character straight away.
	player:GetAttributeChangedSignal("Class"):Connect(function()
		local classId = player:GetAttribute("Class")
		if player.Character and Classes.isClassId(classId) then
			Gear.equip(player.Character, classId)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		local jitter = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		character:PivotTo(built.spawn + jitter)
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		PlayerData.await(player)
		dress(player)
	end)
end
Players.PlayerAdded:Connect(arrive)
for _, player in Players:GetPlayers() do
	arrive(player)
end

Net.event("Walkthrough").OnServerEvent:Connect(function(player, play)
	PlayerData.update(player, function(data)
		data.walkthroughOffered = true
	end)
	if play == true then
		local data = PlayerData.get(player)
		LaunchPads.teleport({ player }, {
			missionType = "Mining",
			seed = WALKTHROUGH_SEED,
			partySize = 1,
			classes = { [tostring(player.UserId)] = if data then data.selectedClass else "Scout" },
			walkthrough = true,
		})
	end
end)

-- Studio-only test hooks: setting DevCredits or DevXp on Workspace grants that much to every
-- player (XP to their selected class), so automated playtests can reach upgrades and tiers.
if RunService:IsStudio() then
	local function grant(attribute: string, apply: (Progress.Data, number) -> ())
		Workspace:GetAttributeChangedSignal(attribute):Connect(function()
			local amount = Workspace:GetAttribute(attribute)
			if type(amount) ~= "number" or amount <= 0 then
				return
			end
			for _, player in Players:GetPlayers() do
				PlayerData.update(player, function(data)
					apply(data, amount)
				end)
			end
		end)
	end
	grant("DevCredits", function(data, amount)
		data.credits += amount
	end)
	grant("DevXp", function(data, amount)
		data.classes[data.selectedClass].xp += amount
	end)
end
