#!/usr/bin/env bash
# ==================================================
#  MangoWM - Static / Random Wallpaper Daemon (swaybg)
# ==================================================
set -uo pipefail

RANDOM_MODE=0
for arg in "$@"; do
    case "$arg" in
        -r|--random)
            RANDOM_MODE=1
            ;;
    esac
done

MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"
SCRIPTSDIR="$MANGO_DIR/scripts"
ROFI_DIR="$MANGO_DIR/rofi"
EFFECTS_DIR="$MANGO_DIR/wallpaper_effects"
WALLPAPER_CURRENT="$EFFECTS_DIR/.wallpaper_current"
WALLPAPER_BASE="$EFFECTS_DIR/.wallpaper_base"

mkdir -p "$EFFECTS_DIR" "$ROFI_DIR"

if ! command -v swaybg >/dev/null 2>&1; then
    printf "WallpaperDaemon: swaybg is not installed\n" >&2
    exit 1
fi


# Helper to check if file is a valid image
is_image() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local mime
    mime=$(file -b --mime-type "$file" 2>/dev/null || true)
    [[ "$mime" =~ ^image/ ]]
}

# Helper to resolve wallpaper path from candidate
resolve_wallpaper() {
    local candidate="$1"
    [[ -e "$candidate" ]] || return 1

    if [[ -L "$candidate" ]]; then
        local target
        target=$(readlink -f "$candidate" 2>/dev/null || true)
        if is_image "$target"; then
            printf '%s\n' "$target"
            return 0
        fi
    elif is_image "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

wallpaper_path=""

# 1. Random mode: pick a random image
if [[ "$RANDOM_MODE" -eq 1 ]]; then
    pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
    wallpaper_dir="$pictures_dir/wallpapers"
    if [[ -d "$wallpaper_dir" ]]; then
        mapfile -d "" candidates < <(find -L "$wallpaper_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 2>/dev/null)
        if [[ "${#candidates[@]}" -gt 0 ]]; then
            wallpaper_path="${candidates[$((RANDOM % ${#candidates[@]}))]}"
        fi
    fi
fi

# 2. Check current wallpaper state
if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(resolve_wallpaper "$WALLPAPER_CURRENT" 2>/dev/null || true)"
fi

# 3. Check base wallpaper state
if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(resolve_wallpaper "$WALLPAPER_BASE" 2>/dev/null || true)"
fi

# 4. Check rofi current wallpaper symlink
if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(resolve_wallpaper "$ROFI_DIR/.current_wallpaper" 2>/dev/null || true)"
fi

# 5. Fallback: random from Pictures/wallpapers
if [[ -z "$wallpaper_path" ]]; then
    pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
    wallpaper_dir="$pictures_dir/wallpapers"
    if [[ -d "$wallpaper_dir" ]]; then
        mapfile -d "" candidates < <(find -L "$wallpaper_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 2>/dev/null)
        if [[ "${#candidates[@]}" -gt 0 ]]; then
            wallpaper_path="${candidates[$((RANDOM % ${#candidates[@]}))]}"
        fi
    fi
fi

if [[ -n "$wallpaper_path" && -f "$wallpaper_path" ]]; then
    # 1. Update MangoWM state files
    if [[ "$wallpaper_path" != "$WALLPAPER_BASE" ]]; then
        cp -f "$wallpaper_path" "$WALLPAPER_BASE" 2>/dev/null || true
    fi
    if [[ "$wallpaper_path" != "$WALLPAPER_CURRENT" ]]; then
        cp -f "$wallpaper_path" "$WALLPAPER_CURRENT" 2>/dev/null || true
    fi

    # 2. Synchronize MangoWM Rofi wallpaper symlinks
    ln -sf "$WALLPAPER_CURRENT" "$ROFI_DIR/.current_wallpaper" 2>/dev/null || true
    ln -sf "$WALLPAPER_CURRENT" "$ROFI_DIR/.current_wallpaper_focused" 2>/dev/null || true

    if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/rofi" ]; then
        ln -sf "$WALLPAPER_CURRENT" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper" 2>/dev/null || true
    fi

    # 3. Apply wallpaper via swaybg
    old_pids=$(pgrep -x swaybg 2>/dev/null || true)
    swaybg -i "$WALLPAPER_CURRENT" -m fill >/dev/null 2>&1 &
    ( sleep 0.1 && if [[ -n "$old_pids" ]]; then kill $old_pids 2>/dev/null || true; fi ) &

    # 4. Run WallustSwww.sh asynchronously
    if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        bash "$SCRIPTSDIR/WallustSwww.sh" "$WALLPAPER_CURRENT" >/dev/null 2>&1 &
    fi
fi

exit 0
