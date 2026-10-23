#!/usr/bin/env bash
# ==================================================
#  MangoWM - Battery Helper for Hyprlock
# ==================================================
for i in {0..3}; do
  if [ -f /sys/class/power_supply/BAT$i/capacity ]; then
    battery_level=$(cat /sys/class/power_supply/BAT$i/status 2>/dev/null || echo "Unknown")
    battery_capacity=$(cat /sys/class/power_supply/BAT$i/capacity 2>/dev/null || echo "0")
    echo "Battery: $battery_capacity% ($battery_level)"
  fi
done
