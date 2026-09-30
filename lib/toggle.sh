#!/bin/bash
# lib/toggle.sh — `svd disable` / `svd enable`: switch the stack off without
# uninstalling it. The flag in $SVD_ROOT (under /home, survives updates) also
# stops svd-heal from turning everything back on after a SteamOS update.

DISABLED_FLAG="${DISABLED_FLAG:-$SVD_ROOT/disabled}"
SVD_UNITS=(svd-watchdog vd-watcher sunshineVD svd-heal)

svd_is_disabled() { [ -f "$DISABLED_FLAG" ]; }

# Sunshine reads its config only at startup. Restart it through Decky (the
# plugin starts it again when its toggle is on) so the prep-command change
# takes effect; a stopped Sunshine picks it up on its next start anyway.
restart_sunshine_if_running() {
  pgrep -x sunshine >/dev/null 2>&1 || return 0
  log "Restarting Sunshine via Decky so it reloads its config"
  run systemctl restart plugin_loader || log "WARNING: restart Sunshine in Decky yourself"
}

disable_apply() {
  require_root
  log "Disabling svd (virtual display, watchdog, auto-heal)"
  # Stopping sunshineVD makes the daemon drop the virtual display and hand
  # the physical monitor back to gamescope.
  run systemctl disable --now "${SVD_UNITS[@]}" || true
  # give gamescope its direct scanout back if a stream had forced composition
  run "$VD_DIR/gamescope-composite.sh" off 2>/dev/null || true
  # Without vd-watcher nothing reads the FIFO, so our connect command would
  # block every stream start: take it out of Sunshine's config.
  config_remove "$HERE"
  restart_sunshine_if_running
  if [ "$DRY_RUN" = "1" ]; then echo "DRY-RUN would create $DISABLED_FLAG"; return 0; fi
  touch "$DISABLED_FLAG"
  chown deck:deck "$DISABLED_FLAG" 2>/dev/null || true
  log "svd disabled. Sunshine (Decky) now streams the physical display. Re-enable with: svd enable"
}

enable_apply() {
  require_root
  log "Enabling svd"
  run rm -f "$DISABLED_FLAG"
  do_repair
  restart_sunshine_if_running
}
