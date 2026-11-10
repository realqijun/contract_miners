--!strict
-- Smooth movement for big anchored models: drop pods, the Lift Pod, the Refinery and its rocket.
-- Moving an anchored model on the server only reaches clients at network rate, so it stutters.
-- Instead the server records where the model goes, when and how (as attributes and a tag), holds
-- it at the start, and snaps it to the end when the time is up; every client animates it smoothly
-- in between.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Glide = {}

local TAG = "Gliding"

-- Server: glides `model` from where it is to `to` over `duration` seconds, then calls `onDone`.
function Glide.move(
	model: Model,
	to: CFrame,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	onDone: (() -> ())?
)
	assert(RunService:IsServer(), "Only the server starts glides")
	model:SetAttribute("GlideFrom", model:GetPivot())
	model:SetAttribute("GlideTo", to)
	model:SetAttribute("GlideStart", Workspace:GetServerTimeNow())
	model:SetAttribute("GlideDuration", duration)
	model:SetAttribute("GlideStyle", style.Name)
	model:SetAttribute("GlideDirection", direction.Name)
	CollectionService:AddTag(model, TAG)
	task.delay(duration, function()
		if model.Parent then
			model:PivotTo(to)
			CollectionService:RemoveTag(model, TAG)
		end
		if onDone then
			onDone()
		end
	end)
end

local function animate(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local from, to = model:GetAttribute("GlideFrom"), model:GetAttribute("GlideTo")
		local start, duration = model:GetAttribute("GlideStart"), model:GetAttribute("GlideDuration")
		if not (model.Parent and CollectionService:HasTag(model, TAG)) then
			connection:Disconnect()
			return
		end
		if
			not (
				typeof(from) == "CFrame"
				and typeof(to) == "CFrame"
				and type(start) == "number"
				and type(duration) == "number"
			)
		then
			return
		end
		local alpha = math.clamp((Workspace:GetServerTimeNow() - start) / duration, 0, 1)
		local style = (Enum.EasingStyle :: any)[model:GetAttribute("GlideStyle")] or Enum.EasingStyle.Linear
		local direction = (Enum.EasingDirection :: any)[model:GetAttribute("GlideDirection")] or Enum.EasingDirection.In
		model:PivotTo(from:Lerp(to, TweenService:GetValue(alpha, style, direction)))
	end)
end

-- Client: animates every gliding model, now and as they appear.
function Glide.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(animate)
	for _, model in CollectionService:GetTagged(TAG) do
		animate(model)
	end
end

return Glide
