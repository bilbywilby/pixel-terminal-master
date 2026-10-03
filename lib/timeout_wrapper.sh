#!/bin/bash
# Usage: timeout_wrapper.sh <seconds> <command>
TIMEOUT=$1
shift
CMD="$@"
if ! command -v timeout &> /dev/null; then
    echo "[-] Error: 'timeout' utility not found."
    exit 1
fi
timeout "$TIMEOUT" bash -c "$CMD"
