#!/bin/bash
# lib/stack.sh — install flatpak, daemon, jeepney, systemd units, FIFO. Idempotent.

VD_DIR=/home/deck/sunshine_virt_display
APPCFG=/root/.var/app/dev.lizardbyte.app.Sunshine/config
VD_REF=v2.0.0   # upstream v2 daemon (socket /tmp/sunshineVD.sock); known-good on device
# Sunshine 2026.516.143833. Newer builds (2026.914) fail KMS capture of the
# virtual display ("Couldn't get drm fb for plane: Permission denied") -> black
# stream. Pin this commit and mask the app so flatpak auto-updates can't move it.
SUNSHINE_APP=dev.lizardbyte.app.Sunshine
SUNSHINE_COMMIT=62e90ef28d2c760d77e85233e1c5754c29f56e430b726947cdd79867915901e2
FIFO=$APPCFG/trigger.fifo

stack_apply() {
  local here="$1"
  require_root

  log "[1/6] Sunshine flatpak (root/system)"
  run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  if ! flatpak info "$SUNSHINE_APP" >/dev/null 2>&1; then
    run flatpak install -y flathub "$SUNSHINE_APP"
  fi
  if [ "$(flatpak info --show-commit "$SUNSHINE_APP" 2>/dev/null)" != "$SUNSHINE_COMMIT" ]; then
    log "  pinning Sunshine to known-good commit ${SUNSHINE_COMMIT:0:12}"
    run flatpak update -y --commit="$SUNSHINE_COMMIT" "$SUNSHINE_APP"
  fi
  flatpak mask 2>/dev/null | grep -qx "$SUNSHINE_APP" || run flatpak mask "$SUNSHINE_APP"
  run mkdir -p "$APPCFG"

  log "[2/6] sunshine_virt_display daemon"
  if [ ! -d "$VD_DIR/.git" ]; then
    run sudo -u deck git clone --branch "$VD_REF" --depth 1 https://github.com/frostplexx/sunshine_virt_display "$VD_DIR"
  fi

  log "[3/6] Vendor jeepney into $VD_DIR/deps"
  if ! PYTHONPATH="$VD_DIR/deps" python3 -c "import jeepney" 2>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "DRY-RUN would download+extract jeepney wheel into $VD_DIR/deps"
    else
      ( cd "$VD_DIR" || exit 1
        URL=$(curl -sL https://pypi.org/pypi/jeepney/json | python3 -c \
          "import sys,json;print([u['url'] for u in json.load(sys.stdin)['urls'] if u['filename'].endswith('.whl')][0])")
        curl -sLO "$URL"
        python3 -c "import zipfile,glob;zipfile.ZipFile(glob.glob('jeepney-*.whl')[0]).extractall('deps')"
        chown -R deck:deck "$VD_DIR" )
    fi
  fi

  log "[4/6] Deploy vdctl.sh + vd-watcher.sh + vd-daemon.py + sunshine-watchdog.sh"
  run install -m 0755 -o deck -g deck "$here/payload/vdctl.sh" "$VD_DIR/vdctl.sh"
  run install -m 0755 -o deck -g deck "$here/payload/vd-watcher.sh" "$VD_DIR/vd-watcher.sh"
  run install -m 0755 -o deck -g deck "$here/payload/vd-daemon.py" "$VD_DIR/vd-daemon.py"
  run install -m 0755 -o deck -g deck "$here/payload/sunshine-watchdog.sh" "$VD_DIR/sunshine-watchdog.sh"

  log "[5/6] systemd units + FIFO"
  [ -p "$FIFO" ] || run mkfifo -m 600 "$FIFO"
  _write_units
  log "[6/6] Enable services"
  run systemctl daemon-reload
  run systemctl enable sunshineVD vd-watcher svd-watchdog
  # restart, not just start: repair must pick up changed units/payload
  run systemctl restart sunshineVD vd-watcher svd-watchdog
}

_write_units() {
  if [ "$DRY_RUN" = "1" ]; then echo "DRY-RUN would write sunshineVD.service + vd-watcher.service + svd-watchdog.service"; return; fi
  cat > /etc/systemd/system/sunshineVD.service <<EOF
[Unit]
Description=Sunshine Virtual Display Daemon
After=display-manager.service dbus.service
Requires=dbus.service

[Service]
Type=simple
User=root
Group=root
Environment=PYTHONPATH=$VD_DIR/deps
Environment=PYTHONUNBUFFERED=1
# vd-daemon.py runs upstream's daemon with its DRM-master theft neutralised
# (gamescope aborts when its master is stolen); see payload/vd-daemon.py.
ExecStart=/usr/bin/python3 $VD_DIR/vd-daemon.py
Restart=always
RestartSec=3
TimeoutStopSec=10

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
  cat > /etc/systemd/system/svd-watchdog.service <<EOF
[Unit]
Description=Restart Sunshine via Decky when it crashes (svd)
After=plugin_loader.service

[Service]
Type=simple
ExecStart=$VD_DIR/sunshine-watchdog.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}
