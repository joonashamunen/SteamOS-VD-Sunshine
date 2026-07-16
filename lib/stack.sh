#!/bin/bash
# lib/stack.sh — install flatpak, daemon, jeepney, systemd units, FIFO. Idempotent.

VD_DIR=/home/deck/sunshine_virt_display
APPCFG=/root/.var/app/dev.lizardbyte.app.Sunshine/config
FIFO=$APPCFG/trigger.fifo

stack_apply() {
  local here="$1"
  require_root

  log "[1/6] Sunshine flatpak (root/system)"
  run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  if ! flatpak info dev.lizardbyte.app.Sunshine >/dev/null 2>&1; then
    run flatpak install -y flathub dev.lizardbyte.app.Sunshine
  fi
  run mkdir -p "$APPCFG"

  log "[2/6] sunshine_virt_display daemon"
  if [ ! -d "$VD_DIR/.git" ]; then
    run sudo -u deck git clone https://github.com/frostplexx/sunshine_virt_display "$VD_DIR"
  fi

  log "[3/6] Vendor jeepney into $VD_DIR/deps"
  if ! PYTHONPATH="$VD_DIR/deps" python3 -c "import jeepney" 2>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "DRY-RUN would download+extract jeepney wheel into $VD_DIR/deps"
    else
      ( cd "$VD_DIR"
        URL=$(curl -sL https://pypi.org/pypi/jeepney/json | python3 -c \
          "import sys,json;print([u['url'] for u in json.load(sys.stdin)['urls'] if u['filename'].endswith('.whl')][0])")
        curl -sLO "$URL"
        python3 -c "import zipfile,glob;zipfile.ZipFile(glob.glob('jeepney-*.whl')[0]).extractall('deps')"
        chown -R deck:deck "$VD_DIR" )
    fi
  fi

  log "[4/6] Deploy vdctl.sh + vd-watcher.sh"
  run install -m 0755 -o deck -g deck "$here/payload/vdctl.sh" "$VD_DIR/vdctl.sh"
  run install -m 0755 -o deck -g deck "$here/payload/vd-watcher.sh" "$VD_DIR/vd-watcher.sh"

  log "[5/6] systemd units + FIFO"
  [ -p "$FIFO" ] || run mkfifo -m 600 "$FIFO"
  _write_units
  log "[6/6] Enable services"
  run systemctl daemon-reload
  run systemctl enable --now sunshineVD vd-watcher
}

_write_units() {
  if [ "$DRY_RUN" = "1" ]; then echo "DRY-RUN would write sunshineVD.service + vd-watcher.service"; return; fi
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
}
