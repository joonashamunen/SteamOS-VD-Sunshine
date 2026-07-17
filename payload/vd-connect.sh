#!/bin/sh
D=/root/.var/app/dev.lizardbyte.app.Sunshine/config
[ -n "$SUNSHINE_CLIENT_WIDTH" ] || exit 1
rm -f "$D/vd.ready"
echo "connect,${SUNSHINE_CLIENT_WIDTH},${SUNSHINE_CLIENT_HEIGHT},${SUNSHINE_CLIENT_FPS}" > "$D/trigger.fifo"
i=0
while [ "$i" -lt 25 ] && [ ! -f "$D/vd.ready" ]; do sleep 1; i=$((i+1)); done
