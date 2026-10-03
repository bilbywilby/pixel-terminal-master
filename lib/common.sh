#!/bin/bash
# Global Utilities for Pixel Terminal

shutdown_gracefully() {
    echo "[!] Initiating graceful shutdown sequence..."
    # Kill background monitors
    if [ -n "${IDLE_MONITOR_PID:-}" ]; then
        kill "$IDLE_MONITOR_PID" 2>/dev/null || true
    fi
    echo "[+] Resource gates released. System offline."
    exit 0
}
