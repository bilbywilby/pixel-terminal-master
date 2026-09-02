#!/usr/bin/env bash
set -e
sqlite3 ~/.termux_master/state.db ".dump" | gzip > addons/state_backup_$(date +%s).sql.gz
