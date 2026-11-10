--!strict
-- Named remotes shared by server and client.
-- The server creates each remote on first use; clients wait for it to replicate.
-- Every remote name used anywhere in the game is listed here so the protocol is visible in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

export type Kind = "Event" | "Unreliable" | "Function"

local REMOTES: { [string]: Kind } = {}

local CLASS_FOR_KIND: { [Kind]: string } = {
	Event = "RemoteEvent",
	Unreliable = "UnreliableRemoteEvent",
	Function = "RemoteFunction",
}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string): Instance
	local kind = REMOTES[name]
	assert(kind, `Unknown remote "{name}"`)
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(CLASS_FOR_KIND[kind])
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	assert(REMOTES[name] == "Event", `"{name}" is not a RemoteEvent`)
	return get(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	assert(REMOTES[name] == "Unreliable", `"{name}" is not an UnreliableRemoteEvent`)
	return get(name) :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(REMOTES[name] == "Function", `"{name}" is not a RemoteFunction`)
	return get(name) :: RemoteFunction
end

-- Creates every remote up front so clients never wait on one the server has not touched yet.
function Net.createAll()
	assert(RunService:IsServer(), "Net.createAll runs on the server")
	for name in REMOTES do
		get(name)
	end
end

return Net
