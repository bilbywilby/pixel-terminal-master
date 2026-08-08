#!/bin/sh
# Unified Scheduler Backend Adapter (termux-job-scheduler / crond)
set -eu

detect_scheduler_backend() {
    if command -v termux-job-scheduler >/dev/null 2>&1; then
        printf 'termux-job-scheduler'
    elif command -v crontab >/dev/null 2>&1; then
        printf 'crond'
    else
        printf 'none'
    fi
}

schedule_job() {
    _job_id="$1"
    _cron_expr="$2"
    _script_path="$3"
    _backend=$(detect_scheduler_backend)
    log_info "Scheduling job '$_job_id' using backend: $_backend"

    case "$_backend" in
        termux-job-scheduler)
            case "$_cron_expr" in
                "*/15 * * * *") _period="15m" ;;
                "0 * * * *") _period="1h" ;;
                "0 0 * * *") _period="1d" ;;
                *)
                    log_warn "Complex cron expression detected. Falling back to crond setup."
                    _backend="crond"
                    ;;
            esac
            if [ "$_backend" = "termux-job-scheduler" ]; then
                termux-job-scheduler -s "$_script_path" --job-id "$_job_id" --period-ms 900000 --persisted true
                return 0
            fi
            ;;
    esac

    if [ "$_backend" = "crond" ]; then
        ( crontab -l 2>/dev/null | grep -v "$_job_id"; printf '%s %s # %s\n' "$_cron_expr" "$_script_path" "$_job_id" ) | crontab -
        log_info "Cron entry added to user crontab."
    else
        log_err "No functional scheduling daemon located on host."
        return 1
    fi
}
