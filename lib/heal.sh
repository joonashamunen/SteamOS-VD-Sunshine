#!/bin/bash
# lib/heal.sh — auto-heal after SteamOS updates.
#
# A root system oneshot (/etc/systemd/system/svd-heal.service) runs `svd heal`
# on every boot and repairs the stack when BUILD_ID changed. It needs no sudo:
# SteamOS updates were observed to reset /etc/sudoers.d (deleting the old
# passwordless rule the user-unit healer relied on) while keeping
# /etc/systemd/system. If /etc/systemd/system is ever wiped, the whole stack is
# gone with it, so the user unit (in /home, which always survives) only checks
# that the root healer exists and tells the user to run `sudo svd repair`.

OS_RELEASE=/etc/os-release
STAMP="$SVD_ROOT/last-build.stamp"
SVD_BIN=/home/deck/.local/bin/svd
SYSTEM_UNIT="${SYSTEM_UNIT:-/etc/systemd/system/svd-heal.service}"
USER_UNIT="${USER_UNIT:-/home/deck/.config/systemd/user/svd-heal.service}"
LEGACY_SUDOERS=(/etc/sudoers.d/zz-svd-heal /etc/sudoers.d/svd-heal)

heal_render_unit() {
  cat <<EOF
[Unit]
Description=SVD auto-heal after SteamOS update
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SVD_BIN heal

[Install]
WantedBy=multi-user.target
EOF
}

heal_render_user_unit() {
  cat <<EOF
[Unit]
Description=SVD check that the root auto-heal service is installed

[Service]
Type=oneshot
ExecStart=$SVD_BIN heal-check

[Install]
WantedBy=default.target
EOF
}

heal_install() {
  require_root
  log "Installing auto-heal (root system unit + user check unit)"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY-RUN would write $SYSTEM_UNIT and $USER_UNIT, enable both, remove legacy sudoers"
    return 0
  fi
  heal_render_unit > "$SYSTEM_UNIT"
  systemctl daemon-reload
  systemctl enable svd-heal.service

  mkdir -p "$(dirname "$USER_UNIT")"
  heal_render_user_unit > "$USER_UNIT"
  chown deck:deck "$(dirname "$USER_UNIT")" "$USER_UNIT"
  sudo -u deck XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload \
    && sudo -u deck XDG_RUNTIME_DIR=/run/user/1000 systemctl --user enable svd-heal.service \
    || log "WARNING: could not enable the user check unit now (no active user session?); the next svd repair retries."

  rm -f "${LEGACY_SUDOERS[@]}"
}

# Called by the root system unit on each boot.
heal_run() {
  local here="$1"
  if [ "$(id -u)" -ne 0 ]; then
    log "svd heal must run as root (it is started by svd-heal.service)"
    return 1
  fi
  if python3 "$here/helpers/build_id.py" changed "$OS_RELEASE" "$STAMP"; then
    log "SteamOS build changed (or first run) — repairing stack"
    do_repair
    python3 "$here/helpers/build_id.py" current "$OS_RELEASE" > "$STAMP"
    chown deck:deck "$STAMP" 2>/dev/null || true
    _notify "Virtual display repaired after update"
  else
    log "SteamOS build unchanged — no heal needed"
  fi
}

# Called by the user unit on each login: warn if the root healer is gone.
heal_check() {
  [ -f "$SYSTEM_UNIT" ] && return 0
  log "WARNING: $SYSTEM_UNIT is missing, so updates will not be auto-repaired. Run: sudo svd repair"
  _notify "Virtual display setup needs repair: run sudo svd repair"
}

_notify() {
  if command -v steamos-notify >/dev/null 2>&1; then steamos-notify "$1"; else log "notify: $1"; fi
}
