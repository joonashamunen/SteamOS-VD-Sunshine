#!/bin/bash
# lib/common.sh — shared paths, logging, dry-run helpers. Source, don't execute.

SVD_ROOT="${SVD_ROOT:-/home/deck/.local/share/svd}"
SVD_LOG="${SVD_LOG:-$SVD_ROOT/svd.log}"
DRY_RUN="${DRY_RUN:-0}"

log() {
  local msg="[$( { date '+%Y-%m-%d %H:%M:%S'; } 2>/dev/null || echo '?')] $*"
  echo "$msg"
  mkdir -p "$(dirname "$SVD_LOG")" 2>/dev/null || true
  echo "$msg" >> "$SVD_LOG" 2>/dev/null || true
}

die() { echo "ERROR: $*" >&2; exit 1; }

require_root() { [ "$DRY_RUN" = "1" ] || [ "$(id -u)" -eq 0 ] || die "This action must run as root (use sudo)."; }

# run CMD...  — execute, or under dry-run just print.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY-RUN would run: $*"
  else
    "$@"
  fi
}
