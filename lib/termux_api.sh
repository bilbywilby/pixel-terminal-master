#!/bin/sh
# Termux Hardware & Android API Interoperability Subroutine
# NOTE: on a plain Debian userland (no Termux), the command -v checks below
# simply fail and every function falls back to the log_* line — this is
# intentional, not a bug. Do not "fix" it into a hard requirement.
set -eu

acquire_wake_lock() {
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
        log_debug "Android wake-lock acquired."
    fi
}

release_wake_lock() {
    if command -v termux-wake-unlock >/dev/null 2>&1; then
        termux-wake-unlock
        log_debug "Android wake-lock released."
    fi
}

send_notification() {
    _title="$1"
    _message="$2"
    _priority="${3:-normal}"
    if command -v termux-notification >/dev/null 2>&1; then
        termux-notification \
            --title "$_title" \
            --content "$_message" \
            --priority "$_priority" \
            --id "termux_master_event"
    else
        log_info "Notification [$_title]: $_message"
    fi
}

check_battery_status() {
    if command -v termux-battery-status >/dev/null 2>&1; then
        termux-battery-status | jq -r '.percentage'
    else
        printf '100'
    fi
}
