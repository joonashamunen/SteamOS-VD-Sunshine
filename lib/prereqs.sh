#!/bin/bash
# lib/prereqs.sh — detect Decky Loader + Decky Sunshine, guide if missing.

_has_decky() { [ -d /home/deck/homebrew/services ] || systemctl is-enabled plugin_loader >/dev/null 2>&1; }
_has_decky_sunshine() { ls -d /home/deck/homebrew/plugins/*[Ss]unshine* >/dev/null 2>&1; }

check_prereqs() {
  local ok=0
  if ! _has_decky; then
    ok=1
    cat <<'EOF'
[missing] Decky Loader not found.
  Install it (Desktop Mode) from https://decky.xyz and reboot to Game Mode.
EOF
  fi
  if ! _has_decky_sunshine; then
    ok=1
    cat <<'EOF'
[missing] Decky Sunshine plugin not found.
  In Game Mode: Decky (plug icon) -> Store -> install "Sunshine".
EOF
  fi
  if [ "$ok" -ne 0 ]; then
    echo "Install the above, then re-run: svd install"
    return 1
  fi
  log "Prerequisites present (Decky Loader + Decky Sunshine)."
  return 0
}
