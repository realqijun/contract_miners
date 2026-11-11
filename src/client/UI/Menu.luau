--!strict
-- Modal menus (terminals, settings) and the small widgets they are made of. One menu is open at a
-- time; opening one frees the mouse and pauses gameplay input until it closes.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Input = require(script.Parent.Parent.Input)

local Menu = {}

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local current: Frame? = nil
local closeListeners: { () -> () } = {}

local function screen(): ScreenGui
	if not gui then
		local created = Instance.new("ScreenGui")
		created.Name = "Menus"
		created.ResetOnSpawn = false
		created.IgnoreGuiInset = true
		created.DisplayOrder = 40
		created.Parent = player:WaitForChild("PlayerGui")
		gui = created
	end
	return gui :: ScreenGui
end

function Menu.isOpen(): boolean
	return current ~= nil
end

function Menu.close()
	if current then
		current:Destroy()
		current = nil
		Input.setEnabled(true)
		for _, listener in closeListeners do
			task.spawn(listener)
		end
	end
end

-- Called whenever a menu closes (the mission client re-locks the mouse).
function Menu.onClose(callback: () -> ())
	table.insert(closeListeners, callback)
end

-- Opens a titled panel and returns its content frame for the caller to fill.
function Menu.open(title: string, width: number, height: number): Frame
	Menu.close()
	Input.setEnabled(false)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Active = true
	backdrop.Parent = screen()
	current = backdrop

	local panel = Theme.panel("Panel", backdrop)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, height)
	panel.BackgroundTransparency = 0.05
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	-- Shrink to fit small screens.
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - 40) / width, (viewport.Y - 40) / height)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	Theme.label(panel, {
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.new(1, -120, 0, 32),
		Font = Theme.FONT_HEAVY,
		TextSize = 26,
		TextColor3 = Theme.ACCENT,
		Text = string.upper(title),
	})
	local close = Menu.button(panel, "Close", function()
		Menu.close()
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.Size = UDim2.fromOffset(90, 34)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(24, 62)
	content.Size = UDim2.new(1, -48, 1, -84)
	content.Parent = panel
	return content
end

export type ButtonStyle = "Primary" | "Secondary" | "Disabled" | "Selected"

-- The plain button colour, and the text colour that reads on an accent background.
Menu.SECONDARY = Color3.fromRGB(56, 50, 74)
Menu.ON_ACCENT = Color3.fromRGB(24, 16, 8)

local STYLE_COLORS: { [ButtonStyle]: Color3 } = {
	Primary = Theme.ACCENT,
	Secondary = Menu.SECONDARY,
	Disabled = Color3.fromRGB(40, 36, 50),
	Selected = Color3.fromRGB(110, 200, 120),
}

function Menu.button(parent: Instance, text: string, onClick: () -> (), style: ButtonStyle?): TextButton
	local chosen: ButtonStyle = style or "Secondary"
	local button = Instance.new("TextButton")
	button.AutoButtonColor = chosen ~= "Disabled"
	button.BackgroundColor3 = STYLE_COLORS[chosen]
	button.BorderSizePixel = 0
	button.Font = Theme.FONT_BOLD
	button.TextSize = 15
	button.TextColor3 = if chosen == "Primary" then Menu.ON_ACCENT else Theme.TEXT
	button.TextWrapped = true
	button.Text = text
	button.Size = UDim2.fromOffset(160, 36)
	button.Parent = parent
	Theme.corner(button)
	if chosen ~= "Disabled" then
		button.Activated:Connect(onClick)
	else
		button.TextColor3 = Theme.TEXT_DIM
	end
	return button
end

-- A labelled horizontal slider. `format` turns the value into its readout.
function Menu.slider(
	parent: Instance,
	label: string,
	min: number,
	max: number,
	value: number,
	format: (number) -> string,
	onChange: (number) -> ()
): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = parent
	Theme.label(row, { Size = UDim2.fromScale(0.4, 1), Text = label })
	local readout = Theme.label(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 70, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.FONT_BOLD,
	})
	local track = Instance.new("TextButton")
	track.Text = ""
	track.AutoButtonColor = false
	track.BackgroundColor3 = Theme.TRACK
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0.42, 0, 0.5, -4)
	track.Size = UDim2.new(0.58, -84, 0, 8)
	track.Parent = row
	Theme.corner(track, 4)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 4)
	local current_ = value
	local function render()
		local alpha = (current_ - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		readout.Text = format(current_)
	end
	local dragging = false
	local function setFromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		current_ = min + (max - min) * alpha
		render()
		onChange(current_)
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	-- Global input listeners live only as long as the slider does.
	local connections = {
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				setFromX(input.Position.X)
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end),
		-- Gamepad: left/right on a selected track nudges it.
		UserInputService.InputBegan:Connect(function(input)
			if GuiService.SelectedObject ~= track then
				return
			end
			local step = (max - min) / 20
			if input.KeyCode == Enum.KeyCode.DPadRight then
				current_ = math.min(max, current_ + step)
			elseif input.KeyCode == Enum.KeyCode.DPadLeft then
				current_ = math.max(min, current_ - step)
			else
				return
			end
			render()
			onChange(current_)
		end),
	}
	row.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	render()
	return row
end

function Menu.list(parent: Instance, padding: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 8)
	layout.Parent = parent
	return layout
end

-- Closes the open menu on the gamepad B button. The menu key toggles through `Menu.toggle`.
UserInputService.InputBegan:Connect(function(input)
	if current and input.KeyCode == Enum.KeyCode.ButtonB then
		Menu.close()
	end
end)

-- For the menu key: closes the open menu, or calls `openDefault` when none is open.
function Menu.toggle(openDefault: () -> ())
	if current then
		Menu.close()
	else
		openDefault()
	end
end

return Menu
