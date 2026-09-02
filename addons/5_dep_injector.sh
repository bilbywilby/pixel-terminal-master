#!/usr/bin/env bash
set -e
BIN="$1"
[ -z "$BIN" ] && { echo "usage: $0 <binary>" >&2; exit 1; }

command -v "$BIN" >/dev/null 2>&1 && exit 0

if command -v pkg >/dev/null 2>&1; then
    pkg install -y "$BIN"
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y "$BIN"
elif command -v apt >/dev/null 2>&1; then
    sudo apt install -y "$BIN"
else
    echo "error: no supported package manager found (pkg/apt-get/apt)" >&2
    exit 1
fi
