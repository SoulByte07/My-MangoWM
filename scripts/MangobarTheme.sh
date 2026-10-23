#!/usr/bin/env bash
# ==============================================================================
# Mangobar Theme Switcher
# Allows switching between themes in ~/.config/mango/mangobar/themes/
# ==============================================================================

set -euo pipefail

MANGO_DIR="${HOME}/.config/mango"
MANGOBAR_DIR="${MANGO_DIR}/mangobar"
THEMES_DIR="${MANGOBAR_DIR}/themes"
CURRENT_FILE="${MANGOBAR_DIR}/.current_theme"

get_current_theme() {
    if [[ -f "${CURRENT_FILE}" ]]; then
        cat "${CURRENT_FILE}"
    else
        echo "classic"
    fi
}

list_themes() {
    if [[ -d "${THEMES_DIR}" ]]; then
        find "${THEMES_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
    fi
}

apply_theme() {
    local theme="$1"
    local target_dir="${THEMES_DIR}/${theme}"

    if [[ ! -d "${target_dir}" ]]; then
        echo "Error: Theme '${theme}' does not exist in ${THEMES_DIR}" >&2
        return 1
    fi

    if [[ ! -f "${target_dir}/config.jsonc" ]] || [[ ! -f "${target_dir}/style.css" ]]; then
        echo "Error: Theme '${theme}' is missing config.jsonc or style.css" >&2
        return 1
    fi

    ln -sf "themes/${theme}/config.jsonc" "${MANGOBAR_DIR}/config.jsonc"
    ln -sf "themes/${theme}/style.css" "${MANGOBAR_DIR}/style.css"
    echo "${theme}" > "${CURRENT_FILE}"

    echo "Applied Mangobar theme: ${theme}"

    # Refresh running mangobar
    if [[ -x "${MANGO_DIR}/scripts/Refresh.sh" ]]; then
        bash "${MANGO_DIR}/scripts/Refresh.sh" --force-bar >/dev/null 2>&1 &
    else
        pkill -x mangobar 2>/dev/null || true
        ~/.local/bin/mangobar -c "${MANGOBAR_DIR}/config.jsonc" -s "${MANGOBAR_DIR}/style.css" >/dev/null 2>&1 &
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -i preferences-desktop-theme "Mangobar Theme" "Switched to '${theme}'"
    fi
}

toggle_theme() {
    local current
    current="$(get_current_theme)"
    if [[ "${current}" == "floating-capsule" ]]; then
        apply_theme "classic"
    else
        apply_theme "floating-capsule"
    fi
}

rofi_menu() {
    local themes
    themes="$(list_themes)"
    local current
    current="$(get_current_theme)"

    local selected
    selected="$(echo "${themes}" | rofi -dmenu -i -p "Mangobar Theme (Current: ${current})")" || exit 0

    if [[ -n "${selected}" ]]; then
        apply_theme "${selected}"
    fi
}

case "${1:-}" in
    set)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 set <theme-name>" >&2
            exit 1
        fi
        apply_theme "$2"
        ;;
    toggle)
        toggle_theme
        ;;
    current)
        get_current_theme
        ;;
    list)
        list_themes
        ;;
    menu)
        rofi_menu
        ;;
    *)
        echo "Usage: $0 {set <theme>|toggle|current|list|menu}"
        echo "Available themes:"
        list_themes
        exit 1
        ;;
esac
