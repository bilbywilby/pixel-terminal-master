#!/usr/bin/env bash
set -e
find ~/.termux_master/logs/ -type f -mtime +7 -exec gzip {} \;
