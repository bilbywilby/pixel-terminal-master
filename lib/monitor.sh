#!/bin/sh
# Process Supervisor & Watchdog Daemon
set -eu

MONITOR_DIR="$MASTER_STORAGE/schedules/monitors"

ensure_monitor_dir() {
    if [ ! -d "$MONITOR_DIR" ]; then
        mkdir -p "$MONITOR_DIR"
        chmod 700 "$MONITOR_DIR"
    fi
}

monitor_start() {
    _script_id="$1"
    _max_retries="${2:-5}"
    ensure_monitor_dir
    _pid_file="$MONITOR_DIR/${_script_id}.pid"
    _log_file="$MONITOR_DIR/${_script_id}.log"

    if [ -f "$_pid_file" ]; then
        _old_pid=$(cat "$_pid_file")
        if kill -0 "$_old_pid" 2>/dev/null; then
            log_warn "Monitor process already active for ID '$_script_id' (PID: $_old_pid)"
            return 0
        fi
    fi

    log_info "Starting watchdog process for script: $_script_id"
    nohup sh -c "
        retry_count=0
        while [ \$retry_count -lt $_max_retries ]; do
            log_info 'Watchdog spawning execution of $_script_id'
            if master.sh run '$_script_id' >> '$_log_file' 2>&1; then
                retry_count=0
            else
                retry_count=\$((retry_count + 1))
                log_err 'Script $_script_id failed. Retrying (\${retry_count}/$_max_retries)...'
                sleep \$((retry_count * 5))
            fi
        done
        log_err 'Max retries reached for $_script_id. Terminating supervisor.'
        rm -f '$_pid_file'
    " >/dev/null 2>&1 &
    _new_pid=$!
    printf '%s' "$_new_pid" > "$_pid_file"
    log_info "Supervisor running for '$_script_id' under PID: $_new_pid"
}

monitor_stop() {
    _script_id="$1"
    _pid_file="$MONITOR_DIR/${_script_id}.pid"
    if [ -f "$_pid_file" ]; then
        _pid=$(cat "$_pid_file")
        if kill "$_pid" 2>/dev/null; then
            log_info "Terminated supervisor process PID: $_pid"
        fi
        rm -f "$_pid_file"
    else
        log_warn "No active supervisor found for ID: $_script_id"
    fi
}

monitor_status() {
    _script_id="$1"
    _pid_file="$MONITOR_DIR/${_script_id}.pid"
    if [ -f "$_pid_file" ] && kill -0 "$(cat "$_pid_file")" 2>/dev/null; then
        printf 'RUNNING (PID: %s)\n' "$(cat "$_pid_file")"
    else
        printf 'STOPPED\n'
    fi
}
