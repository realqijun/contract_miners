--!strict
-- Navigation aids: world markers (Dropcan, Lift Pod, objectives, teammates, pings) that show
-- through rock with a distance readout, and a compass strip that carries the same markers.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Theme = require(script.Parent.Theme)
local Hud = require(script.Parent.Hud)

local Markers = {}

type Marker = {
	gui: BillboardGui,
	distance: TextLabel,
	label: TextLabel,
	target: () -> Vector3?,
	color: Color3,
	pip: Frame?,
	expires: number?,
}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local markers: { [any]: Marker } = {}
local compass: Frame
local COMPASS_WIDTH = 360
local COMPASS_FOV = 180

local function makeBillboard(text: string, color: Color3): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.MaxDistance = 2000
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0)
	diamond.Position = UDim2.fromScale(0.5, 0)
	diamond.Size = UDim2.fromOffset(10, 10)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = color
	diamond.BorderSizePixel = 0
	diamond.Parent = gui
	local label = Theme.label(gui, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.FONT_BOLD,
		TextSize = 14,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})
	local distance = Theme.label(gui, {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Theme.TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	for _, text_ in { label, distance } do
		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.4
		stroke.Parent = text_
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, label, distance
end

local function makePip(color: Color3): Frame
	local pip = Instance.new("Frame")
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.Size = UDim2.fromOffset(8, 8)
	pip.Rotation = 45
	pip.BackgroundColor3 = color
	pip.BorderSizePixel = 0
	pip.Position = UDim2.fromScale(0.5, 0.75)
	pip.Parent = compass
	return pip
end

local function add(key: any, text: string, color: Color3, target: () -> Vector3?, adornee: Instance?, expires: number?)
	local gui, label, distance = makeBillboard(text, color)
	if adornee then
		gui.Adornee = adornee
	end
	markers[key] = {
		gui = gui,
		label = label,
		distance = distance,
		target = target,
		color = color,
		pip = makePip(color),
		expires = expires,
	}
end

local function remove(key: any)
	local marker = markers[key]
	if marker then
		marker.gui:Destroy()
		if marker.pip then
			marker.pip:Destroy()
		end
		markers[key] = nil
	end
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function trackTagged(instance: Instance)
	local label = instance:GetAttribute("MarkerLabel")
	local color = instance:GetAttribute("MarkerColor")
	add(
		instance,
		if type(label) == "string" then label else "Objective",
		if typeof(color) == "Color3" then color else Theme.ACCENT,
		function()
			return positionOf(instance)
		end,
		if instance:IsA("Model") then instance.PrimaryPart else instance
	)
	instance:GetAttributeChangedSignal("MarkerLabel"):Connect(function()
		local marker = markers[instance]
		local value = instance:GetAttribute("MarkerLabel")
		if marker and type(value) == "string" then
			marker.label.Text = value
		end
	end)
end

local function trackTeammate(other: Player)
	if other == player then
		return
	end
	local function attach(character: Model)
		remove(other)
		local head = character:WaitForChild("Head", 5)
		if not head then
			return
		end
		local classId = other:GetAttribute("Class")
		local color = if Classes.isClassId(classId) then Classes.INFO[classId :: Classes.ClassId].color else Theme.TEXT
		add(other, other.DisplayName, color, function()
			return (head :: BasePart).Position
		end, head)
	end
	other.CharacterAdded:Connect(attach)
	other.CharacterRemoving:Connect(function()
		remove(other)
	end)
	if other.Character then
		task.spawn(attach, other.Character)
	end
end

-- Shows a ping for a few seconds.
function Markers.ping(pinger: Player, position: Vector3, text: string)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local key = anchor
	local classId = pinger:GetAttribute("Class")
	local color = if Classes.isClassId(classId) then Classes.INFO[classId :: Classes.ClassId].color else Theme.ACCENT
	add(key, text, color, function()
		return position
	end, anchor, os.clock() + 8)
end

local function headingDegrees(): number
	local look = camera.CFrame.LookVector
	return math.deg(math.atan2(look.X, -look.Z))
end

local function compassOffset(direction: Vector3): number?
	local bearing = math.deg(math.atan2(direction.X, -direction.Z))
	local delta = (bearing - headingDegrees() + 540) % 360 - 180
	if math.abs(delta) > COMPASS_FOV / 2 then
		return nil
	end
	return 0.5 + delta / COMPASS_FOV
end

local function buildCompass()
	compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.AnchorPoint = Vector2.new(0.5, 0)
	compass.Position = UDim2.new(0.5, 0, 0, 24)
	compass.Size = UDim2.fromOffset(COMPASS_WIDTH, 34)
	compass.BackgroundColor3 = Theme.PANEL
	compass.BackgroundTransparency = 0.45
	compass.BorderSizePixel = 0
	compass.ClipsDescendants = true
	compass.Parent = Hud.gui()
	Theme.corner(compass)
	local centre = Instance.new("Frame")
	centre.AnchorPoint = Vector2.new(0.5, 0)
	centre.Position = UDim2.fromScale(0.5, 0)
	centre.Size = UDim2.fromOffset(2, 8)
	centre.BackgroundColor3 = Theme.ACCENT
	centre.BorderSizePixel = 0
	centre.Parent = compass
	local cardinals = {}
	for _, entry in { { "N", 0 }, { "E", 90 }, { "S", 180 }, { "W", 270 } } do
		local label = Theme.label(compass, {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(24, 18),
			Position = UDim2.fromOffset(0, 4),
			Font = Theme.FONT_BOLD,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = entry[1],
		})
		table.insert(cardinals, { label = label, bearing = entry[2] })
	end
	return cardinals
end

function Markers.start()
	local cardinals = buildCompass()
	CollectionService:GetInstanceAddedSignal("Marker"):Connect(trackTagged)
	CollectionService:GetInstanceRemovedSignal("Marker"):Connect(remove)
	for _, instance in CollectionService:GetTagged("Marker") do
		trackTagged(instance)
	end
	Players.PlayerAdded:Connect(trackTeammate)
	Players.PlayerRemoving:Connect(remove)
	for _, other in Players:GetPlayers() do
		trackTeammate(other)
	end

	RunService.RenderStepped:Connect(function()
		local heading = headingDegrees()
		for _, cardinal in cardinals do
			local delta = (cardinal.bearing - heading + 540) % 360 - 180
			cardinal.label.Visible = math.abs(delta) <= COMPASS_FOV / 2
			cardinal.label.Position = UDim2.new(0.5 + delta / COMPASS_FOV, 0, 0, 4)
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		for key, marker in markers do
			if marker.expires and now > marker.expires then
				if typeof(key) == "Instance" and key:IsA("Attachment") then
					key:Destroy()
				end
				remove(key)
				continue
			end
			local position = marker.target()
			if not position then
				continue
			end
			local offset = position - eye
			marker.distance.Text = string.format("%dm", math.floor(offset.Magnitude / 3.5))
			if marker.pip then
				local x = compassOffset(offset)
				marker.pip.Visible = x ~= nil
				if x then
					marker.pip.Position = UDim2.fromScale(x, 0.75)
				end
			end
		end
	end)
end

return Markers
