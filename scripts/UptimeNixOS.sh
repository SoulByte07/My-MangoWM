#!/usr/bin/env bash
# ==================================================
#  MangoWM - Uptime Helper for Hyprlock
# ==================================================
if [[ -r /proc/uptime ]]; then
    s=$(< /proc/uptime)
    s=${s/.*}
else
    echo "up $(uptime -p 2>/dev/null || echo 'unknown')"
    exit 0
fi

d="$((s / 60 / 60 / 24)) days"
h="$((s / 60 / 60 % 24)) hours"
m="$((s / 60 % 60)) minutes"

((${d/ *} == 1)) && d=${d/s}
((${h/ *} == 1)) && h=${h/s}
((${m/ *} == 1)) && m=${m/s}

((${d/ *} == 0)) && unset d
((${h/ *} == 0)) && unset h
((${m/ *} == 0)) && unset m

uptime=${d:+$d, }${h:+$h, }$m
uptime=${uptime%', '}
uptime=${uptime:-$s seconds}

echo "up $uptime"
