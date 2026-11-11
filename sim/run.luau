--!strict
-- Contract Miners balance simulation. Run from the repository root:
--   lune run sim/run.luau -- [sections...] [--quick] [--out <folder>]
-- Sections: ttk, swarms, missions, progression, dominance, power (default: all of them).
-- Each section prints Markdown and is also saved to <folder>/<section>.md (default sim/out).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Report = require("./src/Report")

local SECTIONS = { "ttk", "swarms", "missions", "dominance", "power", "progression" }
local BUILDERS = {
	ttk = Report.ttk,
	swarms = Report.swarms,
	missions = Report.missions,
	progression = Report.progression,
	dominance = Report.dominance,
	power = Report.power,
}

local settings = { quick = false }
local chosen = {}
local out = "sim/out"
local args = process.args
local index = 1
while index <= #args do
	local arg = args[index]
	if arg == "--quick" then
		settings.quick = true
	elseif arg == "--out" then
		index += 1
		out = assert(args[index], "--out needs a folder")
	elseif BUILDERS[arg] then
		table.insert(chosen, arg)
	elseif arg ~= "--" then
		error(`Unknown argument "{arg}". Sections: {table.concat(SECTIONS, ", ")}; flags: --quick, --out <folder>`)
	end
	index += 1
end
if #chosen == 0 then
	chosen = SECTIONS
end

if not fs.isDir(out) then
	fs.writeDir(out)
end
for _, section in chosen do
	local started = os.clock()
	local text = BUILDERS[section](settings)
	local footer =
		string.format("\n\n_%s: %.0f s%s_\n", section, os.clock() - started, if settings.quick then ", quick" else "")
	print(text .. footer)
	fs.writeFile(`{out}/{section}.md`, text .. footer)
end
