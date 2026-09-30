#!/bin/bash
# gamescope-composite.sh on|off — force gamescope to composite while streaming.
#
# With the cursor hidden (gamepad input) gamescope switches to direct scanout:
# the game's buffer goes straight to the display hardware, which applies the
# colour conversion. Sunshine's KMS capture reads that raw buffer, so the stream
# comes out over-saturated (and, for smaller buffers, squeezed/garbled). Game
# Mode ignores --force-composition and gamescopectl; the GAMESCOPE_COMPOSITE_FORCE
# root-window atom on its XWayland display (:0) works. Same approach as newer
# Decky Sunshine builds. vd-watcher turns it on per stream and off afterwards.

XPROP="${SVD_XPROP:-xprop}"
case "${1:-}" in
  on) value=1 ;;
  off) value=0 ;;
  *) echo "usage: gamescope-composite.sh on|off" >&2; exit 2 ;;
esac

args=(-root -f GAMESCOPE_COMPOSITE_FORCE 32c -set GAMESCOPE_COMPOSITE_FORCE "$value")
if [ "$(id -u)" -eq 0 ]; then
  # The X display belongs to the session user; root can't talk to it directly.
  runuser -u deck -- env DISPLAY=:0 "$XPROP" "${args[@]}"
else
  DISPLAY=:0 "$XPROP" "${args[@]}"
fi
