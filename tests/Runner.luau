--!strict
-- Minimal test runner. Run it on the server of a Studio playtest, where every module is freshly required:
--   return require(game.ServerStorage.Tests.Runner).run()
-- Every ModuleScript named "*.spec" under Tests is a suite. A suite returns function(t: Runner.T).

local Runner = {}

type Case = { name: string, body: () -> () }

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeCloseTo: (expected: number, tolerance: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeGreaterThan: (bound: number) -> (),
	toBeLessThan: (bound: number) -> (),
	toBeBetween: (low: number, high: number) -> (),
}

export type T = {
	describe: (name: string, body: () -> ()) -> (),
	it: (name: string, body: () -> ()) -> (),
	expect: (actual: any) -> Expectation,
}

local function deepEqual(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function fail(message: string)
	error(message, 3)
end

local function expect(actual: any): Expectation
	return {
		toBe = function(expected)
			if actual ~= expected then
				fail(`expected {expected}, got {actual}`)
			end
		end,
		toEqual = function(expected)
			if not deepEqual(actual, expected) then
				fail("values are not deeply equal")
			end
		end,
		toBeCloseTo = function(expected, tolerance)
			if math.abs(actual - expected) > (tolerance or 1e-6) then
				fail(`expected {actual} to be within {tolerance or 1e-6} of {expected}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected a truthy value, got {actual}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected a falsy value, got {actual}`)
			end
		end,
		toBeGreaterThan = function(bound)
			if not (actual > bound) then
				fail(`expected {actual} > {bound}`)
			end
		end,
		toBeLessThan = function(bound)
			if not (actual < bound) then
				fail(`expected {actual} < {bound}`)
			end
		end,
		toBeBetween = function(low, high)
			if not (actual >= low and actual <= high) then
				fail(`expected {actual} to be in [{low}, {high}]`)
			end
		end,
	}
end

local function collect(suite: ModuleScript): { Case }
	local cases: { Case } = {}
	local prefix: { string } = { (suite.Name:gsub("%.spec$", "")) }
	local t: T = {
		describe = function(name, body)
			table.insert(prefix, name)
			body()
			table.remove(prefix)
		end,
		it = function(name, body)
			table.insert(cases, { name = table.concat(prefix, " > ") .. " > " .. name, body = body })
		end,
		expect = expect,
	}
	local define = (require :: any)(suite)
	define(t)
	return cases
end

-- Runs every suite, or only suites whose name contains `filter`. Returns a printable report.
function Runner.run(filter: string?): string
	local lines = {}
	local passed, failed = 0, 0
	local started = os.clock()
	for _, instance in script.Parent:GetDescendants() do
		if instance:IsA("ModuleScript") and instance.Name:match("%.spec$") then
			if filter == nil or instance.Name:find(filter, 1, true) then
				local ok, cases = pcall(collect, instance)
				if not ok then
					failed += 1
					table.insert(lines, `FAIL {instance:GetFullName()} failed to load: {cases}`)
					continue
				end
				for _, case in cases :: { Case } do
					local caseOk, err = pcall(case.body)
					if caseOk then
						passed += 1
					else
						failed += 1
						table.insert(lines, `FAIL {case.name}: {err}`)
					end
				end
			end
		end
	end
	table.insert(lines, string.format("%d passed, %d failed in %.2fs", passed, failed, os.clock() - started))
	return table.concat(lines, "\n")
end

return Runner
