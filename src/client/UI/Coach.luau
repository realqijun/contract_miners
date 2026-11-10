--!strict
-- The walkthrough's instruction card: the current step and what to do, written with the
-- player's own bindings for keyboard or gamepad. It also reports the camera switch, which the
-- server cannot see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local MissionState = require(Shared.MissionState)
local Net = require(Shared.Net)
local WalkthroughConfig = require(Shared.Config.Walkthrough)

local Client = script.Parent.Parent
local CameraController = require(Client.Character.CameraController)
local Input = require(Client.Input)
local Theme = require(script.Parent.Theme)

local Coach = {}

local KEYS = MissionState.KEYS
local player = Players.LocalPlayer

-- Words for the placeholders that are not Input actions.
local EXTRA_LABELS = {
	keyboard = { Look = "the mouse", Move = "WASD", Jump = "Space" },
	gamepad = { Look = "the right stick", Move = "the left stick", Jump = "A" },
}

-- Fills each {Placeholder} with the binding for the device in use, in bold accent.
local function format(template: string): string
	local device = if Input.isGamepad() then "gamepad" else "keyboard"
	return (
		string.gsub(template, "{(%w+)}", function(name: string)
			local label = (EXTRA_LABELS :: any)[device][name] or Input.LABELS[device][name :: any]
			if not label and name == "Primary" and device == "gamepad" then
				label = Input.LABELS.gamepad.CycleWeapon
			end
			return `<font color="#FFB040"><b>{label or name}</b></font>`
		end)
	)
end

local function textFor(step: WalkthroughConfig.Step): string
	if step == "Climb" then
		local classId = player:GetAttribute("Class")
		return WalkthroughConfig.CLIMB_TEXT[if type(classId) == "string" then classId else "Scout"]
			or WalkthroughConfig.CLIMB_TEXT.Scout
	end
	return WalkthroughConfig.TEXT[step]
end

function Coach.start()
	if MissionState.get(KEYS.Walkthrough) ~= true then
		-- Mission state arrives before the client starts; only the walkthrough shows a coach.
		local connection: RBXScriptConnection
		connection = MissionState.observe(KEYS.Walkthrough, function(value)
			if value == true then
				connection:Disconnect()
				Coach.start()
			end
		end)
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Coach"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top centre, below the compass and the swarm banner, and between the objective and team
	-- panels in the corners, which are 300 wide with a 24 margin.
	local card = Theme.panel("Card", gui)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 136)
	card.Size = UDim2.new(1, -2 * (24 + 300 + 20), 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(360, 0)
	limit.MaxSize = Vector2.new(600, math.huge)
	limit.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ACCENT
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = card

	local heading = Theme.label(card, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.FONT_HEAVY,
		TextSize = 14,
		TextColor3 = Theme.ACCENT,
	})
	local body = Theme.label(card, {
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 17,
		TextWrapped = true,
		RichText = true,
	})

	local function render()
		local step = MissionState.get(KEYS.WalkthroughStep)
		local index = MissionState.get(KEYS.WalkthroughIndex)
		card.Visible = type(step) == "string" and MissionState.get(KEYS.Phase) ~= "Ended"
		if not card.Visible then
			return
		end
		heading.Text = `WALKTHROUGH  ·  STEP {index} OF {#WalkthroughConfig.STEPS}`
		body.Text = format(textFor(step :: WalkthroughConfig.Step))
	end
	MissionState.observe(KEYS.WalkthroughStep, function()
		render()
		-- A brief outline flash marks each new step.
		stroke.Transparency = 0
		TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end)
	MissionState.observe(KEYS.Phase, render)
	-- Bindings in the text follow whichever device was used last.
	UserInputService.LastInputTypeChanged:Connect(render)
	player:GetAttributeChangedSignal("Class"):Connect(render)

	CameraController.onModeChanged(function()
		Net.event("WalkthroughAction"):FireServer("CameraToggle")
	end)
end

return Coach
