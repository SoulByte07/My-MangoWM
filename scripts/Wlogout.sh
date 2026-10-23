#!/usr/bin/env bash
# ==================================================
#  MangoWM - Wlogout Power & Session Menu
# ==================================================

# Toggle: check if wlogout is already running
if pgrep -x "wlogout" >/dev/null 2>&1; then
    pkill -x "wlogout"
    exit 0
fi

LAYOUT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wlogout/layout"
STYLE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wlogout/style.css"

# Default dimensions for 1080p display
T_val=200
B_val=200

# Detect monitor resolution from monitor.conf
MON_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/mango/config/monitor.conf"
[[ ! -f "$MON_CONF" ]] && MON_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/mango/monitor.conf"
if [[ -f "$MON_CONF" ]]; then
    height=$(awk -F'[,:]' '/monitor_rule/{for(i=1;i<=NF;i++) if($i=="height") print $(i+1)}' "$MON_CONF" 2>/dev/null | head -n1 | tr -d ' ')
    if [[ -n "$height" && "$height" =~ ^[0-9]+$ ]]; then
        if (( height >= 2160 )); then
            T_val=600
            B_val=600
        elif (( height >= 1440 )); then
            T_val=400
            B_val=400
        else
            T_val=200
            B_val=200
        fi
    fi
fi

exec wlogout --protocol layer-shell -b 6 -c "$STYLE_FILE" -l "$LAYOUT_FILE" -T "$T_val" -B "$B_val"
