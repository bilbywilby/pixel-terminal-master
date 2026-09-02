#!/usr/bin/env bash
set -e
ssh -o StrictHostKeyChecking=no root@${2:-192.168.1.1} "/etc/init.d/network restart ${1:-wg0}"
