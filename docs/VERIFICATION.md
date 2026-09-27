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

## D. Auto-heal update-survival spike (the named risk)

On boot, the `svd-heal.service` user unit runs `svd heal` (unprivileged, as
`deck`). `heal` checks the recorded BUILD_ID against the current one; if it
changed (or there is no stamp yet), it runs `sudo svd repair` (the one
passwordless, scoped sudoers command), writes the new stamp, and fires a
"repaired after update" notification. If the BUILD_ID is unchanged, heal
exits without repairing or notifying.

Note: on the very first boot after a fresh install there is no stamp on
disk yet, so heal will treat that as "changed", run one repair (harmless
and idempotent since the stack is already correctly configured), and then
write the initial stamp.

1. Record current: `svd repair` then `cat ~/.local/share/svd/last-build.stamp`.
2. Simulate an update: edit the stamp to a fake older BUILD_ID
   (`echo 00000000.0 > ~/.local/share/svd/last-build.stamp`), and
   `sudo rm /etc/systemd/system/sunshineVD.service` to mimic a wiped unit.
3. Reboot. After reaching Game Mode, `svd status` → services active again;
   stamp updated to current BUILD_ID; a "repaired after update" notice seen.
4. If heal did NOT fire: confirm `systemctl --user is-enabled svd-heal.service`
   and check `~/.local/share/svd/svd.log`. Fallback per spec:
   `~/.config/environment.d` trigger or Decky-backed trigger.
5. TRUE update test (when a real SteamOS update lands): confirm heal fires
   automatically with no manual action.

## E. Uninstall
1. `sudo svd uninstall` → units/sudoers/healer/daemon gone; Decky untouched.
2. `sudo svd uninstall --purge` → also removes the Sunshine flatpak.
