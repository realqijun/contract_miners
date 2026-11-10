--!strict
-- The guided walkthrough: its steps in order and what each one tells the player.
-- Text placeholders in braces are filled in by the client with the player's own bindings:
-- an Input action name such as {Pickaxe}, or {Move}, {Look} and {Jump}.

local Walkthrough = {}

export type Step =
	"Move"
	| "Camera"
	| "Mine"
	| "Deposit"
	| "Tunnel"
	| "Climb"
	| "Ferrin"
	| "CallResupply"
	| "Restock"
	| "Grenade"
	| "Swarm"
	| "Revive"
	| "LiftPod"

Walkthrough.STEPS = {
	"Move",
	"Camera",
	"Mine",
	"Deposit",
	"Tunnel",
	"Climb",
	"Ferrin",
	"CallResupply",
	"Restock",
	"Grenade",
	"Swarm",
	"Revive",
	"LiftPod",
} :: { Step }

Walkthrough.TEXT = {
	Move = "Look around with {Look} and move with {Move}. Hold {Sprint} to sprint and press {Jump} to jump. Walk to the marker.",
	Camera = "Press {CameraToggle} to switch between first and third person. Press it again whenever you like.",
	Mine = "Take out your pickaxe with {Pickaxe} and hit the glowing purple Volticite veins with {Fire} until you carry 24.",
	Deposit = "Bring the Volticite to the Dropcan and hold {Interact} to deposit it.",
	Tunnel = "Follow the tunnel to the next cavern and find the marker.",
	Climb = "",
	Ferrin = "Mine the red Ferrin crystals. The crew shares Ferrin, and 80 of it buys a resupply pod.",
	CallResupply = "Aim at the floor and hold {Ping} to call a resupply pod there.",
	Restock = "Stand by the pod and hold {Interact} to restock your ammo and health.",
	Grenade = "Vrill incoming! Throw a grenade into them with {Grenade}.",
	Swarm = "Finish off the swarm. Fire with {Fire}, reload with {Reload}, and switch weapons with {Primary}.",
	Revive = "Going down: a downed miner bleeds out after 40 seconds unless a crewmate holds {Interact} by them for 3 seconds. Carry a fallen miner's dog tag to a resupply pod to bring them back. When the whole crew is down, the mission fails.",
	LiftPod = "The Lift Pod is coming down. Follow its marker and get aboard before it launches.",
} :: { [Step]: string }

-- The ledge climb depends on the class's traversal tool.
Walkthrough.CLIMB_TEXT = {
	Scout = "Climb to the ledge above. Take out the Grapple Line with {Traversal}, aim at the ledge and fire with {Fire}.",
	Mechanic = "Climb to the ledge above. Take out the Foam Projector with {Traversal} and fire foam pads up the wall with {Fire} to make steps.",
	HeavyWeapons = "Climb to the ledge above. Take out the Cable Launcher with {Traversal}, fire a cable up to the ledge with {Fire}, then stand under it and press {Interact} to ride.",
	Demolition = "Climb to the ledge above. Take out the Plasma Cutter with {Traversal} and melt a ramp up into the rock with {Fire}.",
} :: { [string]: string }

-- Volticite the walkthrough asks for, two veins' worth.
Walkthrough.VOLTICITE_TARGET = 24
-- Seconds the revive explanation stays up before the Lift Pod is called.
Walkthrough.REVIVE_SECONDS = 14
-- Seconds a downed player stays down in the walkthrough before getting back up on their own.
Walkthrough.SELF_REVIVE_SECONDS = 5
-- Vrill in the practice swarm.
Walkthrough.SWARM = { Drone = 5 }

return Walkthrough
