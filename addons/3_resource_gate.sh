#!/bin/bash
# Enhanced Resource Gate v2.0 - OPSEC Sanitized
MIN_BATTERY=20
MAX_LOAD=2.0

battery_pct=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 100)
if [ "$battery_pct" -lt "$MIN_BATTERY" ]; then
    echo "[-] Gate Closed: Battery too low ($battery_pct%)"
    exit 1
fi

load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
if (( $(echo "$load_avg > $MAX_LOAD" | bc -l) )); then
    echo "[-] Gate Closed: CPU Load too high ($load_avg)"
    exit 1
fi
echo "[+] Resource Gate Passed."
exit 0
