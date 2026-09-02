#!/usr/bin/env bash
set -e
curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"$1\"}" "$WEBHOOK_URL"
