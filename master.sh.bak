#!/bin/sh
# Termux Master Scripts Main CLI Core
set -eu
MASTER_STORAGE="${MASTER_STORAGE:-$HOME/.termux_master}"
export MASTER_STORAGE

# Load Libraries
. "$MASTER_STORAGE/lib/common.sh"
. "$MASTER_STORAGE/lib/crypto.sh"
. "$MASTER_STORAGE/lib/scheduler.sh"
. "$MASTER_STORAGE/lib/dto.sh"
. "$MASTER_STORAGE/lib/config.sh"
. "$MASTER_STORAGE/lib/termux_api.sh"
. "$MASTER_STORAGE/lib/monitor.sh"
. "$MASTER_STORAGE/lib/adb.sh"
. "$MASTER_STORAGE/lib/plugin.sh"

ensure_directories
load_plugins

VERSION="0.2.0"

usage() {
    cat << EOF
Termux Master CLI Engine v${VERSION}

Usage: master.sh <command> [options]
Commands:
  setup                              Initialize storage & structure
  version                            Print version
  import <file.json>                 Import a Script DTO
  run <script_id>                    Execute an imported script DTO
  list                                List imported DAG script IDs
  env set <key> <val> [1|0]          Set environment variable (1=encrypt)
  schedule add <id> <cron> <script>  Schedule execution
  backup create [out.tar.gz]         Snapshot framework state
  config get|set <key> [val]         Read/write config.ini
  monitor start|stop|status <id>     Manage watchdog supervisors
  adb set|run|list <code> [script]   ADB intent code mapping
  plugins list                       List loaded plugins
EOF
    exit 0
}

main() {
    [ $# -eq 0 ] && usage
    _cmd="$1"; shift

    case "$_cmd" in
        setup)
            ensure_directories
            log_info "System configuration active at $MASTER_STORAGE"
            ;;
        version)
            printf 'termux-master-ultra %s\n' "$VERSION"
            ;;
        import)
            [ $# -lt 1 ] && { log_err "Import requires JSON DTO path"; exit 1; }
            import_script_dto "$1"
            ;;
        run)
            [ $# -lt 1 ] && { log_err "Run command requires script ID"; exit 1; }
            _dag_id="$1"
            _script_target="$MASTER_STORAGE/scripts/${_dag_id}.json"
            if [ ! -f "$_script_target" ]; then
                log_err "Script ID '$_dag_id' not found."
                exit 1
            fi
            _exec_cmd=$(jq -r '.command' "$_script_target")

            _exec_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
            _log_path="$MASTER_STORAGE/logs/${_dag_id}_${_exec_id}.log"

            _run_id=$(python3 "$MASTER_STORAGE/bin/state.py" record-start "$_dag_id")
            log_info "Executing '$_dag_id' (run_id=$_run_id): $_exec_cmd"
            log_info "Output log: $_log_path"

            # Guarded with if/else, not a bare command, so `set -e` doesn't
            # kill the script on a nonzero exit before we can record it.
            # Wrapped in a subshell ( ) so that if _exec_cmd itself contains
            # a literal `exit N`, it only terminates the subshell — not this
            # master.sh process, which would otherwise skip every line below.
            if ( eval "$_exec_cmd" ) > "$_log_path" 2>&1; then
                _exit_code=0
                _status="success"
            else
                _exit_code=$?
                _status="failed"
            fi

            if [ "$_status" = "success" ]; then
                python3 "$MASTER_STORAGE/bin/state.py" record-finish "$_run_id" success
            else
                python3 "$MASTER_STORAGE/bin/state.py" record-finish "$_run_id" failed "exit code $_exit_code"
            fi

            log_info "Run '$_dag_id' finished: status=$_status exit_code=$_exit_code"
            # Surface the captured output to the caller — CLI users still see
            # it, dashboard-triggered runs (stdout/stderr sent to DEVNULL by
            # the caller) just lose the live echo but keep the log file.
            cat "$_log_path"
            exit "$_exit_code"
            ;;
        list)
            if [ -d "$MASTER_STORAGE/scripts" ]; then
                for _f in "$MASTER_STORAGE"/scripts/*.json; do
                    [ -f "$_f" ] || continue
                    basename "$_f" .json
                done
            fi
            ;;
        env)
            _subcmd="${1:-}"
            if [ "$_subcmd" = "set" ]; then
                _key="$2"
                _val="$3"
                _encrypt="${4:-0}"
                if [ "$_encrypt" = "1" ]; then
                    _val=$(encrypt_value "$_val")
                    printf '%s=ENC:%s\n' "$_key" "$_val" >> "$MASTER_STORAGE/envs/global.env"
                else
                    printf '%s=%s\n' "$_key" "$_val" >> "$MASTER_STORAGE/envs/global.env"
                fi
                chmod 600 "$MASTER_STORAGE/envs/global.env"
            fi
            ;;
        schedule)
            _subcmd="${1:-}"
            if [ "$_subcmd" = "add" ]; then
                _job_id="$2"
                _cron="$3"
                _script_id="$4"
                schedule_job "$_job_id" "$_cron" "$MASTER_STORAGE/scripts/${_script_id}.json"
            fi
            ;;
        backup)
            _out="${1:-$HOME/master-backup-$(date +%s).tar.gz}"
            tar -czf "$_out" -C "$MASTER_STORAGE" . --exclude="./.env_key"
            log_info "Backup archive created at $_out"
            ;;
        config)
            _subcmd="${1:-}"; shift
            if [ "$_subcmd" = "get" ]; then
                config_get "$1"
                echo ""
            elif [ "$_subcmd" = "set" ]; then
                config_set "$1" "$2"
                log_info "Config updated: $1=$2"
            fi
            ;;
        monitor)
            _subcmd="${1:-}"; shift
            case "$_subcmd" in
                start) monitor_start "$1" "${2:-5}" ;;
                stop) monitor_stop "$1" ;;
                status) monitor_status "$1" ;;
                *) log_err "Unknown monitor subcommand: $_subcmd" ;;
            esac
            ;;
        adb)
            _subcmd="${1:-}"; shift
            case "$_subcmd" in
                set) adb_set_mapping "$1" "$2" ;;
                run) adb_dispatch "$1" ;;
                list) adb_list ;;
                *) log_err "Unknown adb subcommand: $_subcmd" ;;
            esac
            ;;
        plugins)
            _subcmd="${1:-list}"
            if [ "$_subcmd" = "list" ]; then
                list_plugins
            fi
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
