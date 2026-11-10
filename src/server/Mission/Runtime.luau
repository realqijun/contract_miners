--!strict
-- The running mission's world: launch settings, cave layout and the Dropcan.
-- Set once by the Mission place entry point; read by every mission system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Cave.Layout)
local LaunchData = require(ReplicatedStorage.Shared.LaunchData)
local Dropcan = require(script.Parent.Parent.Models.Dropcan)

export type World = {
	launch: LaunchData.LaunchData,
	layout: Layout.CaveLayout,
	dropcan: Dropcan.Dropcan,
	-- Floor point the Dropcan stands on.
	landing: Vector3,
}

local Runtime = {}

local world: World? = nil

function Runtime.init(value: World)
	assert(world == nil, "Mission runtime is already initialised")
	world = value
end

function Runtime.get(): World
	assert(world, "Mission runtime is not initialised yet")
	return world
end

return Runtime
