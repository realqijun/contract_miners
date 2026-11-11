# Balance simulation

A Lune simulation of Contract Miners that runs on the game's own tuning data and math.
It is the tool behind the balance audit described in `docs/DESIGN.md` §12.

## Running it

Run every command from the repository root, with the Rokit tools on the path.

```sh
lune run sim/run.luau                     # every section, full sample sizes (about 25 minutes)
lune run sim/run.luau -- --quick          # every section, small samples (a few minutes)
lune run sim/run.luau -- ttk dominance    # only the named sections
lune run sim/run.luau -- --out sim/out/before   # save the Markdown somewhere else
```

The sections are `ttk`, `swarms`, `missions`, `dominance`, `power` and `progression`.
Each prints Markdown and is also saved to `sim/out/<section>.md` (or the `--out` folder); git ignores `sim/out`.
Runs are seeded, so the same code and data always give the same numbers.

## What it loads from the game

`src/Loader.luau` reads the Roblox-style modules in `src/` and runs them inside Lune unchanged.
It compiles each file with `@lune/luau` and gives it a fake `script` that walks the real folders, so `require(script.Parent.Config.Tools)` works as in Studio.
`game:GetService` follows `mission.project.json`, Roblox datatypes come from `@lune/roblox`, and `Random` is a seeded stand-in.
Nothing in the simulation copies a tuning number.
The config modules, `Stats`, `Progress`, `Progression.reward` and the cave generator `Cave/Layout` are loaded directly.
The few tuning values the server keeps as local constants (the freeze bonus, Refinery swarm sizes, the Lift Pod swarm and so on) are read out of the server scripts by pattern in `src/Game.luau`.
If the server code changes shape, the simulation stops with an error instead of going stale.

## What it models

- `src/Weapon.luau` fires each weapon the way the client and server do: magazines, reloads, bursts, spin-up and heat, stream ticks and the Arc Mortar's reload.
- `src/Duel.luau` measures time-to-kill against one Vrill.
- `src/Arena.luau` plays a fight: the Spawner's queue and live cap, the Hive's movement and attacks, grenades, fences, domes, revives, resupply pods and Refinery pipes.
- `src/Mission.luau` plays a whole mission on a generated cave: travel and climbing, mining or pipe-laying, sleeping Vrill, timed swarms, pumping and the Lift Pod.
- `src/Career.luau` plays careers from a fresh save through the game's `Progress` rules.
- `src/Power.luau` measures upgrade axes for the dominance check and a crew power index per level.

## Assumptions

The human side of play is not in the game data, so the simulation assumes it.
`src/Bands.luau` defines the low, mid and high skill bands: aim error, tracking lag, recoil control, weakspot intent, time spent firing, reaction time, and how often enemy attacks connect.
`src/Assumptions.luau` holds target sizes, crowd behaviour and mission pacing.
Pacing was set by hand toward the design's 15 to 20 minute missions; a mid-skill crew of four currently finishes a Mining mission in about 12 minutes.
These are the numbers to replace with playtest measurements in the second audit run.
