--!strict
local MotionRules = require(game:GetService("ServerScriptService").Server.Character.MotionRules)
local PlayerConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Player)

local SPRINT = PlayerConfig.SPRINT_SPEED

return function(t)
	t.describe("fall", function()
		t.it("does nothing for drops up to the threshold", function()
			local track = MotionRules.new(Vector3.zero, 0)
			t.expect(MotionRules.fall(track, 40, false, false)).toBe(0)
			t.expect(MotionRules.fall(track, 15, true, false)).toBe(0)
		end)

		t.it("hurts per stud beyond the threshold, measured from the peak", function()
			local track = MotionRules.new(Vector3.zero, 0)
			MotionRules.fall(track, 10, false, false)
			MotionRules.fall(track, 50, false, false)
			MotionRules.fall(track, 30, false, false)
			local damage = MotionRules.fall(track, 15, true, false)
			t.expect(damage)
				.toBeCloseTo((50 - 15 - PlayerConfig.FALL_DAMAGE_HEIGHT) * PlayerConfig.FALL_DAMAGE_PER_STUD)
		end)

		t.it("only counts each fall once", function()
			local track = MotionRules.new(Vector3.zero, 0)
			MotionRules.fall(track, 60, false, false)
			t.expect(MotionRules.fall(track, 0, true, false)).toBeGreaterThan(0)
			t.expect(MotionRules.fall(track, 0, true, false)).toBe(0)
		end)

		t.it("restarts the fall when a grapple or cable lets go", function()
			local track = MotionRules.new(Vector3.zero, 0)
			MotionRules.fall(track, 80, false, false)
			MotionRules.fall(track, 70, false, true)
			MotionRules.fall(track, 60, false, false)
			t.expect(MotionRules.fall(track, 40, true, false)).toBe(0)
		end)
	end)

	t.describe("checkSpeed", function()
		t.it("accepts sprinting", function()
			local track = MotionRules.new(Vector3.zero, 0)
			for step = 1, 8 do
				local ok =
					MotionRules.checkSpeed(track, Vector3.new(SPRINT * step * 0.25, 0, 0), step * 0.25, SPRINT, false)
				t.expect(ok).toBe(true)
			end
		end)

		t.it("ignores vertical travel", function()
			local track = MotionRules.new(Vector3.zero, 0)
			t.expect(MotionRules.checkSpeed(track, Vector3.new(0, -200, 0), 0.25, SPRINT, false)).toBe(true)
		end)

		t.it("rejects a teleport and keeps the last good position", function()
			local track = MotionRules.new(Vector3.zero, 0)
			MotionRules.checkSpeed(track, Vector3.new(5, 0, 0), 0.25, SPRINT, false)
			t.expect(MotionRules.checkSpeed(track, Vector3.new(80, 0, 0), 0.5, SPRINT, false)).toBe(false)
			t.expect(track.anchor).toEqual(Vector3.new(5, 0, 0))
		end)

		t.it("rejects sustained running well above sprint speed", function()
			local track = MotionRules.new(Vector3.zero, 0)
			local failed = false
			local x = 0
			for step = 1, 20 do
				x += SPRINT * 2 * 0.25
				if not MotionRules.checkSpeed(track, Vector3.new(x, 0, 0), step * 0.25, SPRINT, false) then
					failed = true
				end
			end
			t.expect(failed).toBe(true)
		end)

		t.it("lets a burst of late positions through after a lag spike", function()
			local track = MotionRules.new(Vector3.zero, 0)
			-- Frozen for two seconds, then two seconds of sprinting arrives at once.
			for step = 1, 8 do
				MotionRules.checkSpeed(track, Vector3.zero, step * 0.25, SPRINT, false)
			end
			t.expect(MotionRules.checkSpeed(track, Vector3.new(SPRINT * 2, 0, 0), 2.25, SPRINT, false)).toBe(true)
		end)

		t.it("caps the budget banked by standing still", function()
			local track = MotionRules.new(Vector3.zero, 0)
			t.expect(MotionRules.checkSpeed(track, Vector3.new(SPRINT * 10, 0, 0), 30, SPRINT, false)).toBe(false)
		end)

		t.it("spends the bank on one burst, so repeated blinks fail", function()
			local track = MotionRules.new(Vector3.zero, 0)
			local blink = MotionRules.budgetCap(SPRINT) - 2
			t.expect(MotionRules.checkSpeed(track, Vector3.new(blink, 0, 0), 0.25, SPRINT, false)).toBe(true)
			t.expect(MotionRules.checkSpeed(track, Vector3.new(blink * 2, 0, 0), 0.5, SPRINT, false)).toBe(false)
		end)

		t.it("lets traversal tools move any distance", function()
			local track = MotionRules.new(Vector3.zero, 0)
			t.expect(MotionRules.checkSpeed(track, Vector3.new(60, 0, 0), 0.25, SPRINT, true)).toBe(true)
			t.expect(track.anchor).toEqual(Vector3.new(60, 0, 0))
		end)
	end)
end
