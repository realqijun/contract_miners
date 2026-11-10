--!strict
-- Minerals and crystals found in the cave.

export type Kind = "Volticite" | "Ferrin" | "Health"

local Resources = {}

-- Volticite per vein, and per pickaxe hit on a vein.
Resources.VOLTICITE_PER_VEIN = 12
Resources.VOLTICITE_PER_HIT = 3

-- Ferrin per node, and per hit. Every RESUPPLY_COST Ferrin in the team pool buys one resupply pod.
Resources.FERRIN_PER_NODE = 20
Resources.FERRIN_PER_HIT = 10
Resources.FERRIN_NODES_PER_CAVERN = { 2, 4 }
Resources.RESUPPLY_COST = 80

-- A health crystal breaks in one hit and heals the miner.
Resources.HEALTH_PER_CRYSTAL = 30
Resources.HEALTH_CRYSTALS_PER_CAVERN = { 1, 2 }

Resources.COLORS = {
	Volticite = Color3.fromRGB(176, 96, 255),
	Ferrin = Color3.fromRGB(206, 82, 44),
	Health = Color3.fromRGB(255, 52, 72),
} :: { [Kind]: Color3 }

Resources.DISPLAY_NAME = {
	Volticite = "Volticite",
	Ferrin = "Ferrin",
	Health = "Health crystal",
} :: { [Kind]: string }

return Resources
