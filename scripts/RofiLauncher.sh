#!/usr/bin/env bash
# ==================================================
#  MangoWM - Rofi Application Launcher
# ==================================================

if pidof rofi >/dev/null 2>&1; then
  pkill -x rofi 2>/dev/null || pkill rofi 2>/dev/null || true
  exit 0
fi

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts"
ROFI_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi/config.rasi"

if [ -x "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" ]; then
  "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
fi

if [ "$#" -gt 0 ]; then
  exec rofi "$@" -config "$ROFI_CONF"
else
  exec rofi -show drun -modi drun,filebrowser,run,window -config "$ROFI_CONF"
fi
