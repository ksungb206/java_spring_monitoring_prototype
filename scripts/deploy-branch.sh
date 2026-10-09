#!/usr/bin/env bash
# Run as the dedicated deployment user on its own self-hosted runner.
set -euo pipefail
PROFILE="${1:?Usage: deploy-branch.sh dev|stage|prod}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Invalid profile" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f ".env.$PROFILE" ]] || { echo "Missing .env.$PROFILE" >&2; exit 1; }
command -v mvn >/dev/null
command -v git >/dev/null
command -v curl >/dev/null
UNIT="main-api-$PROFILE.service"
JAR="target/main-api-spring-0.1.0.jar"
case "$PROFILE" in dev) PORT=7002;; stage) PORT=7003;; prod) PORT=7004;; esac
# Refuse to overwrite local tracked changes.
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "Tracked changes present: abort" >&2; exit 1; }
[[ "$(git branch --show-current)" == "$PROFILE" ]] || { echo "Expected checked-out branch $PROFILE" >&2; exit 1; }
git fetch --prune origin "$PROFILE"
# Only fast-forward, never rewrite deployment history.
git merge --ff-only "origin/$PROFILE"
mkdir -p target
BACKUP="$(mktemp -d)"
trap 'rm -rf "$BACKUP"' EXIT
if [[ -f "$JAR" ]]; then cp -p "$JAR" "$BACKUP/previous.jar"; fi
# Build and test before touching the running service.
mvn -B clean package
[[ -s "$JAR" ]] || { echo "Missing built JAR" >&2; exit 1; }
# The systemd unit must already be installed and its sudo permission provisioned.
sudo -n systemctl cat "$UNIT" >/dev/null
echo "Restarting $UNIT"
sudo -n systemctl restart "$UNIT"
healthy=false
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null; then healthy=true; break; fi
  sleep 2
done
if [[ "$healthy" != true ]]; then
  echo "Health check failed; restoring previous JAR" >&2
  if [[ -s "$BACKUP/previous.jar" ]]; then
    cp -p "$BACKUP/previous.jar" "$JAR"
    sudo -n systemctl restart "$UNIT" || true
  else
    echo "No previous JAR available; manual recovery required" >&2
  fi
  exit 1
fi
echo "Deployment successful: $PROFILE"
