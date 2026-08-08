#!/bin/sh
# Core System Common Subroutines
set -eu

MASTER_STORAGE="${MASTER_STORAGE:-$HOME/.termux_master}"
MASTER_LOG_LEVEL="${MASTER_LOG_LEVEL:-info}"

log_msg() {
    _level="$1"; shift
    _timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf '[%s] [%s] %s\n' "$_timestamp" "$_level" "$*"
}
log_info()  { log_msg "INFO" "$@"; }
log_warn()  { log_msg "WARN" "$@" >&2; }
log_err()   { log_msg "ERROR" "$@" >&2; }
log_debug() { [ "$MASTER_LOG_LEVEL" = "debug" ] && log_msg "DEBUG" "$@" || true; }

ensure_directories() {
    for _dir in scripts envs schedules backups plugins bin dags logs state; do
        _target="$MASTER_STORAGE/$_dir"
        if [ ! -d "$_target" ]; then
            mkdir -p "$_target"
            chmod 700 "$_target"
        fi
    done
}

assert_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_err "Missing mandatory system dependency: $1"
        exit 127
    fi
}
