--!strict
-- Saved player progress through ProfileStore, in both places. A profile is session-locked while the
-- player is in a server, so moving between the hub and a mission never loses or duplicates data.
-- A JSON snapshot is replicated as the "Progress" attribute for menus to read.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)
local Progress = require(Shared.Progress)
local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)

local PlayerData = {}

local STORE_NAME = "ContractMinersPlayers_v1"
local SETTING_LIMITS: { [string]: { number } } = {
	mouseSensitivity = { 0.1, 4 },
	gamepadSensitivity = { 0.1, 4 },
	fieldOfView = { 60, 100 },
	masterVolume = { 0, 1 },
	musicVolume = { 0, 1 },
	sfxVolume = { 0, 1 },
	aimAssist = { 0, 1 },
}

local store = ProfileStore.New(STORE_NAME, Progress.template())
local profiles: { [Player]: any } = {}
local loadedListeners: { (Player, Progress.Data) -> () } = {}

local function publish(player: Player)
	local profile = profiles[player]
	if profile then
		player:SetAttribute("Progress", HttpService:JSONEncode(profile.Data))
		player:SetAttribute("Credits", profile.Data.credits)
	end
end

local function load(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Your save could not be loaded. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened in another server. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	publish(player)
	for _, listener in loadedListeners do
		task.spawn(listener, player, profile.Data)
	end
end

-- The player's data once loaded, waiting for it if needed. Nil if they left first.
function PlayerData.await(player: Player): Progress.Data?
	while player.Parent == Players and not profiles[player] do
		task.wait(0.1)
	end
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerData.get(player: Player): Progress.Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Applies a change to the player's data and republishes it.
function PlayerData.update(player: Player, change: (Progress.Data) -> ())
	local profile = profiles[player]
	if profile then
		change(profile.Data)
		publish(player)
	end
end

function PlayerData.onLoaded(callback: (Player, Progress.Data) -> ())
	table.insert(loadedListeners, callback)
end

local function saveSettings(player: Player, settings: unknown)
	if type(settings) ~= "table" then
		return
	end
	PlayerData.update(player, function(data)
		for key, value in settings :: { [string]: any } do
			local limits = SETTING_LIMITS[key]
			if limits and type(value) == "number" and value == value then
				data.settings[key] = math.clamp(value, limits[1], limits[2])
			elseif key == "invertY" and type(value) == "boolean" then
				data.settings[key] = value
			end
		end
	end)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
	Net.event("SaveSettings").OnServerEvent:Connect(saveSettings)
	Net.func("BuyUpgrade").OnServerInvoke = function(player, upgradeId)
		local data = PlayerData.get(player)
		if not data or type(upgradeId) ~= "string" then
			return false, "Not loaded"
		end
		local ok, reason = Progress.canBuy(data, data.selectedClass, upgradeId)
		if ok then
			PlayerData.update(player, function(current)
				Progress.buy(current, current.selectedClass, upgradeId)
			end)
		end
		return ok, reason
	end
	Net.func("EquipUpgrade").OnServerInvoke = function(player, upgradeId)
		local data = PlayerData.get(player)
		if not data or type(upgradeId) ~= "string" then
			return false, "Not loaded"
		end
		local ok = false
		PlayerData.update(player, function(current)
			ok = Progress.equip(current, current.selectedClass, upgradeId)
		end)
		return ok, if ok then nil else "Not owned"
	end
	Net.func("SelectClass").OnServerInvoke = function(player, classId)
		if not Classes.isClassId(classId) or not PlayerData.get(player) then
			return false, "Unknown class"
		end
		PlayerData.update(player, function(current)
			current.selectedClass = classId :: Classes.ClassId
		end)
		player:SetAttribute("Class", classId)
		return true, nil
	end
end

return PlayerData
