#!/bin/bash
# lib/uninstall.sh — remove stack. --purge also removes the Sunshine flatpak.

uninstall_apply() {
  local purge="$1"
  require_root
  log "Uninstalling svd stack"
  run systemctl disable --now svd-heal svd-watchdog sunshineVD vd-watcher 2>/dev/null || true
  run rm -f /etc/systemd/system/sunshineVD.service /etc/systemd/system/vd-watcher.service /etc/systemd/system/svd-watchdog.service /etc/systemd/system/svd-heal.service
  run rm -f /etc/sudoers.d/zz-svd-heal /etc/sudoers.d/svd-heal
  run rm -f /home/deck/.config/systemd/user/svd-heal.service
  run systemctl daemon-reload
  run sudo -u deck XDG_RUNTIME_DIR=/run/user/1000 systemctl --user disable svd-heal.service 2>/dev/null || true
  run rm -rf /home/deck/sunshine_virt_display
  if [ "$purge" = "1" ]; then
    log "Purging Sunshine flatpak"
    run flatpak mask --remove dev.lizardbyte.app.Sunshine || true
    run flatpak uninstall -y dev.lizardbyte.app.Sunshine || true
  fi
  log "Uninstall complete. (Decky + Decky Sunshine left untouched.)"
}
