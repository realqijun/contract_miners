# Contract Miners

An original Roblox co-op mining horde shooter.
The full design lives in [docs/DESIGN.md](docs/DESIGN.md).

## Setup

1. Install Rokit: `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
2. Restart the terminal, then run `rokit install` in this folder.
3. Install the Rojo Studio plugin: `rojo plugin install`
4. In Roblox Studio, open Assistant, click the `...` menu, choose Manage MCP Servers, and turn on Enable Studio as MCP server.
5. In Assistant Settings under MCP Servers, open Quick connect and turn on Claude Code.
6. Restart Roblox Studio and Claude Code.

## Syncing code into Studio

The game has two places, and each has its own Rojo project.

- Hub place: `rojo serve hub.project.json`
- Mission place: `rojo serve mission.project.json --port 34873`

Then press Connect in the Rojo plugin inside the matching Studio window.

## Layout

| Path | Synced to | Contents |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | Data, config and pure logic used by server and client |
| `src/client` | `ReplicatedStorage.Client` | Client modules used by both places |
| `src/server` | `ServerScriptService.Server` | Server modules used by both places |
| `src/hub` | Hub place scripts | Hub-only server and client entry points |
| `src/mission` | Mission place scripts | Mission-only server and client entry points |
| `src/vendor` | `ServerScriptService.Vendor` | Vendored third-party code (ProfileStore) |
| `tests` | - | In-Studio test suites |
| `sim` | - | Lune balance simulation |

## Checks

- Format: `stylua src tests sim`
- Lint: `selene src tests sim`
