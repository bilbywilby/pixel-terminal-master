#!/bin/bash
# OPSEC: Idle state detector for terminal sessions
# Usage: source idle_monitor.sh <timeout_minutes>

IDLE_TIMEOUT_MIN=${1:-60}  # Default: 5 minutes
IDLE_FILE="/tmp/pixel_terminal_idle_$$"
LAST_ACTIVITY_FILE="/tmp/pixel_terminal_last_activity_$$"

# Initialize activity timestamp
date +%s > "$LAST_ACTIVITY_FILE"

# Update activity on any input
trap 'date +%s > "$LAST_ACTIVITY_FILE"' DEBUG

# Idle check loop
idle_monitor_loop() {
    while true; do
        sleep 10
        local last_activity=$(cat "$LAST_ACTIVITY_FILE" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local idle_duration=$((current_time - last_activity))

        if [ "$idle_duration" -ge $((IDLE_TIMEOUT_MIN * 60)) ]; then
            echo "[!] Idle detected: $IDLE_TIMEOUT_MIN minutes of inactivity" >&2
            touch "$IDLE_FILE"
            # Trigger graceful shutdown via master.sh
            if [ -f "$HOME/pixel-terminal-master/master.sh" ]; then
                bash -c "source $HOME/pixel-terminal-master/lib/common.sh; shutdown_gracefully"
            fi
            break
        fi
    done
}

# Start the monitor in background
idle_monitor_loop &
IDLE_MONITOR_PID=$!
export IDLE_MONITOR_PID

# Cleanup on exit
cleanup_idle_monitor() {
    kill "$IDLE_MONITOR_PID" 2>/dev/null || true
    rm -f "$IDLE_FILE" "$LAST_ACTIVITY_FILE"
}
# trap cleanup_idle_monitor EXIT  # CHAINED BELOW
