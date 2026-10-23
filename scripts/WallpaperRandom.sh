#!/usr/bin/env bash
# ==================================================
#  MangoWM - Random Wallpaper Setter
# ==================================================

set -uo pipefail

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi"
EFFECTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects"

mkdir -p "$EFFECTS_DIR" "$ROFI_DIR"

mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \) -print0 2>/dev/null)

if [[ "${#PICS[@]}" -eq 0 ]]; then
  notify-send -u low "Random Wallpaper" "No images found in $wallDIR"
  exit 1
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"

# 1. Apply wallpaper via swaybg
if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg 2>/dev/null || true
    swaybg -i "$RANDOM_PIC" -m fill >/dev/null 2>&1 &
fi

# 2. Update MangoWM state files and symlinks
cp -f "$RANDOM_PIC" "$EFFECTS_DIR/.wallpaper_current" 2>/dev/null || true
cp -f "$RANDOM_PIC" "$EFFECTS_DIR/.wallpaper_base" 2>/dev/null || true

ln -sf "$RANDOM_PIC" "$ROFI_DIR/.current_wallpaper" 2>/dev/null || true
ln -sf "$RANDOM_PIC" "$ROFI_DIR/.current_wallpaper_focused" 2>/dev/null || true

if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/rofi" ]; then
    ln -sf "$RANDOM_PIC" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper" 2>/dev/null || true
fi

# 3. Generate color palette via WallustSwww.sh
if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
    bash "$SCRIPTSDIR/WallustSwww.sh" "$RANDOM_PIC" >/dev/null 2>&1 &
fi

notify-send -u low -i "$RANDOM_PIC" "Random Wallpaper Applied" "$(basename "$RANDOM_PIC")"
exit 0
