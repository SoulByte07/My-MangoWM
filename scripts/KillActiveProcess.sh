#!/usr/bin/env bash
# ==================================================
#  MangoWM - Kill Active Window Script
# ==================================================

# Primary method: MangoWM IPC socket dispatch
if command -v mmsg >/dev/null 2>&1; then
    if mmsg dispatch killclient >/dev/null 2>&1; then
        exit 0
    fi
fi

notify-send -u low -i "${XDG_CONFIG_HOME:-$HOME/.config}/dunst/images/error.png" "Kill Active Window" "No active window found to close."
exit 1
