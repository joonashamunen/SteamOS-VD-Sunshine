#!/bin/bash
# Bring Sunshine back when it dies although Decky Sunshine wants it running.
#
# Decky Sunshine records the user's intent in its settings (lastRunState =
# "start"/"stop") and, on load, starts Sunshine when the intent is "start".
# Older store builds have no crash watchdog of their own, so a crashed
# Sunshine stays down. We restart plugin_loader, which makes the plugin start
# Sunshine itself: the plugin keeps owning the process and its toggle state.
#
# GRACE is longer than the plugin's own watchdog (newer builds check every
# 20 s), so where the plugin recovers by itself we never act. LIMIT restarts
# per WINDOW stop a crash loop from reloading Decky forever.

SETTINGS="${SVD_DECKY_SETTINGS:-/home/deck/homebrew/settings/decky-sunshine/decky-sunshine.json}"
RUNNING_CMD="${SVD_WD_RUNNING_CMD:-pgrep -x sunshine}"
RESTART_CMD="${SVD_WD_RESTART_CMD:-systemctl restart plugin_loader}"
INTERVAL="${SVD_WD_INTERVAL:-15}"
GRACE="${SVD_WD_GRACE:-60}"
LIMIT="${SVD_WD_LIMIT:-3}"
WINDOW="${SVD_WD_WINDOW:-600}"

missing_since=""
restart_times=()
gave_up=0

wd_log() { echo "sunshine-watchdog: $*"; }

wd_wants_running() {
  [ -r "$SETTINGS" ] || return 1
  python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1])).get("lastRunState") != "start")' \
    "$SETTINGS" 2>/dev/null
}

wd_is_running() { eval "$RUNNING_CMD" >/dev/null 2>&1; }

# One check at time $1 (seconds). Restarts at most once per call.
wd_tick() {
  local now="$1" t kept=()
  if wd_is_running || ! wd_wants_running; then
    missing_since=""
    return 0
  fi
  [ -n "$missing_since" ] || missing_since="$now"
  [ $((now - missing_since)) -ge "$GRACE" ] || return 0

  for t in "${restart_times[@]}"; do
    [ $((now - t)) -lt "$WINDOW" ] && kept+=("$t")
  done
  restart_times=("${kept[@]}")
  if [ "${#restart_times[@]}" -ge "$LIMIT" ]; then
    [ "$gave_up" = 1 ] || wd_log "Sunshine keeps dying; giving up until the restart window clears"
    gave_up=1
    return 0
  fi
  gave_up=0
  wd_log "Sunshine gone for $((now - missing_since)) s although Decky wants it running; restarting plugin_loader"
  eval "$RESTART_CMD"
  restart_times+=("$now")
  missing_since="$now"   # the restarted Sunshine gets a fresh grace period
}

if [ "${SVD_WD_LIB:-0}" != 1 ]; then
  wd_log "watching (grace ${GRACE}s, limit ${LIMIT}/${WINDOW}s)"
  while true; do
    wd_tick "$(date +%s)"
    sleep "$INTERVAL"
  done
fi
