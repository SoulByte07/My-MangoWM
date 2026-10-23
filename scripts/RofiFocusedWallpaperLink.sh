#!/usr/bin/env bash
# ==================================================
#  MangoWM - Rofi Focused Wallpaper Link Helper
# ==================================================

set -uo pipefail

MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"
ROFI_DIR="$MANGO_DIR/rofi"
EFFECTS_DIR="$MANGO_DIR/wallpaper_effects"
WALLPAPER_CURRENT="$EFFECTS_DIR/.wallpaper_current"

mkdir -p "$ROFI_DIR"

if [[ -f "$WALLPAPER_CURRENT" ]]; then
    target=$(readlink -f "$WALLPAPER_CURRENT" 2>/dev/null || echo "$WALLPAPER_CURRENT")
    ln -sf "$target" "$ROFI_DIR/.current_wallpaper" 2>/dev/null || true
    ln -sf "$target" "$ROFI_DIR/.current_wallpaper_focused" 2>/dev/null || true
fi

exit 0
