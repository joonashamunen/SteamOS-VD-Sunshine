#!/bin/bash
FIFO=/root/.var/app/dev.lizardbyte.app.Sunshine/config/trigger.fifo
VD=/home/deck/sunshine_virt_display/vdctl.sh
READY=/root/.var/app/dev.lizardbyte.app.Sunshine/config/vd.ready
while true; do
  if read -r line < "$FIFO"; then
    IFS=',' read -r cmd w h fps <<< "$line"
    case "$cmd" in
      connect)
        [[ "$w$h$fps" =~ ^[0-9]+$ ]] && {
          "$VD" --connect --width "$w" --height "$h" --refresh-rate "$fps"
          touch "$READY"
        } ;;
      disconnect) "$VD" --disconnect ;;
    esac
  fi
done
