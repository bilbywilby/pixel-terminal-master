#!/usr/bin/env bash
set -e
ip neigh show | grep -q "$1" && exit 0 || exit 1
