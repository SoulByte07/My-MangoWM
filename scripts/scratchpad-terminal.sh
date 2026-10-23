#!/usr/bin/env bash
# ==============================================================================
#  MangoWM - Scratchpad Dropdown Terminal Launcher
#  Location: ~/.config/mango/scripts/scratchpad-terminal.sh
# ==============================================================================

APP_ID="foot-dropterm"

# Check if foot-dropterm is currently running
if pgrep -f "foot.*--app-id=${APP_ID}" >/dev/null 2>&1; then
    # Terminal exists, toggle the special workspace / scratchpad view
    mmsg dispatch toggle_special_tag 2>/dev/null || true
else
    # Launch foot terminal
    foot --app-id="${APP_ID}" &
    
    # Wait for the client window to appear and tag it directly to the special tag
    for _ in {1..30}; do
        sleep 0.05
        # Tag the active window to special tag if it matches our app-id
        if mmsg get focusing-client 2>/dev/null | grep -q "${APP_ID}"; then
            mmsg dispatch tag_special_tag 2>/dev/null || true
            break
        fi
    done
fi
