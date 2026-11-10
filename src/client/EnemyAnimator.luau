--!strict
-- Procedural animation for every Vrill: legs stride with ground speed, wings flap constantly.
-- Purely local and visual; it only writes Motor6D.Transform, which never replicates.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EnemyAnimator = {}

type Rig = {
	root: BasePart,
	legs: { { joint: Motor6D, phase: number } },
	wings: { { joint: Motor6D, phase: number } },
	cycle: number,
}

local rigs: { [Model]: Rig } = {}

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local rig: Rig = { root = root, legs = {}, wings = {}, cycle = math.random() * 10 }
	for _, joint in root:GetChildren() do
		if joint:IsA("Motor6D") then
			local entry = { joint = joint, phase = (joint:GetAttribute("Phase") :: number?) or 0 }
			if joint.Name == "WingJoint" then
				table.insert(rig.wings, entry)
			else
				table.insert(rig.legs, entry)
			end
		end
	end
	rigs[model] = rig
end

local function untrack(model: Instance)
	rigs[model :: Model] = nil
end

function EnemyAnimator.start()
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(untrack)
	for _, model in CollectionService:GetTagged("Enemy") do
		track(model)
	end
	RunService.RenderStepped:Connect(function(dt)
		for model, rig in rigs do
			if not model.Parent then
				continue
			end
			local velocity = rig.root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local frozen = model:GetAttribute("Frozen") == true
			if not frozen then
				rig.cycle += dt * (4 + speed * 0.9)
			end
			local stride = math.clamp(speed / 12, 0.15, 1) * math.rad(32)
			for _, leg in rig.legs do
				leg.joint.Transform = CFrame.Angles(
					math.sin(rig.cycle + leg.phase) * stride,
					0,
					math.max(0, math.cos(rig.cycle + leg.phase)) * math.rad(10)
				)
			end
			for _, wing in rig.wings do
				local flap = if frozen then 0 else math.sin(os.clock() * 42 + wing.phase) * math.rad(35)
				wing.joint.Transform = CFrame.Angles(0, 0, flap)
			end
		end
	end)
end

return EnemyAnimator
