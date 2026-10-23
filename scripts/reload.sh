#!/usr/bin/env bash
# Unified reload for MangoWM and desktop components
set -uo pipefail

MANGO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mango"
exec bash "$MANGO_DIR/scripts/Refresh.sh" "$@"
