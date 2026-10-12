#!/usr/bin/env bash
# Run from an environment-specific checkout on the self-hosted deployment runner.
set -euo pipefail

PROFILE="${1:?Usage: deploy-branch.sh dev|stage|prod}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Invalid profile" >&2; exit 2;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f ".env.$PROFILE" ]] || { echo "Missing .env.$PROFILE in isolated checkout $ROOT" >&2; exit 1; }
command -v mvn >/dev/null
command -v git >/dev/null
command -v curl >/dev/null

UNIT="main-api-$PROFILE.service"
JAR="target/main-api-spring-0.1.0.jar"
case "$PROFILE" in dev) PORT=7002;; stage) PORT=7003;; prod) PORT=7004;; esac

RESTART_ATTEMPTED=false
LOG_DIR="$ROOT/logs/$PROFILE/deployment"
log_event() {
  mkdir -p "$LOG_DIR"
  printf '%s profile=%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$PROFILE" "$*" >> "$LOG_DIR/deployment-$(date '+%Y-%m-%d').log"
}
notify() {
  local event="$1" detail="$2"
  if python3 "$ROOT/scripts/deployment-email.py" "$PROFILE" "$event" "$detail"; then
    log_event "event=EMAIL_SENT type=$event"
  else
    log_event "event=EMAIL_FAILED type=$event"
    echo "WARNING: Email failed for $event" >&2
  fi
}
fail_deploy() {
  local reason="$1" rollback="not_needed" healthy=false
  log_event "event=DEPLOY_FAILED reason=$reason"
  if [[ "$RESTART_ATTEMPTED" == true ]]; then
    if [[ -s "$BACKUP/previous.jar" ]]; then
      if cp -p "$BACKUP/previous.jar" "$JAR" && sudo -n systemctl restart "$UNIT"; then
        for i in $(seq 1 30); do
          if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null; then healthy=true; break; fi
          sleep 2
        done
        if [[ "$healthy" == true ]]; then rollback="succeeded"; else rollback="failed_health"; fi
      else
        rollback="failed"
      fi
    else
      rollback="unavailable_no_previous_jar"
    fi
  fi
  log_event "event=ROLLBACK result=$rollback"
  notify DEPLOY_FAILED "Deployment failed ($reason); rollback=$rollback"
  return 1
}


# Each environment has its own checkout; never deploy from the feature workspace.
[[ "$(git branch --show-current)" == "$PROFILE" ]] || { echo "Expected checked-out branch $PROFILE in $ROOT" >&2; exit 1; }
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "Tracked changes present in $ROOT: abort" >&2; exit 1; }

git fetch --prune origin "$PROFILE"
# Only fast-forward, never rewrite deployment history.
git merge --ff-only "origin/$PROFILE"

mkdir -p target
BACKUP="$(mktemp -d)"
trap 'rm -rf "$BACKUP"' EXIT
if [[ -s "$JAR" ]]; then cp -p "$JAR" "$BACKUP/previous.jar"; fi

# Build and test before touching the running service.
if mvn -B clean package; then
  if [[ -s "$JAR" ]]; then
    log_event "event=BUILD_SUCCEEDED"
    notify BUILD_SUCCEEDED "Maven build and tests passed; deployment starting."
  else
    log_event "event=BUILD_FAILED reason=missing_jar"
    notify BUILD_FAILED "Expected JAR missing after Maven; existing service unchanged."
    if [[ -s "$BACKUP/previous.jar" ]]; then cp -p "$BACKUP/previous.jar" "$JAR"; fi
    exit 1
  fi
else
  rc=$?
  log_event "event=BUILD_FAILED exit=$rc"
  notify BUILD_FAILED "Maven build or tests failed (exit=$rc); existing service unchanged."
  if [[ -s "$BACKUP/previous.jar" ]]; then
    mkdir -p "$(dirname "$JAR")"
    cp -p "$BACKUP/previous.jar" "$JAR"
  fi
  exit "$rc"
fi
if ! sudo -n systemctl cat "$UNIT" >/dev/null; then
  fail_deploy "unit_not_found"
  exit 1
fi
if ! UNIT_ROOT="$(sudo -n systemctl show "$UNIT" -p WorkingDirectory --value)"; then
  fail_deploy "unit_inspection_failed"
  exit 1
fi
if [[ "$UNIT_ROOT" != "$ROOT" ]]; then
  echo "$UNIT WorkingDirectory mismatch: expected $ROOT, found $UNIT_ROOT." >&2
  fail_deploy "unit_working_directory_mismatch"
  exit 1
fi
echo "Restarting $UNIT"
RESTART_ATTEMPTED=true
if ! sudo -n systemctl restart "$UNIT"; then
  fail_deploy "service_restart_failed"
  exit 1
fi
healthy=false
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null; then healthy=true; break; fi
  sleep 2
done
if [[ "$healthy" != true ]]; then
  fail_deploy "health_check_failed"
  exit 1
fi
log_event "event=DEPLOY_SUCCEEDED"
notify DEPLOY_SUCCEEDED "New JAR deployed; health endpoint passed."
echo "Deployment successful: $PROFILE ($ROOT)"
