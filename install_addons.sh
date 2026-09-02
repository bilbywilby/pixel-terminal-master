#!/usr/bin/env bash
set -e
mkdir -p addons

cat << 'EOF' > addons/1_webhook.py
import http.server, socketserver, subprocess
local_port = 8080
class H(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        subprocess.Popen(["sh", "./master.sh"])
        self.send_response(200)
        self.end_headers()
socketserver.TCPServer(("", local_port), H).serve_forever()
EOF

# Fixed: termux-job-scheduler doesn't exist outside Termux. Detects the
# environment and uses cron on Debian/AVF, falls back to Termux's native
# scheduler when actually running inside Termux.
cat << 'EOF' > addons/2_scheduler.sh
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
EOF

# Fixed: termux-battery-status doesn't exist outside Termux. Falls back to
# /sys/class/power_supply on plain Linux; skips the gate (exit 0, don't
# block the pipeline) if no battery source can be found at all, since an
# AVF VM may have no exposed battery telemetry.
cat << 'EOF' > addons/3_resource_gate.sh
#!/usr/bin/env bash
set -e
MIN_BATTERY="${1:-20}"

get_battery_pct() {
    if command -v termux-battery-status >/dev/null 2>&1; then
        termux-battery-status | grep -oP '(?<="percentage": )\d+'
        return
    fi
    for supply in /sys/class/power_supply/*/capacity; do
        [ -f "$supply" ] && cat "$supply" && return
    done
    echo ""
}

battery_pct=$(get_battery_pct)

if [ -z "$battery_pct" ]; then
    echo "warn: no battery source found, skipping gate" >&2
    exit 0
fi

[ "$battery_pct" -lt "$MIN_BATTERY" ] && exit 1 || exit 0
EOF

cat << 'EOF' > addons/4_archiver.sh
#!/usr/bin/env bash
set -e
sqlite3 ~/.termux_master/state.db ".dump" | gzip > addons/state_backup_$(date +%s).sql.gz
EOF

# Fixed: falls back to pkg install -y with no error handling when pkg
# doesn't exist. Detects pkg vs apt-get vs apt and uses whichever is
# actually present.
cat << 'EOF' > addons/5_dep_injector.sh
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
EOF

cat << 'EOF' > addons/6_telemetry.sh
#!/usr/bin/env bash
set -e
curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"$1\"}" "$WEBHOOK_URL"
EOF

cat << 'EOF' > addons/7_tui_dashboard.py
import curses, sqlite3
def main(stdscr):
    stdscr.addstr(0, 0, "DAG State Monitor - Active")
    stdscr.refresh()
    stdscr.getkey()
curses.wrapper(main)
EOF

cat << 'EOF' > addons/8_log_rotator.sh
#!/usr/bin/env bash
set -e
find ~/.termux_master/logs/ -type f -mtime +7 -exec gzip {} \;
EOF

cat << 'EOF' > addons/9_network_presence.sh
#!/usr/bin/env bash
set -e
ip neigh show | grep -q "$1" && exit 0 || exit 1
EOF

# NOTE: StrictHostKeyChecking=no is kept per the original spec (must_have:
# "strict host key checking disabled"). This means an attacker who can
# intercept this connection (rogue AP, ARP spoofing on the same LAN) can
# swap the host key silently, with no warning shown. Fine for a trusted
# LAN-only router with a known static IP; risky on anything else. Swap in
# a pinned known_hosts entry instead of "no" if that risk isn't acceptable.
cat << 'EOF' > addons/10_wg_rotator.sh
#!/usr/bin/env bash
set -e
ssh -o StrictHostKeyChecking=no root@${2:-192.168.1.1} "/etc/init.d/network restart ${1:-wg0}"
EOF

chmod +x addons/*.sh addons/*.py
echo "Installed 10 addons into ./addons/ (2, 3, 5 refactored for Debian/AVF compatibility)"
