--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Kits = require(Shared.Config.Kits)
local Stats = require(Shared.Stats)
local ToolsConfig = require(Shared.Config.Tools)
local Upgrades = require(Shared.Config.Upgrades)
local Weapons = require(Shared.Config.Weapons)

local function baseStats(itemId: string): { [string]: any }
	return (Weapons.STATS :: any)[itemId] or ToolsConfig.TOOLS[itemId] or ToolsConfig.GRENADES[itemId]
end

return function(t)
	t.describe("catalogue", function()
		t.it("covers every kit item with 3 tiers of 2 choices", function()
			local count = 0
			for _, kit in Kits.BY_CLASS do
				for _, itemId in { kit.primary, kit.secondary, kit.traversal, kit.support, kit.grenade } do
					local item = Upgrades.ITEMS[itemId]
					t.expect(item ~= nil).toBeTruthy()
					t.expect(#item).toBe(3)
					for tier = 1, 3 do
						t.expect(item[tier].A ~= nil and item[tier].B ~= nil).toBeTruthy()
						count += 2
					end
				end
			end
			t.expect(count).toBe(120)
		end)

		t.it("only changes stats the item actually has", function()
			for itemId, item in Upgrades.ITEMS do
				local base = baseStats(itemId)
				t.expect(base ~= nil).toBeTruthy()
				for _, tier in item do
					for _, upgrade in { tier.A, tier.B } do
						for _, change in upgrade.changes do
							local known = base[change.stat] ~= nil
								-- Optional stats an upgrade may introduce.
								or change.stat == "burnPerSecond"
							if not known then
								error(`{itemId} upgrade "{upgrade.name}" changes unknown stat "{change.stat}"`)
							end
						end
					end
				end
			end
		end)
	end)

	t.describe("ids", function()
		t.it("round-trips through parse", function()
			local itemId, tier, choice = Upgrades.parse(Upgrades.id("RotaryCannon", 2, "B"))
			t.expect(itemId).toBe("RotaryCannon")
			t.expect(tier).toBe(2)
			t.expect(choice).toBe("B")
		end)

		t.it("rejects malformed ids", function()
			for _, bad in { "RotaryCannon.4A", "Nope.1A", "RotaryCannon.1C", "RotaryCannon", "" } do
				t.expect(Upgrades.parse(bad)).toBe(nil)
			end
		end)
	end)

	t.describe("Stats", function()
		t.it("applies only the upgrades for the item", function()
			local stats = Stats.weapon("RivetDriver", { "RivetDriver.1A", "BurstCarbine.1A", "RivetDriver.1B" })
			t.expect(stats.damage).toBeCloseTo(Weapons.STATS.RivetDriver.damage * 1.15)
			t.expect(stats.magazine).toBe(Weapons.STATS.RivetDriver.magazine + 15)
		end)

		t.it("never mutates the base config", function()
			Stats.weapon("HandCannon", { "HandCannon.3A" })
			t.expect(Weapons.STATS.HandCannon.piercesArmor).toBe(false)
			Stats.tool("FoamProjector", { "FoamProjector.1A" })
			t.expect(ToolsConfig.TOOLS.FoamProjector.charges).toBe(30)
		end)
	end)
end
