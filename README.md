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

## Install (Steam Deck, Desktop Mode → Konsole)

    curl -fsSL https://raw.githubusercontent.com/<you>/SteamOS-VD-Sunshine/main/bootstrap.sh | bash

Prerequisites (the installer checks and guides you): Decky Loader + the Decky
Sunshine plugin, and a sudo password set for the `deck` user.

After install, two one-time Game Mode steps remain: enable the Sunshine plugin,
and pair Moonlight with the PIN. Everything else — including the Sunshine
Command Preparations and update auto-heal — is configured automatically.

## Security note

`svd` installs a passwordless sudoers entry scoped to exactly
`/home/deck/.local/bin/svd repair` so the auto-heal unit can repair the
stack without a password prompt. That path is a symlink into
`/home/deck/.local/share/svd/`, which is owned and writable by `deck`.
In practice this means `deck` can obtain passwordless root (by editing
the `svd` engine that `sudo svd repair` executes, then invoking it). On a
single-user Steam Deck where the `deck` account already has full sudo
access, this is an accepted tradeoff — it does not grant any privilege
`deck` doesn't already have — but it should not be treated as a genuine
privilege boundary between "deck user" and "root" on any device where
that separation matters.

## Development

- Requires bash, and for tests: [`bats-core`](https://github.com/bats-core/bats-core)
  and `python3`.
- Run bash tests: `bats tests/*.bats`
- Run Python tests (once helpers exist): `python3 -m pytest -q`
- Lint shell scripts: `shellcheck svd lib/*.sh`

CI (`.github/workflows/ci.yml`) runs both suites on every push/PR.
