--!strict
-- The upgrades terminal: three tiers of two choices for each of your class's five items.
-- Buying equips the choice; switching between bought choices is free.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)
local Progress = require(Shared.Progress)
local Progression = require(Shared.Config.Progression)
local ToolsConfig = require(Shared.Config.Tools)
local Upgrades = require(Shared.Config.Upgrades)
local Weapons = require(Shared.Config.Weapons)

local Client = ReplicatedStorage.Client
local Menu = require(Client.UI.Menu)
local Theme = require(Client.UI.Theme)
local ProgressView = require(Client.ProgressView)

local UpgradesMenu = {}

local function itemName(id: string): string
	local weapon = (Weapons.STATS :: any)[id]
	if weapon then
		return weapon.displayName
	end
	return (ToolsConfig.TOOLS[id] or ToolsConfig.GRENADES[id]).displayName
end

-- The class level at which a tier opens for this item.
local function unlockLevel(itemId: string, tier: number): number
	local kind = if Upgrades.WEAPON_ITEMS[itemId] then "weapons" else "tools"
	for level = 1, Progression.MAX_LEVEL do
		if Progression.TIER_UNLOCKS[level][kind] >= tier then
			return level
		end
	end
	return Progression.MAX_LEVEL
end

local function choiceCell(
	parent: Instance,
	data: Progress.Data,
	classId: Classes.ClassId,
	itemId: string,
	tier: number,
	choice: Upgrades.Choice
)
	local upgrade = Upgrades.ITEMS[itemId][tier][choice]
	local id = Upgrades.id(itemId, tier, choice)
	local progress = data.classes[classId]
	local owned = progress.owned[id] == true
	local equipped = owned and progress.equipped[`{itemId}.{tier}`] == choice
	local open = tier <= Progress.tierOpen(data, classId, itemId)
	local cost = Progression.UPGRADE_COST[tier]

	local cell = Instance.new("Frame")
	cell.BackgroundColor3 = if equipped then Color3.fromRGB(34, 52, 40) else Color3.fromRGB(30, 26, 40)
	cell.BorderSizePixel = 0
	cell.Size = UDim2.new(0.5, -4, 1, 0)
	cell.LayoutOrder = if choice == "A" then 1 else 2
	cell.Parent = parent
	Theme.corner(cell)
	Theme.label(cell, {
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Theme.FONT_BOLD,
		TextSize = 13,
		TextColor3 = if open then Theme.TEXT else Theme.TEXT_DIM,
		Text = upgrade.name,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Theme.label(cell, {
		Position = UDim2.fromOffset(8, 20),
		Size = UDim2.new(1, -16, 0, 40),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.TEXT_DIM,
		Text = upgrade.description,
	})
	local text, style, action
	if not open then
		text, style = `Level {unlockLevel(itemId, tier)}`, "Disabled"
	elseif equipped then
		text, style = "Equipped", "Selected"
	elseif owned then
		text, style, action = "Equip", "Secondary", "EquipUpgrade"
	elseif data.credits >= cost then
		text, style, action = `Buy  {cost}`, "Primary", "BuyUpgrade"
	else
		text, style = `{cost} credits`, "Disabled"
	end
	local button = Menu.button(cell, text, function()
		if action then
			Net.func(action):InvokeServer(id)
		end
	end, style)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 8, 1, -6)
	button.Size = UDim2.new(1, -16, 0, 24)
	button.TextSize = 12
end

local function render(content: Frame, data: Progress.Data)
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local classId = data.selectedClass
	local info = Classes.INFO[classId]
	Theme.label(content, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.FONT_BOLD,
		TextColor3 = info.color,
		Text = `{info.displayName}  ·  Level {Progress.level(data, classId)}      Credits: {data.credits}`,
	})
	for tier = 1, 3 do
		Theme.label(content, {
			Position = UDim2.new(0.16 + (tier - 1) * 0.28, 4, 0, 30),
			Size = UDim2.new(0.28, -8, 0, 18),
			Font = Theme.FONT_BOLD,
			TextSize = 13,
			TextColor3 = Theme.TEXT_DIM,
			Text = `TIER {tier}  ·  {Progression.UPGRADE_COST[tier]} CREDITS`,
		})
	end
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 54)
	grid.Size = UDim2.new(1, 0, 1, -54)
	grid.Parent = content
	Menu.list(grid, 6)
	for row, itemId in Progress.items(classId) do
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0.2, -6)
		line.LayoutOrder = row
		line.Parent = grid
		Theme.label(line, {
			Size = UDim2.fromScale(0.16, 1),
			Font = Theme.FONT_BOLD,
			TextSize = 14,
			TextWrapped = true,
			Text = itemName(itemId),
		})
		for tier = 1, 3 do
			local pair = Instance.new("Frame")
			pair.BackgroundTransparency = 1
			pair.Position = UDim2.new(0.16 + (tier - 1) * 0.28, 4, 0, 0)
			pair.Size = UDim2.new(0.28, -8, 1, 0)
			pair.Parent = line
			local layout = Menu.list(pair, 8)
			layout.FillDirection = Enum.FillDirection.Horizontal
			for _, choice in { "A", "B" } :: { Upgrades.Choice } do
				choiceCell(pair, data, classId, itemId, tier, choice)
			end
		end
	end
end

function UpgradesMenu.open()
	local content = Menu.open("Upgrades", 1180, 624)
	local connection: RBXScriptConnection? = nil
	connection = ProgressView.observe(function(data)
		if not content.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		render(content, data)
	end)
end

return UpgradesMenu
