#!/usr/bin/env bash
# ==================================================
#  MangoWM - Hypridle / Idle Inhibitor Indicator
# ==================================================

PROCESS="hypridle"
SIGNAL_N=9
MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"

is_running() {
    pgrep -x "$PROCESS" >/dev/null 2>&1
}

poke_mangobar() {
    pkill -"RTMIN+$SIGNAL_N" -x mangobar 2>/dev/null || true
}

case "${1:-status}" in
    status)
        # When hypridle is running: normal timer active (caffeine off)
        # When hypridle is stopped: caffeine on (inhibited)
        if is_running; then
            echo "󰈈"
        else
            echo "󰅶"
        fi
        ;;

    toggle)
        if is_running; then
            pkill -x "$PROCESS" 2>/dev/null || true
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -a "Caffeine" -u low "Caffeine Mode ON" "Screen will stay awake indefinitely"
            fi
        else
            if [ -f "$MANGO_DIR/config/hypridle.conf" ]; then
                hypridle -q -c "$MANGO_DIR/config/hypridle.conf" >/dev/null 2>&1 &
            else
                hypridle -q >/dev/null 2>&1 &
            fi
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -a "Caffeine" -u low "Caffeine Mode OFF" "Normal idle timers restored"
            fi
        fi
        sleep 0.1
        poke_mangobar
        ;;

    lock)
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock -q -c "$MANGO_DIR/config/hyprlock.conf" >/dev/null 2>&1 &
        elif command -v loginctl >/dev/null 2>&1; then
            loginctl lock-session
        fi
        ;;

    *)
        echo "Usage: $0 {status|toggle|lock}"
        exit 1
        ;;
esac
