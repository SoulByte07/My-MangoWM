#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Headless Toggle & Rofi Device Selector
# ==============================================================================
# - Headless toggle: starts/stops /usr/lib/kdeconnectd without KDE GUI
# - Uses $HOME/.config/mango/scripts/RofiLauncher.sh for wallpaper-aware Rofi menu
# - Allows quick pairing, pinging, and connecting to Android devices
# ==============================================================================

set -eo pipefail

ROFI_LAUNCHER="${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts/RofiLauncher.sh"
ICON="kdeconnect"

notify() {
    local urgency="${1:-normal}"
    local title="$2"
    local msg="$3"
    notify-send -u "$urgency" -a "KDE-Connect" -i "$ICON" "$title" "$msg" 2>/dev/null || true
}

# 1. If kdeconnectd is already running, toggle it OFF
if pgrep -x "kdeconnectd" > /dev/null 2>&1; then
    pkill -x "kdeconnectd" 2>/dev/null || true
    notify "normal" "KDE Connect" "Daemon stopped (Disconnected)"
    exit 0
fi

# 2. Start daemon headlessly in background
notify "low" "KDE Connect" "Starting daemon & scanning local network..."
/usr/lib/kdeconnectd > /dev/null 2>&1 &
disown

# Wait for local mDNS / UDP broadcast discovery
sleep 1.8

# 3. Query available devices
get_devices() {
    kdeconnect-cli -a 2>/dev/null | grep -E '^[[:space:]]*-' || true
}

RAW_DEVICES=$(get_devices)

if [ -z "$RAW_DEVICES" ]; then
    # Give it one more brief check if discovery took longer
    sleep 1.2
    RAW_DEVICES=$(get_devices)
fi

# Build Menu Options
MENU_ITEMS=""
if [ -n "$RAW_DEVICES" ]; then
    while IFS= read -r line; do
        # Format: - DeviceName: DeviceID (status)
        clean_line=$(echo "$line" | sed 's/^[[:space:]]*- //')
        MENU_ITEMS="${MENU_ITEMS}📱 ${clean_line}\n"
    done <<< "$RAW_DEVICES"
else
    MENU_ITEMS="⚠️ No devices found on local Wi-Fi\n🔄 Rescan network\n"
fi

MENU_ITEMS="${MENU_ITEMS}🛑 Stop Daemon (Disconnect)"

# 4. Launch Rofi via RofiLauncher.sh
if [ -x "$ROFI_LAUNCHER" ]; then
    SELECTED=$(echo -e "$MENU_ITEMS" | "$ROFI_LAUNCHER" -dmenu -i -p "📱 KDE Connect")
else
    SELECTED=$(echo -e "$MENU_ITEMS" | rofi -dmenu -i -p "📱 KDE Connect")
fi

# If user cancelled / pressed Esc
if [ -z "$SELECTED" ]; then
    exit 0
fi

# 5. Handle Action
case "$SELECTED" in
    *"Stop Daemon"*)
        pkill -x "kdeconnectd" 2>/dev/null || true
        notify "normal" "KDE Connect" "Daemon stopped (Disconnected)"
        exit 0
        ;;
    *"Rescan"*)
        exec "$0"
        ;;
    *"No devices found"*)
        notify "low" "KDE Connect" "Make sure your Android device is on the same Wi-Fi and KDE Connect app is open."
        exit 0
        ;;
    *)
        # Extract device ID from line: "📱 <Name>: <ID> (<status>)"
        # Device ID is the token after the first colon and before the status parentheses
        DEV_ID=$(echo "$SELECTED" | awk -F': ' '{print $2}' | awk '{print $1}')
        DEV_NAME=$(echo "$SELECTED" | sed -E 's/^📱 //' | awk -F': ' '{print $1}')

        if [ -n "$DEV_ID" ]; then
            notify "normal" "KDE Connect" "Connecting to ${DEV_NAME}..."
            kdeconnect-cli --pair -d "$DEV_ID" > /dev/null 2>&1 || true
            kdeconnect-cli --ping -d "$DEV_ID" > /dev/null 2>&1 || true
            notify "normal" "KDE Connect" "Connected & paired with ${DEV_NAME}!"
        else
            notify "critical" "KDE Connect" "Could not parse device ID."
        fi
        ;;
esac
