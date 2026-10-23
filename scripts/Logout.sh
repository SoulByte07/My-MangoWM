#!/usr/bin/env bash
# ==================================================
#  MangoWM - Logout / Session Exit Helper
# ==================================================

set -uo pipefail

# 1. Close wlogout if open
pkill -x wlogout 2>/dev/null || true

# 2. Stop user graphical session target
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop graphical-session.target >/dev/null 2>&1 || true
fi

# 3. Request MangoWM exit via IPC
if command -v mmsg >/dev/null 2>&1; then
    mmsg dispatch quit >/dev/null 2>&1 || true
fi

# Give compositor time to quit cleanly
for _ in {1..10}; do
    pgrep -u "$USER" -x mango >/dev/null 2>&1 || break
    sleep 0.1
done

# 4. If MangoWM process is still alive, terminate it
pkill -u "$USER" -TERM -x mango 2>/dev/null || true
sleep 0.2
if pgrep -u "$USER" -x mango >/dev/null 2>&1; then
    pkill -u "$USER" -KILL -x mango 2>/dev/null || true
fi

# 5. Terminate systemd logind session if present
if [ -n "${XDG_SESSION_ID:-}" ] && command -v loginctl >/dev/null 2>&1; then
    loginctl terminate-session "$XDG_SESSION_ID" >/dev/null 2>&1 || true
fi

exit 0
