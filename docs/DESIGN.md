# Contract Miners - Design

This document is the single source of truth for building Contract Miners.
Every decision here was settled with the project owner on 2026-11-10.
The build and the tuning audit work from this document.
Change it deliberately, not implicitly.

## 1. Scope and principles

Contract Miners is an original Roblox co-op mining horde shooter for 1 to 4 players.
It ships as a minimal, polished, publishable game covering exactly the scope below.
There is no prototype, MVP or staged v1, and nothing outside this scope gets added.
The game is original in name, fiction, characters, kits, creatures and look.
It shares only genre-level mechanics with other games in its genre.

Target platforms are PC with keyboard and mouse, and gamepad.
Mobile touch controls are out of scope.
There is no monetisation of any kind: no Robux purchases, no premium currency and no cosmetics shop.
The game is English only.

## 2. Fiction and names

Players are contract miners working the hive-riddled caves of the planet Kessra.
There is no named mining company.

| Concept | Name |
| --- | --- |
| Game title | Contract Miners |
| Planet | Kessra |
| Enemy hive | The Vrill |
| Primary mineral | Volticite (glowing violet crystal) |
| Liquid primary mineral | Volticite slurry |
| Resupply mineral | Ferrin (red nodes) |
| Arrival pod | Dropcan |
| Extraction pod | Lift Pod |
| Refinery structure | Refinery |
| Classes | Mechanic, Scout, Heavy Weapons, Demolition |

## 3. Characters and presentation

Players keep their own Roblox avatars.
Each class adds part-built gear over the avatar: a class-coloured suit, a helmet with a headlamp, and a backpack.
Gear, weapons, enemies, pods and the Refinery are stylised low-poly models built from Parts and simple MeshParts with Roblox built-in materials.
The art direction is creative and bold rather than conservative.
No art is produced outside Roblox.

The camera defaults to first-person.
Players can toggle to an over-the-shoulder third-person camera at any time with V on keyboard or right-stick click on gamepad.
The crosshair stays visible in both modes, and shooting and mining aim along the camera ray in both modes.

## 4. Universal kit and controls

Every class carries:

- A pickaxe that mines Volticite, Ferrin and health crystals, digs small chunks of terrain, and works as a melee attack.
- A pickaxe heavy swing on a 20 second cooldown.
- An always-on headlamp.
- Throwable flares, 4 held, recharging 1 every 15 seconds.
- A ping that marks a spot, enemy or mineral for the team with a world marker.
- Sprint, jump and crouch.

Keyboard bindings:

| Input | Action |
| --- | --- |
| 1 / 2 | Primary / secondary weapon |
| 3 / 4 | Traversal tool / support tool |
| G | Grenade |
| F | Flare |
| Q | Pickaxe |
| E | Interact, revive, deposit, repair |
| Middle mouse | Ping |
| V | Camera toggle |
| Tab | Team status |

Gamepad gets an equivalent layout.
Controls are built on named input actions.
There is no keybind remapping.

## 5. Classes

Every class has a primary weapon, a secondary weapon, a traversal tool, a support tool and a grenade.
Duplicate classes are allowed in a party.
Classes cannot be switched during a mission.

### 5.1 Mechanic (builder and support)

- **Primary - Rivet Driver:** a fast-firing nail gun whose hits stack a brief slow on small enemies.
- **Secondary - Arc Mortar:** a single-shot lobbed explosive with splash damage and a slow reload.
- **Traversal - Foam Projector:** fires globs of hardfoam that stick to any surface and set into walkable 4x4 pads, chainable into stairs and bridges, 30 charges.
- **Support - Arc Pylons:** place two pylons up to 15 studs apart to form an electric fence that damages enemies passing through, lasting 45 seconds, 2 charges.
- **Grenade - Decoy Beacon:** a noisy beacon that pulls enemy aggro for 8 seconds and then explodes.

### 5.2 Scout (mobility and recon)

- **Primary - Burst Carbine:** accurate 3-round bursts with bonus weakspot damage.
- **Secondary - Bolt Pistol:** slow, heavy single shots that penetrate Bulwark armour.
- **Traversal - Grapple Line:** fires a hook up to 30 studs and reels the player in, on a 4 second cooldown.
- **Support - Lumen Dart Launcher:** sticky darts that light a large radius for 60 seconds and briefly highlight minerals within 20 studs, 8 held, regenerating 1 every 12 seconds.
- **Grenade - Cryo Bomb:** freezes enemies in a radius for 4 seconds, and frozen enemies take bonus damage.

