#!/usr/bin/env bash
# ==================================================
#  MangoWM - Wallpaper Effects (ImageMagick + swaybg)
# ==================================================

set -uo pipefail

# Variables
wallpaper_output="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects/.wallpaper_modified"
wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects/.wallpaper_current"
wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallpaper_effects/.wallpaper_base"
wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi/.current_wallpaper"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts"
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi/config-wallpaper-effect.rasi"

# Ensure base wallpaper exists
if [[ ! -f "$wallpaper_base" && -f "$wallpaper_current" ]]; then
    mkdir -p "$(dirname "$wallpaper_base")"
    cp -f "$wallpaper_current" "$wallpaper_base" || true
fi

# Define ImageMagick effects
declare -A effects=(
    ["No Effects"]="no-effects"
    ["Black & White"]="magick $wallpaper_base -colorspace gray -sigmoidal-contrast 10,40% $wallpaper_output"
    ["Blurred"]="magick $wallpaper_base -blur 0x10 $wallpaper_output"
    ["Charcoal"]="magick $wallpaper_base -charcoal 0x5 $wallpaper_output"
    ["Edge Detect"]="magick $wallpaper_base -edge 1 $wallpaper_output"
    ["Emboss"]="magick $wallpaper_base -format '%[pixel:p{0,0}]' -write info:/tmp/orig_c.txt -emboss 0x5 -fill $(cat /tmp/orig_c.txt 2>/dev/null || echo '#808080') -colorize 50% $wallpaper_output"
    ["Negate"]="magick $wallpaper_base -negate $wallpaper_output"
    ["Oil Paint"]="magick $wallpaper_base -paint 4 $wallpaper_output"
    ["Posterize"]="magick $wallpaper_base -posterize 4 $wallpaper_output"
    ["Polaroid"]="magick $wallpaper_base -polaroid 0 $wallpaper_output"
    ["Sepia"]="magick $wallpaper_base -sepia-tone 80% $wallpaper_output"
    ["Solarize"]="magick $wallpaper_base -solarize 50% $wallpaper_output"
    ["Vignette"]="magick $wallpaper_base -vignette 0x5 $wallpaper_output"
    ["Zoomed"]="magick $wallpaper_base -gravity Center -crop 80%x80%+0+0 $wallpaper_output"
)

no-effects() {
    if [[ -f "$wallpaper_base" ]]; then
        pkill -x swaybg 2>/dev/null || true
        swaybg -i "$wallpaper_base" -m fill >/dev/null 2>&1 &
        cp -f "$wallpaper_base" "$wallpaper_current" 2>/dev/null || true
        ln -sf "$wallpaper_base" "$wallpaper_link" 2>/dev/null || true
        if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
            "$SCRIPTSDIR/WallustSwww.sh" "$wallpaper_base" >/dev/null 2>&1 || true
        fi
        notify-send -u low "Wallpaper Effects" "Original wallpaper restored"
    fi
}

main() {
    pkill -x rofi 2>/dev/null || true
    
    # Update rofi wallpaper link
    if [ -x "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" ]; then
        "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
    fi

    local choice
    choice=$(printf '%s\n' "${!effects[@]}" | sort | rofi -dmenu -i -config "$rofi_theme" -p "✨ Effects: ")

    if [[ -n "$choice" ]]; then
        if [[ "$choice" == "No Effects" ]]; then
            no-effects
        elif [[ -n "${effects[$choice]:-}" ]]; then
            notify-send -u low "Wallpaper Effects" "Applying $choice effect..."
            if eval "${effects[$choice]}"; then
                pkill -x swaybg 2>/dev/null || true
                swaybg -i "$wallpaper_output" -m fill >/dev/null 2>&1 &
                cp -f "$wallpaper_output" "$wallpaper_current" 2>/dev/null || true
                ln -sf "$wallpaper_output" "$wallpaper_link" 2>/dev/null || true
                if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
                    "$SCRIPTSDIR/WallustSwww.sh" "$wallpaper_output" >/dev/null 2>&1 || true
                fi
                notify-send -u low "Wallpaper Effects" "$choice effect applied"
            else
                notify-send -u critical "Wallpaper Effects" "Failed to apply $choice"
            fi
        fi
    fi
}

main
