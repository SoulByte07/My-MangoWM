#!/usr/bin/env bash
# ==================================================
#  MangoWM - Game Mode (Toggle Effects for Max Performance)
# ==================================================

GAMEMODE_FLAG="${XDG_CACHE_HOME:-$HOME/.cache}/mango_gamemode"
notif_icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
[ -f "$notif_icon" ] || notif_icon="preferences-desktop-display"

if [ -f "$GAMEMODE_FLAG" ]; then
    # Currently in GameMode -> Disable GameMode (Restore eye-candy)
    rm -f "$GAMEMODE_FLAG"
    if command -v mmsg >/dev/null 2>&1; then
        mmsg setoption animations 1 >/dev/null 2>&1 || true
        mmsg setoption shadows 1 >/dev/null 2>&1 || true
        mmsg setoption dim_enable 1 >/dev/null 2>&1 || true
    fi
    notify-send -e -u normal -i "$notif_icon" "MangoWM Game Mode" "Disabled: Animations & shadows restored"
else
    # Not in GameMode -> Enable GameMode (Zero latency, maximum FPS)
    touch "$GAMEMODE_FLAG"
    if command -v mmsg >/dev/null 2>&1; then
        mmsg setoption animations 0 >/dev/null 2>&1 || true
        mmsg setoption shadows 0 >/dev/null 2>&1 || true
        mmsg setoption blur 0 >/dev/null 2>&1 || true
        mmsg setoption dim_enable 0 >/dev/null 2>&1 || true
    fi
    notify-send -e -u low -i "$notif_icon" "MangoWM Game Mode" "Enabled: Animations & shadows paused"
fi

exit 0
