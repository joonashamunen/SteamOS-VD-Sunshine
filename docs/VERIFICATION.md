# On-Device Verification (per release)

Run on a real Steam Deck. Prereqs: Decky Loader + Decky Sunshine installed;
`deck` sudo password set.

## A. Fresh install
1. Desktop Mode → Konsole: run the bootstrap one-liner.
2. Expect: prereq check passes, `[1/6]..[6/6]` progress, checklist printed.
3. `svd status` → sunshineVD active, vd-watcher active, flatpak installed, fifo present.
4. `grep global_prep_cmd /root/.var/app/dev.lizardbyte.app.Sunshine/config/sunshine/sunshine.conf`
   → shows our vd-connect Do command.

## B. Streaming connect
1. Game Mode → enable Decky Sunshine plugin; pair Moonlight (PIN).
2. Connect from Moonlight. In sunshine.log:
   - 'Executing Do Cmd' → 'CLIENT CONNECTED' gap ~5–15s.
   - 'Found connector ID' = the VIRTUAL connector (DP), not the physical panel.
   - Moonlight stats show the client's own resolution.

## C. Idempotency
1. Re-run `sudo svd repair`. Expect no errors, no duplicate global_prep_cmd
   entry (`grep` shows exactly one vd-connect Do), services still active.

## D. Auto-heal update survival

On boot, the root system unit `/etc/systemd/system/svd-heal.service` runs
`svd heal`. `heal` compares the recorded BUILD_ID
(`~/.local/share/svd/last-build.stamp`) with the current one; if it changed
(or there is no stamp yet) it runs a full repair as root and writes the new
stamp. No sudo is involved: a real SteamOS update (20260922.1 -> 20260925.101)
reset `/etc/sudoers.d` but kept `/etc/systemd/system`. The user unit
`svd-heal.service` (in /home) only runs `svd heal-check`, which logs a warning
to run `sudo svd repair` if the root unit has gone missing.

1. After install: `systemctl is-enabled svd-heal` -> enabled;
   `sudo svd status` lists `svd-heal enabled`.
2. Simulate an update: `echo 00000000.0 > ~/.local/share/svd/last-build.stamp`,
   then `sudo systemctl start svd-heal` (or reboot). `journalctl -u svd-heal -b`
   shows "SteamOS build changed" and the repair; the stamp holds the current
   BUILD_ID.
3. Healer-missing warning: `sudo mv /etc/systemd/system/svd-heal.service /tmp/`,
   `systemctl --user start svd-heal`, and `journalctl --user -u svd-heal -b`
   shows the "Run: sudo svd repair" warning; then `sudo svd repair` restores it.
4. TRUE update test (when a real SteamOS update lands): heal runs with no
   manual action and the stamp matches the new BUILD_ID.

## E. Uninstall
1. `sudo svd uninstall` → units/healer/daemon gone; Decky untouched.
2. `sudo svd uninstall --purge` → also removes the Sunshine flatpak.
