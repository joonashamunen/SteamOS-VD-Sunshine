#!/bin/bash
# install-virtual-display-stack.sh
# Recreates the working SteamOS Game Mode streaming virtual-display setup:
#   root Sunshine flatpak -> sunshine_virt_display daemon -> FIFO bridge ->
#   watcher -> gamescope udev pokes -> readiness handshake.
# Scope: ONLY the streaming/virtual-display stack. No VirtualHere/SSH/WoL.
#
# PREREQUISITES (manual, done first):
#   - Decky Loader installed, Decky Sunshine plugin installed from its store
#   - sudo password set for user 'deck'
# Run: sudo ./install-virtual-display-stack.sh
# Idempotent: safe to re-run (also serves as post-update repair).

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }

VD_DIR=/home/deck/sunshine_virt_display
APPCFG=/root/.var/app/dev.lizardbyte.app.Sunshine/config
FIFO=$APPCFG/trigger.fifo

echo "==> [1/8] Sunshine flatpak (root/system — required for KMS capture in Game Mode)"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak info dev.lizardbyte.app.Sunshine >/dev/null 2>&1 \
  || flatpak install -y flathub dev.lizardbyte.app.Sunshine
mkdir -p "$APPCFG"

echo "==> [2/8] sunshine_virt_display daemon (v2, main branch)"
if [ ! -d "$VD_DIR/.git" ]; then
  sudo -u deck git clone https://github.com/frostplexx/sunshine_virt_display "$VD_DIR"
fi
# NOTE: do NOT run the repo's install.sh — it targets /opt (read-only on SteamOS).

echo "==> [3/8] Vendor jeepney into $VD_DIR/deps (no pip on SteamOS)"
if ! PYTHONPATH="$VD_DIR/deps" python3 -c "import jeepney" 2>/dev/null; then
  cd "$VD_DIR"
  URL=$(curl -sL https://pypi.org/pypi/jeepney/json | python3 -c \
    "import sys,json;print([u['url'] for u in json.load(sys.stdin)['urls'] if u['filename'].endswith('.whl')][0])")
  curl -sLO "$URL"
  python3 -c "import zipfile,glob;zipfile.ZipFile(glob.glob('jeepney-*.whl')[0]).extractall('deps')"
  chown -R deck:deck "$VD_DIR"
fi

echo "==> [4/8] sunshineVD.service"
cat > /etc/systemd/system/sunshineVD.service <<EOF
[Unit]
Description=Sunshine Virtual Display Daemon
After=network.target

[Service]
Type=simple
Environment=PYTHONPATH=$VD_DIR/deps
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 $VD_DIR/main.py
Restart=on-failure
RestartSec=3
TimeoutStopSec=15

[Install]
WantedBy=multi-user.target
EOF

echo "==> [5/8] vdctl.sh (daemon socket client + gamescope hotplug pokes)"
# SteamOS-specific: gamescope never notices the daemon's DRM changes without
# udev 'change' events. Five pokes over ~10s cover slow/stale-cleanup connects.
cat > "$VD_DIR/vdctl.sh" <<'EOF'
#!/bin/bash
python3 - "$@" <<'PYEOF'
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect('/tmp/sunshineVD.sock')
s.send((','.join(sys.argv[1:]) + '\n').encode())
PYEOF
for i in 1 2 3 4 5; do
  sleep 2
  udevadm trigger --subsystem-match=drm --action=change
done
EOF
chmod +x "$VD_DIR/vdctl.sh"; chown deck:deck "$VD_DIR/vdctl.sh"

echo "==> [6/8] FIFO bridge + vd-watcher (sandbox -> host, with vd.ready handshake)"
[ -p "$FIFO" ] || mkfifo -m 600 "$FIFO"
cat > "$VD_DIR/vd-watcher.sh" <<EOF
#!/bin/bash
FIFO=$FIFO
VD=$VD_DIR/vdctl.sh
READY=$APPCFG/vd.ready
while true; do
  if read -r line < "\$FIFO"; then
    IFS=',' read -r cmd w h fps <<< "\$line"
    case "\$cmd" in
      connect)
        [[ "\$w\$h\$fps" =~ ^[0-9]+\$ ]] && {
          "\$VD" --connect --width "\$w" --height "\$h" --refresh-rate "\$fps"
          touch "\$READY"
        } ;;
      disconnect) "\$VD" --disconnect ;;
    esac
  fi
done
EOF
chmod +x "$VD_DIR/vd-watcher.sh"; chown deck:deck "$VD_DIR/vd-watcher.sh"

cat > /etc/systemd/system/vd-watcher.service <<EOF
[Unit]
Description=Virtual Display Watcher (Sunshine FIFO trigger)
After=sunshineVD.service
Wants=sunshineVD.service

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'test -p $FIFO || mkfifo -m 600 $FIFO'
ExecStart=$VD_DIR/vd-watcher.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "==> [7/8] vd-connect.sh (Sunshine do-command; reads env vars, blocks until display ready)"
# No arguments, no sh -c: Sunshine mangles inline shell (\$((...)) etc) and does
# not expand \${VARS} without a shell — but it DOES export them to the environment.
cat > "$APPCFG/vd-connect.sh" <<EOF
#!/bin/sh
D=$APPCFG
[ -n "\$SUNSHINE_CLIENT_WIDTH" ] || exit 1
rm -f "\$D/vd.ready"
echo "connect,\${SUNSHINE_CLIENT_WIDTH},\${SUNSHINE_CLIENT_HEIGHT},\${SUNSHINE_CLIENT_FPS}" > "\$D/trigger.fifo"
i=0
while [ "\$i" -lt 25 ] && [ ! -f "\$D/vd.ready" ]; do sleep 1; i=\$((i+1)); done
EOF
chmod +x "$APPCFG/vd-connect.sh"

echo "==> [8/8] Enable services"
systemctl daemon-reload
systemctl enable --now sunshineVD vd-watcher
systemctl --no-pager --quiet is-active sunshineVD && echo "  sunshineVD: active"
systemctl --no-pager --quiet is-active vd-watcher && echo "  vd-watcher: active"

cat <<'DONE'

============================================================
Install complete. MANUAL STEPS remaining (one-time):

1. Game Mode -> Decky -> Sunshine plugin -> toggle ON
   (it will detect the root flatpak installed by this script)

2. Sunshine Web UI (https://127.0.0.1:47990, credentials via the
   plugin's "Show credentials") -> Configuration -> General ->
   Command Preparations, add:

   Do:
     sh /root/.var/app/dev.lizardbyte.app.Sunshine/config/vd-connect.sh
   Undo:
     sh -c "echo disconnect > /root/.var/app/dev.lizardbyte.app.Sunshine/config/trigger.fifo"

3. Pair Moonlight (PIN via the plugin's PIN field).

VERIFY a good connect in sunshine.log:
  - 'Executing Do Cmd' -> 'CLIENT CONNECTED' gap of ~5-15s
    (~1s = handshake broken; full 25s = display chain broken)
  - 'Found connector ID' = the VIRTUAL connector (DP), not your monitor's
  - Moonlight stats show the client's own resolution

RECOVERY (black/stuck display):
  sudo systemctl stop sunshineVD        # daemon cleans up on stop
  echo disconnect | sudo tee /root/.var/app/dev.lizardbyte.app.Sunshine/config/trigger.fifo
  sudo udevadm trigger --subsystem-match=drm --action=change
  ...or reboot (always restores the physical display).
============================================================
DONE
