#!/usr/bin/env bash
# ==================================================
#  MangoWM - Screen Locker
# ==================================================

set -euo pipefail

MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"

# 1. Close wlogout if open
pkill -x wlogout 2>/dev/null || true

# 2. Lock screen using installed locker
if command -v hyprlock >/dev/null 2>&1; then
    if ! pgrep -x hyprlock >/dev/null 2>&1; then
        hyprlock -q -c "$MANGO_DIR/config/hyprlock.conf" &
        disown
    fi
elif command -v swaylock >/dev/null 2>&1; then
    if ! pgrep -x swaylock >/dev/null 2>&1; then
        swaylock -f -c 161618 &
        disown
    fi
fi

# 3. Synchronize systemd logind state
if command -v loginctl >/dev/null 2>&1; then
    loginctl lock-session 2>/dev/null || true
fi
