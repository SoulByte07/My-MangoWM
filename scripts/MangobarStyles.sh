#!/usr/bin/env bash
# ==================================================
#  MangoWM - Mangobar Theme Switcher
# ==================================================
# Script for mangobar themes & styles
# Similar to WaybarStyles.sh

IFS=$'\n\t'

# Define directories
MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"
mangobar_dir="${MANGO_DIR}/mangobar"
mangobar_themes="${mangobar_dir}/themes"
mangobar_config="${mangobar_dir}/config.jsonc"
mangobar_style="${mangobar_dir}/style.css"
SCRIPTSDIR="${MANGO_DIR}/scripts"
rofi_config="${MANGO_DIR}/rofi/config-mangobar-style.rasi"
[[ ! -f "$rofi_config" ]] && rofi_config="${MANGO_DIR}/rofi/config-waybar-style.rasi"
msg=' 🎨 NOTE: Select Mangobar Theme'

# Apply selected style
apply_style() {
    local theme="$1"
    local target_dir="${mangobar_themes}/${theme}"

    if [[ ! -d "${target_dir}" ]]; then
        echo "Error: Theme '${theme}' not found in ${mangobar_themes}" >&2
        return 1
    fi

    if [[ ! -f "${target_dir}/config.jsonc" ]] || [[ ! -f "${target_dir}/style.css" ]]; then
        echo "Error: Theme '${theme}' is missing config.jsonc or style.css" >&2
        return 1
    fi

    ln -sf "themes/${theme}/config.jsonc" "${mangobar_config}"
    ln -sf "themes/${theme}/style.css" "${mangobar_style}"
    echo "${theme}" > "${mangobar_dir}/.current_theme"

    # Refresh running bar cleanly
    "${SCRIPTSDIR}/Refresh.sh" &

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -i preferences-desktop-theme "Mangobar Theme" "Switched to '${theme}'"
    fi
}

main() {
    # resolve current theme
    current_name=""
    if [[ -f "${mangobar_dir}/.current_theme" ]]; then
        current_name=$(cat "${mangobar_dir}/.current_theme")
    elif [[ -L "${mangobar_style}" ]]; then
        current_target=$(readlink -f "${mangobar_style}")
        current_name=$(basename "$(dirname "${current_target}")")
    fi

    # gather all theme names into an array
    mapfile -t options < <(
        find -L "${mangobar_themes}" -mindepth 1 -maxdepth 1 -type d \
            -exec basename {} \; \
            | sort
    )

    # mark the active theme and record its index
    default_row=0
    MARKER="👉"
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$current_name" ]]; then
            options[i]="$MARKER ${options[i]}"
            default_row=$i
            break
        fi
    done

    # launch rofi with the annotated list and pre-selected row
    choice=$(printf '%s\n' "${options[@]}" \
        | rofi -i -dmenu \
               -config "$rofi_config" \
               -mesg "$msg" \
               -selected-row "$default_row"
    )

    [[ -z "$choice" ]] && { echo "No option selected. Exiting."; exit 0; }

    # remove annotation and apply
    choice=${choice#"$MARKER "}
    apply_style "$choice"
}

# Allow CLI arguments e.g. "MangobarStyles.sh set floating-capsule" or toggle
if [[ $# -gt 0 ]]; then
    case "$1" in
        set)
            [[ -n "${2:-}" ]] && apply_style "$2"
            exit 0
            ;;
        toggle)
            curr="classic"
            [[ -f "${mangobar_dir}/.current_theme" ]] && curr=$(cat "${mangobar_dir}/.current_theme")
            if [[ "$curr" == "floating-capsule" ]]; then
                apply_style "classic"
            else
                apply_style "floating-capsule"
            fi
            exit 0
            ;;
        list)
            find -L "${mangobar_themes}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
            exit 0
            ;;
    esac
fi

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

main
