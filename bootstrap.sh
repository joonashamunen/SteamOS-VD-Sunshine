#!/bin/bash
set -euo pipefail
REPO="${SVD_REPO:-<you>/SteamOS-VD-Sunshine}"
REF="${SVD_REF:-main}"
DEST=/home/deck/.local/share/svd
BIN=/home/deck/.local/bin

echo "==> Downloading svd ($REPO@$REF)"
tmp="$(mktemp -d)"
curl -fsSL "https://github.com/$REPO/archive/$REF.tar.gz" -o "$tmp/svd.tar.gz"
mkdir -p "$DEST" "$BIN"
tar -xzf "$tmp/svd.tar.gz" -C "$tmp"
src="$(find "$tmp" -maxdepth 1 -type d -name 'SteamOS-VD-Sunshine-*')"
cp -a "$src/." "$DEST/"
ln -sf "$DEST/svd" "$BIN/svd"
chown -R deck:deck "$DEST" "$BIN"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "NOTE: add $BIN to PATH";; esac

echo "==> Running installer (sudo)"
sudo "$DEST/svd" install
