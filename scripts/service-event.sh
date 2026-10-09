#!/usr/bin/env bash
# Event writer intentionally lives outside JVM to survive SIGKILL and crashes.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-local}"; EVENT="${2:-UNKNOWN}"; DETAIL="${3:-}"
case "$PROFILE" in local|dev|stage|prod) ;; *) exit 2;; esac
case "$EVENT" in MANUAL_START|MANUAL_STOP|MANUAL_RESTART|SERVICE_START|SERVICE_STOPPED|SERVICE_FAILED|WATCHDOG_FAILED) ;; *) exit 2;; esac
DIR="$ROOT/logs/$PROFILE"
mkdir -p "$DIR/lifecycle" "$DIR/error" || exit 1
case "$EVENT" in SERVICE_FAILED|WATCHDOG_FAILED) LEVEL=ERROR;; *) LEVEL=INFO;; esac
STAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"
DATE="$(date '+%Y-%m-%d')"
# Key-value lines; DETAIL is produced by trusted scripts/systemd, not client input.
LINE="timestamp=$STAMP level=$LEVEL service=main-api profile=$PROFILE event=$EVENT ${DETAIL}"
printf '%s\n' "$LINE" >> "$DIR/lifecycle/lifecycle-$DATE.log" || exit 1
if [[ "$LEVEL" == ERROR ]]; then
  printf '%s\n' "$LINE" >> "$DIR/error/error-$DATE.log" || exit 1
fi
printf '%s\n' "$LINE"