### 5.3 Heavy Weapons (anchor)

- **Primary - Rotary Cannon:** spins up before sustained fire, builds heat instead of reloading, and locks out briefly on overheat.
- **Secondary - Hand Cannon:** a 6-shot revolver with high damage, slow fire and strong kick.
- **Traversal - Cable Launcher:** anchors a cable from the player to a point up to 50 studs away at any angle under 45 degrees, rideable by anyone in either direction, 4 charges.
- **Support - Aegis Dome:** a deployable 10-stud dome that blocks enemy projectiles and halves melee damage to allies inside, lasting 15 seconds, 2 charges.
- **Grenade - Cluster Bomb:** a large explosion that scatters smaller bomblets.

### 5.4 Demolition (tunneler)

- **Primary - Flame Projector:** a short-range cone of fire that ignites enemies and leaves briefly burning ground.
- **Secondary - Auto Pistol:** a fast-firing sidearm with large magazines.
- **Traversal - Plasma Cutter:** a held beam that melts terrain very fast in any direction including straight up, building heat and venting on overheat, with unlimited use.
- **Support - Satchel Charge:** thrown, sticks to surfaces, detonated by pressing again, removes a large sphere of terrain and damages enemies and teammates, 3 charges.
- **Grenade - Seismic Grenade:** an explosion that carves a crater in terrain and briefly stuns enemies.

## 6. Vitals and damage

- Players have 100 health and a 30-point shield.
- The shield regenerates after 5 seconds without taking damage.
- Health is restored only by red health crystals and resupply pods.
- Falls higher than 25 studs deal fall damage, 3.2 per stud beyond that, measured by the server from the top of the fall.
- A grapple pull or a cable ride restarts the fall from where it lets go.
- Friendly fire is off, except for Satchel Charges.

### 6.1 Downed, revive and failure

- At 0 health a player is downed, cannot act, and bleeds out after 40 seconds unless revived.
- A teammate revives a downed player by holding interact for 3 seconds, restoring 30% health.
- A bled-out player leaves a dog tag, and carrying it to any resupply pod respawns that player there.
- The mission fails if every player is downed or dead at the same time.
- In solo play, being downed means mission failure.
- There is no companion drone.

## 7. Resources

Missions contain only these resources:

- **Volticite** is the mission objective, held in each player's backpack with unlimited capacity.
- **Ferrin** goes into a team pool, and every 80 Ferrin calls one resupply pod that refills ammo and health.
- Holding the ping key calls a resupply pod to the pinged spot when the pool can pay for it.
- **Red health crystals** are scattered through the cave and heal on mining.

There are no secondary objectives, no other minerals and no carriable artifacts.

## 8. Enemies

### 8.1 Roster

| Vrill type | Role |
| --- | --- |
| Drone | Small, fast and weak, arriving in swarms |
| Warrior | Standard melee grunt |
| Bulwark | Armoured front with a weak glowing rear |
| Spitter | Stationary ranged acid turret |
| Wasp | Flying ranged harasser |
| Ravager | Rare elite brute with a charge attack |

### 8.2 Spawning

Enemies come from three sources:

- Ambient enemies and Spitters placed during cave generation.
- Timed swarm waves every 4 to 6 minutes.
- Objective-triggered swarms during Refinery pumping and on Lift Pod arrival.

At most 30 enemies are alive at once, and further spawns queue until there is room.

### 8.3 Movement

- Vrill emerge from burrow holes that open in walls, floors and ceilings near players, with a dirt burst and a sound cue.
- Ground types walk using Roblox pathfinding, recomputed as the terrain changes.
- A ground enemy whose path is blocked or too slow burrows and resurfaces closer to its target.
- Wasps fly with direct steering.
- Spitters are rooted in place.
- No enemy walks on walls or ceilings.

### 8.4 Difficulty

There is one difficulty.
Enemy counts, enemy health and the Volticite target scale with the number of players at launch, and stay locked for the rest of the mission.

## 9. Cave generation

