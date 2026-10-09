#!/usr/bin/env bash
set -eu
PROFILE="${1:-local}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/run/$PROFILE"
rm -f "$ROOT/run/$PROFILE/shutdown-reason"
exec /bin/bash "$ROOT/scripts/service-event.sh" "$PROFILE" SERVICE_START "systemd_start=true"
