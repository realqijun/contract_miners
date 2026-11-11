--!strict
-- Loads the game's own Roblox-style ModuleScripts from `src/` inside Lune, so the simulation runs
-- on exactly the tuning data and math the game ships with. Nothing here copies a game number.
--
-- How it works:
--   * Every module is read from disk, compiled with `@lune/luau` and run in an environment whose
--     `script` is a fake Instance: indexing it walks the real folders (`script.Parent.Config.Tools`
--     resolves to `src/shared/Config/Tools.luau`), and `require` on such a node loads that file.
--   * `game:GetService(name)` follows the Rojo project file, so `ReplicatedStorage.Shared` maps to
--     `src/shared` just like in Studio.
--   * Roblox datatypes (Vector3, Color3, NumberSequence, Enum, ...) come from `@lune/roblox`.
--     `Random` is not part of it, so a seeded stand-in with the same methods is supplied. Its stream
--     differs from Roblox's, so a seed gives a different (but equally valid) cave than in Studio.
--   * `Loader.literal` reads a numeric literal out of a server script for the few tuning values
--     the server keeps as local constants, and fails loudly if the source no longer matches.
--
-- Run from the repository root: paths are resolved against the working directory, and the whole
-- `src/` tree is read once on first use.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Rng = require("./Rng")

local Loader = {}

local PROJECT_FILE = "mission.project.json"

-- Datatypes the game's modules may use at load time.
local DATATYPES = {
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector3",
}

-- Roblox's Random, as far as the shared modules use it.
local RandomShim = {}
RandomShim.__index = RandomShim

function RandomShim.new(seed: number?)
	return setmetatable({ rng = Rng.new((seed or os.clock() * 1e6) * 7919 + 17) }, RandomShim)
end

function RandomShim:NextNumber(low: number?, high: number?): number
	return self.rng:range(low or 0, high or 1)
end

function RandomShim:NextInteger(low: number, high: number): number
	return self.rng:int(low, high)
end

type Node = { Name: string, Parent: Node?, __path: string?, __children: { [string]: Node }? }

local cache: { [string]: any } = {}
local nodeMeta = {}

-- File reads yield in Lune, and yielding inside a metamethod is not allowed, so the source tree is
-- read once up front: every directory, and every module's source text.
local sources: { [string]: string } = {}
local directories: { [string]: boolean } = {}

local function scan(path: string)
	directories[path] = true
	for _, name in fs.readDir(path) do
		local child = `{path}/{name}`
		if fs.isDir(child) then
			scan(child)
		elseif string.match(name, "%.luau?$") then
			sources[child] = fs.readFile(child)
		end
	end
end

local function moduleFile(path: string): string?
	for _, candidate in { path .. ".luau", path .. ".lua", path .. "/init.luau", path .. "/init.lua" } do
		if sources[candidate] then
			return candidate
		end
	end
	return nil
end

local function makeNode(name: string, parent: Node?, path: string?, children: { [string]: Node }?): Node
	return setmetatable({ Name = name, Parent = parent, __path = path, __children = children }, nodeMeta) :: any
end

-- Indexing a node finds a child module or folder on disk (or a virtual child from the project file).
nodeMeta.__index = function(node: Node, key: string): any
	local children = rawget(node :: any, "__children")
	if children and children[key] then
		return children[key]
	end
	local path = rawget(node :: any, "__path")
	if type(path) == "string" then
		local childPath = `{path}/{key}`
		if moduleFile(childPath) or directories[childPath] then
			local child = makeNode(key, node, childPath, nil)
			rawset(node :: any, key, child)
			return child
		end
	end
	error(`Loader: "{key}" is not a valid member of {path or node.Name}`, 2)
end

nodeMeta.__tostring = function(node: Node): string
	return `Node({rawget(node :: any, "__path") or node.Name})`
end

local load: (path: string, node: Node) -> any
local projectSource = ""

local function requireNode(target: any): any
	if type(target) == "table" and getmetatable(target) == nodeMeta then
		local path = rawget(target, "__path")
		local file = type(path) == "string" and moduleFile(path)
		if not file then
			error(`Loader: {tostring(target)} is not a module`, 2)
		end
		return load(file, target)
	end
	error(`Loader: cannot require {tostring(target)}`, 2)
end

-- The Rojo tree as nodes, so game:GetService("ReplicatedStorage").Shared works.
local function projectNode(name: string, tree: { [string]: any }, parent: Node?): Node
	local children = {}
	local node = makeNode(name, parent, tree["$path"], children)
	for key, value in tree do
		if type(value) == "table" and string.sub(key, 1, 1) ~= "$" then
			children[key] = projectNode(key, value, node)
		end
	end
	return node
end

local game: Node? = nil
local function fakeGame(): any
	if not game then
		local project = serde.decode("json", projectSource)
		local root = projectNode("game", project.tree, nil) :: any
		root.GetService = function(self, service: string)
			return self[service]
		end
		game = root
	end
	return game
end

load = function(file: string, node: Node): any
	local cached = cache[file]
	if cached ~= nil then
		return cached
	end
	local environment: { [string]: any } = {
		script = node,
		require = requireNode,
		game = fakeGame(),
		Random = RandomShim,
	}
	for _, name in DATATYPES do
		environment[name] = (roblox :: any)[name]
	end
	local chunk = luau.load(sources[file], { debugName = file, environment = environment })
	local result = chunk()
	cache[file] = result
	return result
end

-- Requires a module by its path under the repository, for example "src/shared/Config/Weapons".
function Loader.require(path: string): any
	if not directories.src then
		assert(fs.isDir("src/shared"), "Run the simulation from the repository root")
		scan("src")
		projectSource = fs.readFile(PROJECT_FILE)
	end
	local segments = string.split(path, "/")
	local node = makeNode(segments[1], nil, segments[1], nil)
	for index = 2, #segments do
		node = (node :: any)[segments[index]]
	end
	return requireNode(node)
end

-- Reads the first number captured by `pattern` in a source file. Used for server-local constants
-- that are not in a config module; errors if the code changed so the simulation never goes stale.
function Loader.literal(file: string, pattern: string): number
	local source = fs.readFile(file)
	local captured = string.match(source, pattern)
	local value = captured and tonumber(captured)
	if not value then
		error(`Loader: pattern {pattern} not found in {file}; update the simulation to match the game`)
	end
	return value :: number
end

return Loader