- Each mission has one seed, and the server generates the whole cave once at mission start behind a loading screen.
- Generation finishes within about 20 seconds.
- The layout never regenerates during a mission, and the terrain is fully destructible.
- Caves are built from Roblox voxel Terrain, carved with `WriteVoxels` and edited at runtime with server-validated `FillBall` and `FillBlock` using Air.
- Each seed builds a graph of 7 to 10 large caverns of varied shapes, linked by winding tunnels.
- The cave fits roughly within a 500 x 200 x 500 stud volume.
- 3D noise shapes organic walls.
- Every cavern is reachable from the Dropcan, though some need vertical climbs or digging.
- Volticite veins, Ferrin nodes and health crystals spawn on cavern walls and ceilings as anchored MeshParts with no physics.
- There is one biome: dark violet crystal caves with glowing fungi and ambient particles, lit with Future lighting and fog.
- The same seed always produces the same cave.

## 10. Missions

### 10.1 Mission flow

1. The party launches from a hub Dropcan launch pad into a reserved mission server.
2. The cave generates behind a loading screen, and the Dropcan lands in a starting cavern.
3. The team completes the main objective.
4. The Lift Pod is called to a cavern far from the team, and a swarm triggers when it lands.
5. A 90 second countdown starts when the Lift Pod lands.
6. The Lift Pod launches, and the mission succeeds if at least one player is aboard.
7. The results screen shows for 15 seconds, then everyone teleports back to the hub.

### 10.2 Mining mission

- The objective is to deposit Volticite at the Dropcan, which stays in place as the team's base.
- The target is 120 Volticite for 1 player, 160 for 2 players, and 200 for 3 or 4 players.
- The cave contains Volticite equal to 150% of the target.
- Depositing is a hold on interact at the Dropcan that unloads the whole backpack.
- There is no cargo robot.

### 10.3 Refinery mission

1. The team chooses a flat spot in a large central cavern and calls the Refinery down there.
2. Three Volticite slurry wells spawn in distant caverns.
3. For each well, a player interacts at the well and walks back toward the Refinery, laying pipe behind them along their path.
4. Pipe is laid in floating segments of up to 80 studs, and the player can re-anchor mid-route.
5. Once all three wells are connected, pumping runs for 3 minutes under constant swarms.
6. Vrill target and break pipe segments, and players repair them by holding interact.
7. When pumping completes, a rocket launch sequence plays and the Lift Pod is called.

### 10.4 Joining and leaving

- Nobody joins a mission in progress.
- A player who leaves or disconnects forfeits that mission's rewards and cannot rejoin.
- The rest of the team carries on, and difficulty scaling stays locked to the launch count.

### 10.5 Results and rewards

- The results screen shows outcome, seed, time and Volticite delivered.
- It also shows credits and XP earned for each player.
- Credits are a base payout plus a share for Volticite delivered.
- A player left behind at launch receives half rewards.
- A failed mission pays 25% of what was earned up to that point.

## 11. Progression

- Missions award credits and class XP for the class played.
- Each class has 5 levels.
- Levels unlock upgrade tiers for that class's five items: primary, secondary, traversal tool, support tool and grenade.
- Each item has 3 tiers, and each tier offers a choice of 2 upgrades bought with credits.
- Tier unlocks by class level, with weapons being the primary and secondary and tools being the traversal tool, support tool and grenade:

| Level | Unlocks |
|---|---|
| 1 | Tier 1 for every item |
| 2 | Tier 2 weapons |
| 3 | Tier 2 tools |
| 4 | Tier 3 weapons |
| 5 | Tier 3 tools |

- Upgrades cost 600, 1200 and 1800 credits for tiers 1, 2 and 3.
- Bought upgrades can be swapped for free.
- There are no promotions, no overclocks and no cosmetics.
- Player data is saved with ProfileStore, the only third-party library in the project.

### 11.1 Linear progression target

- Every class level takes the same number of average successful missions: 3, so a class goes from level 1 to 5 in about 12 missions.
- Credits keep pace exactly, so when a tier unlocks the player can afford one choice in each of its 5 items.
- Player power grows in equal steps per level against the fixed difficulty.

## 12. Tuning and the balance audit

