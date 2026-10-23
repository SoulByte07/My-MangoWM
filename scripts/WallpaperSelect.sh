#!/usr/bin/env bash
# ==================================================
#  MangoWM - Wallpaper Selector & Palette Generator
# ==================================================

set -uo pipefail

# Directory paths
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[ -n "$PICTURES_DIR" ] || PICTURES_DIR="$HOME/Pictures"
wallDIR="$PICTURES_DIR/wallpapers"

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi"
EFFECTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects"
ROFI_THEME="$ROFI_DIR/config-wallpaper.rasi"

mkdir -p "$EFFECTS_DIR" "$ROFI_DIR"

wallpaper_current="$EFFECTS_DIR/.wallpaper_current"
wallpaper_base="$EFFECTS_DIR/.wallpaper_base"
wallpaper_link="$ROFI_DIR/.current_wallpaper"
wallpaper_link_focused="$ROFI_DIR/.current_wallpaper_focused"

# Retrieve all wallpaper images
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \) -print0 2>/dev/null)

if [[ "${#PICS[@]}" -eq 0 ]]; then
  notify-send -u low "Wallpaper Selector" "No images found in $wallDIR"
  exit 1
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"

# Build menu choices
menu_entries=()
menu_entries+=("🎲 Random\0icon\x1f$RANDOM_PIC")

for pic in "${PICS[@]}"; do
    filename="$(basename "$pic")"
    menu_entries+=("$filename\0icon\x1f$pic")
done

# Launch Rofi menu
chosen_name=$(printf '%b\n' "${menu_entries[@]}" | rofi -dmenu -i -config "$ROFI_THEME" -p "🖼️ Wallpaper: ")

if [[ -z "$chosen_name" ]]; then
    exit 0
fi

if [[ "$chosen_name" == *"Random"* ]]; then
    chosen_path="$RANDOM_PIC"
else
    chosen_path=""
    for pic in "${PICS[@]}"; do
        if [[ "$(basename "$pic")" == "$chosen_name" ]]; then
            chosen_path="$pic"
            break
        fi
    done
fi

if [[ -z "$chosen_path" || ! -f "$chosen_path" ]]; then
    exit 1
fi

# 1. Apply wallpaper via swaybg
if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg 2>/dev/null || true
    swaybg -i "$chosen_path" -m fill >/dev/null 2>&1 &
fi

# 2. Update MangoWM state files and symlinks
cp -f "$chosen_path" "$wallpaper_current" 2>/dev/null || true
cp -f "$chosen_path" "$wallpaper_base" 2>/dev/null || true
ln -sf "$chosen_path" "$wallpaper_link" 2>/dev/null || true
ln -sf "$chosen_path" "$wallpaper_link_focused" 2>/dev/null || true

# Also sync global rofi link if folder exists
if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/rofi" ]; then
    ln -sf "$chosen_path" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper" 2>/dev/null || true
fi

# 3. Generate color palette via WallustSwww.sh
if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
    bash "$SCRIPTSDIR/WallustSwww.sh" "$chosen_path" >/dev/null 2>&1 &
fi

notify-send -u low -i "$chosen_path" "Wallpaper Applied" "$(basename "$chosen_path")"
exit 0
