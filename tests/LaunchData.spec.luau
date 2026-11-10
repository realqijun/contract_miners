--!strict
local LaunchData = require(game:GetService("ReplicatedStorage").Shared.LaunchData)

local function valid(): { [string]: any }
	return {
		missionType = "Refinery",
		seed = 4242,
		partySize = 2,
		classes = { ["101"] = "Scout", ["202"] = "Demolition" },
	}
end

return function(t)
	t.describe("validate", function()
		t.it("accepts well-formed launch data", function()
			local launch = LaunchData.validate(valid())
			t.expect(launch).toBeTruthy()
			t.expect((launch :: LaunchData.LaunchData).classes["202"]).toBe("Demolition")
			t.expect((launch :: LaunchData.LaunchData).walkthrough).toBe(false)
		end)

		t.it("rejects non-tables", function()
			t.expect(LaunchData.validate(nil)).toBe(nil)
			t.expect(LaunchData.validate("Mining")).toBe(nil)
		end)

		t.it("rejects unknown mission types and classes", function()
			local data = valid()
			data.missionType = "Salvage"
			t.expect(LaunchData.validate(data)).toBe(nil)
			data = valid()
			data.classes["101"] = "Wizard"
			t.expect(LaunchData.validate(data)).toBe(nil)
		end)

		t.it("rejects out-of-range seeds and party sizes", function()
			for _, seed in { 0, -5, 1.5, LaunchData.MAX_SEED + 1 } do
				local data = valid()
				data.seed = seed
				t.expect(LaunchData.validate(data)).toBe(nil)
			end
			for _, size in { 0, 5, 2.5 } do
				local data = valid()
				data.partySize = size
				t.expect(LaunchData.validate(data)).toBe(nil)
			end
		end)

		t.it("rejects empty or oversized crews", function()
			local data = valid()
			data.classes = {}
			t.expect(LaunchData.validate(data)).toBe(nil)
			data.classes = { ["1"] = "Scout", ["2"] = "Scout", ["3"] = "Scout", ["4"] = "Scout", ["5"] = "Scout" }
			t.expect(LaunchData.validate(data)).toBe(nil)
		end)
	end)
end
