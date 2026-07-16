# SteamOS VD + Sunshine Utility (`svd`)

`svd` installs and maintains a SteamOS Game Mode virtual-display + Sunshine
streaming stack in one action: it writes Sunshine config directly and
auto-heals the setup across SteamOS updates.

## Status

Early scaffolding. The `svd` CLI dispatcher and shared `lib/common.sh` exist;
most commands are stubs pending later tasks (prerequisite detection, stack
install, config merge, auto-heal, uninstall).

## Usage

```
svd <command> [--dry-run] [args]
```

Commands:

- `install` — full first-time setup (prereqs -> stack -> config -> auto-heal)
- `repair` — re-apply the full stack idempotently
- `status` — report health of each component
- `check-prereqs` — detect Decky Loader + Decky Sunshine and guide if missing
- `uninstall` — remove the stack (`--purge` also removes the Sunshine flatpak)
- `help` — show usage

`--dry-run` prints intended changes without mutating anything (where
supported by the target command).

## Development

- Requires bash, and for tests: [`bats-core`](https://github.com/bats-core/bats-core)
  and `python3`.
- Run bash tests: `bats tests/*.bats`
- Run Python tests (once helpers exist): `python3 -m pytest -q`
- Lint shell scripts: `shellcheck svd lib/*.sh`

CI (`.github/workflows/ci.yml`) runs both suites on every push/PR.