- I author all tuning: weapon stats, the 120 upgrade options, enemy health and damage, player-count scaling, the XP curve, credit payouts and upgrade prices.
- Tuning lives in one data module per domain so it can change without touching logic.
- A dedicated auditing agent runs a simulation on Lune that loads the exact same data and math modules the game uses.
- The simulation covers every combination of party size 1 to 4, class composition, mission type, outcome (success, failure at each phase, left behind), upgrade path, and three skill bands.
- It measures time-to-kill per weapon against each enemy, damage taken per swarm, mission duration, missions-to-level, credit balance at each tier unlock, and strictly dominant upgrade choices.
- The agent retunes the data modules toward the linear progression target, re-runs the simulation and reports the results.
- The audit runs twice: once all classes, enemies and progression are implemented, and again after the first full end-to-end playtests, using measured swarm sizes and mission times.

## 13. Hub

- The hub is a small walkable ship deck in a public server holding up to 16 players.
- It has three terminals: Class Select (which also shows each tool's description), Upgrades and Mission Board.
- It has a controls board, a Settings terminal and a terminal to replay the walkthrough.
- Parties of up to 4 form by standing on a Dropcan launch pad.
- The first player on the pad leads it and picks the mission at the Mission Board, and a 10 second countdown teleports everyone on the pad into one reserved mission server.
- A banner tells each player on a pad whether they lead it, are waiting for the leader, or how long is left before launch.
- If the leader steps off, the next player aboard leads and any countdown is cancelled.
- Friends join each other through Roblox's normal join flow into the hub.

### 13.1 Mission Board

- It offers the 2 mission types, each launched with a fresh random seed.
- An optional field accepts a typed seed to replay a cave.
- There is one fixed mission length, aiming for 15 to 20 minutes.

## 14. Onboarding

- On a player's first join, the hub offers "Play walkthrough" or "Skip".
- The walkthrough is a short guided solo run in a small, handcrafted fixed cave, played with the selected class.
- It covers look and move, camera toggle, mining Volticite, depositing at the Dropcan, the traversal tool, collecting Ferrin and calling a resupply, a small swarm, a grenade, revive mechanics explained on screen, and boarding the Lift Pod.
- It takes about 5 minutes and pays no rewards.
- It can be replayed any time from the hub.
- There are no other tutorials or contextual hints.
- The cave has four caverns: a landing cavern for mining, a cavern with a ledge about 9 studs high that every class climbs with its traversal tool, an upper cavern for Ferrin, the resupply pod and a 5 Vrill practice swarm, and a far cavern where the Lift Pod lands.
- It runs 13 steps, each waiting on something the server sees for itself; only the camera switch is reported by the client.
- A card at the top of the screen shows the current step with the player's own key or gamepad bindings.
- A downed player gets back up after 5 seconds instead of failing the run.

## 15. UI

- The HUD shows health, shield, ammo, grenades, flares, the objective tracker and team status.
- On-screen markers show the Dropcan, Lift Pod, Refinery, wells, teammates and pings, with distance readouts.
- A compass strip sits at the top of the screen.
- There is no minimap and no 3D scanner map.
- The settings menu contains mouse sensitivity, gamepad sensitivity, invert Y, field of view, master, music and SFX volume, and gamepad aim assist strength.
- Gamepad aim assist slows aim near enemies.
- Settings save per player.
- The menu key opens the settings menu in the hub and in missions, and closes any open menu.

## 16. Audio

- An ambient cave soundscape plays throughout: drips, distant rumbles and hive chittering.
- A combat music track fades in during swarms and out after.
- Distinct stingers play for swarm incoming, objective complete, Lift Pod inbound and launch countdown.
- All audio comes from Roblox's licensed audio library: APM Music for music and stingers, Pro Sound Effects for effects, and sounds built into the Roblox client.
- Music and SFX go through separate volume groups.
- `src/shared/Config/Audio.luau` lists every sound with its volume, pitch, repeat gap and reach.

## 17. Architecture

### 17.1 Places

- There are two places in one experience: the Hub (start place) and the Mission place.
- Each mission runs in a reserved server created through TeleportService.
- Solo play is a party of one in its own reserved server, so solo and co-op share one code path.

### 17.2 Networking and authority

- Weapons fire instantly on the shooting client with tracer, muzzle flash and hit marker.
- The server validates every hit for fire rate, ammo, range, line of sight and lag-compensated target position.
- Only the server applies damage, mining, terrain edits and rewards.
- Enemies are simulated on the server and replicated to clients.
- The server samples every crew member's position 30 times a second for fall damage and a speed check.
- Horizontal travel spends a budget that refills at 1.2 times sprint speed and banks up to 2.5 seconds, so late positions after a lag spike pass while speed hacks and teleports are put back.
- Grapple pulls and cable rides are recognised from what the server knows (when a grapple fired, where cables run), never from client reports.

### 17.3 Performance budget

- A mid-range PC holds a steady 60 FPS.
- At most 30 enemies are alive at once.
- Cave generation finishes within about 20 seconds.
- Mineral and crystal deposits are anchored MeshParts with no physics.
- Particles and lights are capped per area.

## 18. Tooling and workflow

- Code lives as `.luau` files in this repo and syncs live into Roblox Studio through Rojo.
- The owner works in Studio for playtesting, lighting and asset placement.
- Rokit pins tool versions in `rokit.toml`: Rojo, StyLua, Selene and Lune.
- The Roblox Studio MCP server lets the agent run Luau in the open Studio session, inspect the place and run playtests.
- ProfileStore is vendored as a single file, with no package manager.
- The project is versioned with git.

### 18.1 Owner installs

The agent never installs tools.
The owner installs:

1. Rokit.
2. The pinned tools, by running `rokit install` in the repo.
3. The Rojo Studio plugin, by running `rojo plugin install`.
4. The Roblox Studio MCP server, following install steps the agent confirms beforehand.

## 19. Testing

- Pure logic has automated tests: seeded generation determinism, damage and progression math, and upgrade application.
- These tests run inside Studio through the Studio MCP with a small in-house test runner.
- The agent verifies gameplay end-to-end by playtesting in Studio through the MCP, including multi-client tests for co-op.
- Bug fixes start with an end-to-end reproduction that fails before the fix.

### 19.1 Studio test hooks

These Workspace attributes only work in Studio.

| Attribute | Place | Effect |
|---|---|---|
| `DevMissionType` | Mission | `Mining` or `Refinery` for the Studio launch |
| `DevSeed` | Mission | Fixed cave seed |
| `DevClass` | Mission | Class for the Studio launch |
| `DevWalkthrough` | Mission | Runs the walkthrough |
| `DevWalkthroughStep` | Mission | Starts the walkthrough at a step, moving the player there |
| `DevSwarm` | Mission | Set to a size to call a swarm |
| `DevGodMode` | Mission | The crew takes no damage |
| `DevPumpSeconds` | Mission | Shortens Refinery pumping |
| `DevConnectWells` | Mission | Runs every unconnected well straight to the Refinery |
| `DevCredits` | Hub | Grants credits to every player |
| `DevXp` | Hub | Grants XP to every player's selected class |

The player attribute `DebugLookAt`, set to a world point, turns the mission camera to face it.
The player attribute `DevTeleport`, set to a world point from the server, moves that player there without tripping the speed check.

## 20. Publishing

Teleports and DataStores only work in a published experience.
Launching from a pad and returning to the hub show a notice instead of teleporting until both place ids are set.

The owner:

1. Opens the hub place (`ContractMiners.rbxl`) with Rojo connected on port 34872 and chooses File, Publish to Roblox, creating a new experience named Contract Miners.
   This makes the hub the start place.
2. Opens the mission place (`ContractMinersMission.rbxl`) with Rojo connected on port 34873 and chooses File, Publish to Roblox As, picks the Contract Miners experience and adds it as a new place named Mission.
3. Copies both place ids from the Creator Dashboard (Places list) and sends them to the agent, which sets `HUB` and `MISSION` in `src/shared/Config/Places.luau` and republishes both places.
4. In Game Settings, Security, turns on Enable Studio Access to API Services, so saves also work in Studio.
5. In Game Settings, Avatar, sets the avatar type to R15.
6. Completes the Maturity and Compliance questionnaire in the Creator Dashboard, where cartoon violence against aliens should land at a low maturity rating.
7. Clears the Studio test attributes (section 19.1) in both places before the final publish; they are ignored outside Studio but should not ship set.
8. Makes the experience public when ready.
