#!/usr/bin/env bash
# ==================================================
#  MangoWM - Wallust Color Generator Wrapper
# ==================================================

set -uo pipefail

wallpaper="${1:-}"
EFFECTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi"

if [ -z "$wallpaper" ] && [ -f "$EFFECTS_DIR/.wallpaper_current" ]; then
    wallpaper="$EFFECTS_DIR/.wallpaper_current"
fi

if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
    exit 0
fi

# Load MangoWM Wallust arguments
if [ -f "$SCRIPTSDIR/WallustConfig.sh" ]; then
    # shellcheck source=/dev/null
    . "$SCRIPTSDIR/WallustConfig.sh"
fi

if command -v wallust >/dev/null 2>&1; then
    if [ "${#wallust_args[@]}" -gt 0 ]; then
        wallust "${wallust_args[@]}" run -s -q "$wallpaper" >/dev/null 2>&1 || true
    else
        wallust run -s -q "$wallpaper" >/dev/null 2>&1 || true
    fi
    # Keep theme colors synced
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mango/mangobar/wallust/colors-waybar.css" ]]; then
        cp -f "${XDG_CONFIG_HOME:-$HOME/.config}/mango/mangobar/wallust/colors-waybar.css" "${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallust/colors-waybar.css" 2>/dev/null || true
    fi
fi

# Refresh UI components (Mangobar, Rofi links, etc.)
if [ -x "$SCRIPTSDIR/Refresh.sh" ]; then
    bash "$SCRIPTSDIR/Refresh.sh" >/dev/null 2>&1 &
fi

exit 0
