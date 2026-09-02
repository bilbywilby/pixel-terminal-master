#!/usr/bin/env bash
set -e
MIN_BATTERY="${1:-20}"

get_battery_pct() {
    if command -v termux-battery-status >/dev/null 2>&1; then
        termux-battery-status | grep -oP '(?<="percentage": )\d+'
        return
    fi
    for supply in /sys/class/power_supply/*/capacity; do
        [ -f "$supply" ] && cat "$supply" && return
    done
    echo ""
}

battery_pct=$(get_battery_pct)

if [ -z "$battery_pct" ]; then
    echo "warn: no battery source found, skipping gate" >&2
    exit 0
fi

[ "$battery_pct" -lt "$MIN_BATTERY" ] && exit 1 || exit 0
