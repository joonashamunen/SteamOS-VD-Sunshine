# SteamOS VD + Sunshine (`svd`)

Stream SteamOS **Game Mode** to Moonlight at your **client's native resolution**,
with no dummy plug. When a Moonlight client connects, `svd` gives Game Mode a
virtual display at the resolution and refresh rate the client asks for, and
switches back to your real monitor when the stream ends.

`svd` installs and maintains the whole stack in one command, writes Sunshine's
config for you, and repairs itself after SteamOS updates.

## Status

Working on real hardware, verified end to end on a SteamOS desktop PC (AMD
RX 9060 XT) on SteamOS 20260922.1 (stable) and 20260925.101 (beta):

- streaming at the client's resolution, with picture and sound;
- connecting and disconnecting without restarting Game Mode (a running game survives);
- host sleep and client sleep mid-stream, with the session resuming after wake;
- automatic recovery if Sunshine crashes;
- automatic repair after a SteamOS update, and after switching channels back.

Not yet tested on a Steam Deck itself. See [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Requirements

- SteamOS with an AMD GPU
- [Decky Loader](https://decky.xyz) and the **Decky Sunshine** plugin
  (Decky store → "Sunshine"); the installer checks for both
- A sudo password set for the `deck` user (`passwd` in Konsole)

## Install

In Desktop Mode, open Konsole and run:

    curl -fsSL https://raw.githubusercontent.com/joonashamunen/SteamOS-VD-Sunshine/main/bootstrap.sh | bash

Then, in Game Mode:

1. Decky (plug icon) → Sunshine → switch it **on**.
2. Open Sunshine's web UI at `https://<host-ip>:47990`, and **set your own
   username and password**. Don't keep the defaults: anyone on your network
   could pair with your machine.
3. Pair Moonlight with the PIN (web UI PIN tab, or the plugin's PIN field).

Everything else, including Sunshine's connect/disconnect commands, is
configured automatically.

## Usage

```
svd <command> [--dry-run]
```

| Command | What it does |
|---|---|
| `install` | First-time setup: prerequisites → stack → Sunshine config → auto-heal |
| `repair` | Re-apply everything (safe to run any time; restarts the services) |
| `status` | Health of each component (`sudo svd status` for the full picture) |
| `check-prereqs` | Check for Decky Loader + Decky Sunshine |
| `uninstall` | Remove the stack (`--purge` also removes the Sunshine flatpak) |
| `heal`, `heal-check` | Used by the auto-heal units; not needed by hand |

`--dry-run` prints what `install`/`repair` would change without changing anything.

## How it works

- **Sunshine** is the root flatpak `dev.lizardbyte.app.Sunshine`, started by the
  Decky Sunshine plugin. `svd` writes its `global_prep_cmd`, so each stream's
  connect command asks for a virtual display and the undo command releases it.
- **`sunshineVD`** runs the
  [frostplexx/sunshine_virt_display](https://github.com/frostplexx/sunshine_virt_display)
  v2 daemon, which creates the display with an EDID override on a free
  connector. `svd` launches it through `vd-daemon.py`, which stops it from taking
  DRM master away from gamescope (that crashes Game Mode) and keeps the virtual
  display through sleep. gamescope moves between outputs by itself.
- **`vd-watcher`** bridges the sandboxed Sunshine to the daemon through a FIFO.
- **`svd-watchdog`** restarts Sunshine (through Decky, so the plugin stays in
  charge) if it crashes while the plugin's toggle is on.
- **`svd-heal`** runs at boot as root. When the SteamOS build changed, it re-runs
  `repair`. A user unit in `/home` warns if the root unit ever goes missing.

## Known limitations

- **Sunshine is pinned to 2026.516.143833** and flatpak-masked. Version 2026.914
  can't capture the virtual display (black stream), and its tray crashes under
  the Decky plugin.
- **A game that is already running keeps its old resolution** when the display
  switches (partial image plus garbage). Start games after connecting, or toggle
  the game's display mode. No tool can make a running game re-read its screen.
- **No pop-up notification** after an automatic repair; it's logged
  (`journalctl -u svd-heal`).
- One stream at a time.

## Uninstall

    sudo ~/.local/bin/svd uninstall          # keep the Sunshine flatpak
    sudo ~/.local/bin/svd uninstall --purge  # also remove it

Decky Loader and the Decky Sunshine plugin are left in place.

## Security note

`svd` installs no sudoers rules. Its root pieces are systemd system units
(`svd-heal`, `sunshineVD`, `vd-watcher`, `svd-watchdog`) that execute code under
`/home/deck` (`~/.local/share/svd`, `~/sunshine_virt_display`). That code is owned
and writable by `deck`, so `deck` can get root by editing it and rebooting. On a
single-user SteamOS machine where `deck` already has full sudo access this grants
nothing new, but it is not a privilege boundary between `deck` and root.

## Development

- Tests need [`bats-core`](https://github.com/bats-core/bats-core), `python3` and `pytest`.
- `bats tests/*.bats` and `python3 -m pytest -q`
- `shellcheck -x svd lib/*.sh payload/*.sh bootstrap.sh`

CI runs the tests and shellcheck on every push and pull request.

## Credits

- [Sunshine](https://github.com/LizardByte/Sunshine) and [Moonlight](https://moonlight-stream.org)
- [frostplexx/sunshine_virt_display](https://github.com/frostplexx/sunshine_virt_display) (MIT)
- [Decky Sunshine](https://github.com/s0t7x/decky-sunshine) and [Decky Loader](https://decky.xyz)

## License

[MIT](LICENSE)
