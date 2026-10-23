#!/usr/bin/env bash
# ==================================================
#  MangoWM - Unified Refresh Script
# ==================================================

set -uo pipefail

# 1. Base directories strictly in ~/.config/mango
MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"
SCRIPTSDIR="$MANGO_DIR/scripts"
ROFI_DIR="$MANGO_DIR/rofi"
EFFECTS_DIR="$MANGO_DIR/wallpaper_effects"

# 2. Close active rofi menus
pkill -x rofi 2>/dev/null || true

# 3. Synchronize Rofi wallpaper symlinks inside ~/.config/mango/rofi
if [[ -f "$EFFECTS_DIR/.wallpaper_current" ]]; then
    mkdir -p "$ROFI_DIR"
    ln -sf "$EFFECTS_DIR/.wallpaper_current" "$ROFI_DIR/.current_wallpaper" 2>/dev/null || true
    ln -sf "$EFFECTS_DIR/.wallpaper_current" "$ROFI_DIR/.current_wallpaper_focused" 2>/dev/null || true
fi

# 4. Reload Dunst notifications
if command -v dunstctl >/dev/null 2>&1 && pgrep -x dunst >/dev/null 2>&1; then
    dunstctl reload >/dev/null 2>&1 || true
fi

# 5. Restart Mangobar cleanly
pkill -x mangobar 2>/dev/null || true
mangobar -c "$MANGO_DIR/mangobar/config.jsonc" -s "$MANGO_DIR/mangobar/style.css" >/dev/null 2>&1 &

# 6. Ensure MANGO_INSTANCE_SIGNATURE is set for IPC & reload compositor config
if [[ -z "${MANGO_INSTANCE_SIGNATURE:-}" || ! -S "${MANGO_INSTANCE_SIGNATURE:-}" ]]; then
    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for sock in "$runtime_dir"/mango-*.sock; do
        if [[ -S "$sock" ]]; then
            export MANGO_INSTANCE_SIGNATURE="$sock"
            break
        fi
    done
fi

if command -v mmsg >/dev/null 2>&1; then
    mmsg dispatch reload_config >/dev/null 2>&1 || true
fi

exit 0
