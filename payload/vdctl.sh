#!/bin/bash
python3 - "$@" <<'PYEOF'
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect('/tmp/sunshineVD.sock')
s.send((','.join(sys.argv[1:]) + '\n').encode())
PYEOF
for _ in 1 2 3 4 5; do
  sleep 2
  udevadm trigger --subsystem-match=drm --action=change
done
