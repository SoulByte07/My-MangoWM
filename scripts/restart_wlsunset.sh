#!/usr/bin/env bash
set +e

pkill -x wlsunset 2>/dev/null || true
nohup wlsunset -s 18:00 -S 06:00 -T 6500 -t 3500 >/dev/null 2>&1 &
