#!/bin/bash
# lib/config.sh — deploy vd-connect.sh and merge Sunshine global_prep_cmd.

APPCFG=/root/.var/app/dev.lizardbyte.app.Sunshine/config
DO_CMD='sh /root/.var/app/dev.lizardbyte.app.Sunshine/config/vd-connect.sh'
UNDO_CMD='sh -c "echo disconnect > /root/.var/app/dev.lizardbyte.app.Sunshine/config/trigger.fifo"'

config_apply() {
  local here="$1"   # repo/deploy root containing payload/ and helpers/
  log "Applying Sunshine config (global_prep_cmd + vd-connect.sh)"
  run mkdir -p "$APPCFG"
  run install -m 0755 "$here/payload/vd-connect.sh" "$APPCFG/vd-connect.sh"
  # Flatpak Sunshine reads $XDG_CONFIG_HOME/sunshine/sunshine.conf, i.e. config/sunshine/.
  local conf="$APPCFG/sunshine/sunshine.conf"
  run mkdir -p "$APPCFG/sunshine"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY-RUN would merge global_prep_cmd + system_tray=disabled into $conf"
    return 0
  fi
  # system_tray=disabled: Sunshine's Qt tray aborts (SIGABRT) when it can't reach a
  # display, which is always the case for root Sunshine under the Decky plugin.
  python3 "$here/helpers/config_merge.py" "$conf" "$DO_CMD" "$UNDO_CMD" system_tray=disabled \
    || die "config merge failed"
  log "Config applied."
}
