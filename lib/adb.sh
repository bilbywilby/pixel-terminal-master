#!/bin/sh
# ADB Command & Broadcast Intent Router
set -eu

ADB_FILE="$MASTER_STORAGE/adb_codes"

ensure_adb_file() {
    if [ ! -f "$ADB_FILE" ]; then
        touch "$ADB_FILE"
        chmod 600 "$ADB_FILE"
    fi
}

adb_set_mapping() {
    _code="$1"
    _script_id="$2"
    ensure_adb_file
    _tmp="$ADB_FILE.tmp.$$"
    grep -v "^${_code}=" "$ADB_FILE" > "$_tmp" || true
    printf '%s=%s\n' "$_code" "$_script_id" >> "$_tmp"
    mv "$_tmp" "$ADB_FILE"
    chmod 600 "$ADB_FILE"
    log_info "Mapped ADB code '$_code' to script ID '$_script_id'"
}

adb_dispatch() {
    _code="$1"
    ensure_adb_file
    _target_script=$(grep "^${_code}=" "$ADB_FILE" | cut -d'=' -f2-)
    if [ -n "$_target_script" ]; then
        log_info "ADB Intent triggered code '$_code'. Executing target: $_target_script"
        master.sh run "$_target_script"
    else
        log_err "No mapping found for ADB intent code: $_code"
        return 1
    fi
}

adb_list() {
    ensure_adb_file
    if [ ! -s "$ADB_FILE" ]; then
        log_info "No ADB code mappings configured."
    else
        cat "$ADB_FILE"
    fi
}
