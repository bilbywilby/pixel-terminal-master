#!/usr/bin/env bash
set -e
PERIOD_MS="${1:-86400000}"
PERIOD_MIN=$(( PERIOD_MS / 60000 ))
[ "$PERIOD_MIN" -lt 1 ] && PERIOD_MIN=1

if command -v termux-job-scheduler >/dev/null 2>&1; then
    termux-job-scheduler --script "$PWD/master.sh" --period-ms "$PERIOD_MS"
    exit 0
fi

if command -v crontab >/dev/null 2>&1; then
    CRON_LINE="*/${PERIOD_MIN} * * * * cd $PWD && ./master.sh >> $PWD/addons/scheduler.log 2>&1"
    ( crontab -l 2>/dev/null | grep -vF "$PWD/master.sh" ; echo "$CRON_LINE" ) | crontab -
    echo "Registered cron job: every ${PERIOD_MIN} min via crontab"
    exit 0
fi

echo "error: neither termux-job-scheduler nor crontab found" >&2
exit 1
