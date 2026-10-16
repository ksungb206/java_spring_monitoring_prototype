#!/usr/bin/env bash
# Real systemd rollback drill, completely separate from main-api-dev.service.
# Run from repository root: bash scripts/test-systemd-rollback.sh
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT="main-api-rollback-test.service"
PORT=7012
TEST_ROOT=""
INSTALLED=false
JAVA="$(command -v java)"
JAR="$ROOT/run/dev/application.jar"
[[ -s "$JAR" ]] || { echo "DEV JAR missing: $JAR" >&2; exit 1; }
[[ -f "$ROOT/.env.dev" ]] || { echo "Missing .env.dev" >&2; exit 1; }
[[ "$(ps -p 1 -o comm= | xargs)" == systemd ]] || { echo "systemd must be PID 1" >&2; exit 1; }
for cmd in sudo systemctl curl flock sha256sum; do command -v "$cmd" >/dev/null; done
# Never replace or modify any existing unit, including a leftover from another run.
if sudo systemctl cat "$UNIT" >/dev/null 2>&1 || [[ -e "/etc/systemd/system/$UNIT" ]]; then
  echo "Refusing to overwrite existing $UNIT. Inspect/remove it manually." >&2
  exit 1
fi
exec 9>"$ROOT/run/dev/rollback-drill.lock"
flock -n 9 || { echo "Another rollback drill is running" >&2; exit 1; }
if curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
  echo "Port $PORT already serves an API; aborting." >&2; exit 1
fi
TEST_ROOT="$(mktemp -d "$HOME/main-api-rollback-drill.XXXXXXXX")"
chmod 700 "$TEST_ROOT"
UNIT_FILE="/etc/systemd/system/$UNIT"
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ "$INSTALLED" == true ]]; then
    sudo systemctl stop "$UNIT" >/dev/null 2>&1 || true
    sudo rm -f "$UNIT_FILE"
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    sudo systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
  fi
  [[ -z "$TEST_ROOT" ]] || rm -rf "$TEST_ROOT"
  echo "Cleanup complete: original DEV service/JAR untouched."
  exit "$rc"
}
trap cleanup EXIT
cp -p "$JAR" "$TEST_ROOT/application.jar"
cp -p "$JAR" "$TEST_ROOT/previous.jar"
ORIGINAL_SHA="$(sha256sum "$JAR" | awk '{print $1}')"
# Keep original env for Spring compatibility, but force isolated port and disable monitoring/email.
grep -vE '^[[:space:]]*(PORT|MONITORING_ENABLED|MONITORING_EMAIL_ENABLED|DEPLOY_EMAIL_ENABLED)[[:space:]]*=' "$ROOT/.env.dev" > "$TEST_ROOT/test.env" || true
cat >> "$TEST_ROOT/test.env" <<EOF
PORT=$PORT
MONITORING_ENABLED=false
MONITORING_EMAIL_ENABLED=false
DEPLOY_EMAIL_ENABLED=false
EOF
chmod 600 "$TEST_ROOT/test.env"
cat > "$TEST_ROOT/unit" <<EOF
[Unit]
Description=Isolated Spring Boot rollback drill (7012)
After=network.target
[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$TEST_ROOT
EnvironmentFile=$TEST_ROOT/test.env
ExecStart=$JAVA -jar $TEST_ROOT/application.jar --spring.profiles.active=dev
Restart=no
TimeoutStopSec=20
StandardOutput=journal
StandardError=journal
EOF
sudo install -m 644 "$TEST_ROOT/unit" "$UNIT_FILE"
INSTALLED=true
sudo systemctl daemon-reload
healthy() {
  local i
  for i in $(seq 1 30); do
    if curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}
install_jar() {
  local staged
  staged="$(mktemp "$TEST_ROOT/.application.XXXXXXXX")"
  cp -p "$1" "$staged"
  mv -f "$staged" "$TEST_ROOT/application.jar"
}
rollback() {
  sudo systemctl stop "$UNIT" >/dev/null 2>&1 || true
  install_jar "$TEST_ROOT/previous.jar"
  sudo systemctl start "$UNIT"
  healthy
  [[ "$(sha256sum "$TEST_ROOT/application.jar" | awk '{print $1}')" == "$ORIGINAL_SHA" ]]
}
echo "[1/3] Starting isolated real Spring Boot service on $PORT"
sudo systemctl start "$UNIT"
healthy || { echo "Baseline failed: inspect sudo journalctl -u $UNIT -n 60" >&2; exit 1; }
echo "[PASS] Baseline: HTTP health 200 on $PORT"
echo "[2/3] Injecting invalid JAR and testing real restart failure"
printf 'invalid jar - intentionally injected\n' > "$TEST_ROOT/bad.jar"
sudo systemctl stop "$UNIT"
install_jar "$TEST_ROOT/bad.jar"
sudo systemctl start "$UNIT" || true
sleep 2
if sudo systemctl is-active --quiet "$UNIT"; then
  echo "[FAIL] Invalid JAR unexpectedly active" >&2; exit 1
fi
rollback || { echo "[FAIL] Rollback after startup failure" >&2; exit 1; }
echo "[PASS] Startup failure -> previous JAR restored -> HTTP 200"
echo "[3/3] Injecting health failure with a valid JAR on the wrong port"
# A healthy Java process on 7013 must NOT satisfy the required 7012 readiness check.
sudo systemctl stop "$UNIT"
sed -i "s/^PORT=$PORT$/PORT=7013/" "$TEST_ROOT/test.env"
sudo systemctl start "$UNIT"
# 7012 should not return HTTP 200; do not wait 30 seconds for an intentional failure.
sleep 5
if curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
  echo "[FAIL] Expected health failure on $PORT" >&2; exit 1
fi
sudo systemctl stop "$UNIT"
sed -i "s/^PORT=7013$/PORT=$PORT/" "$TEST_ROOT/test.env"
rollback || { echo "[FAIL] Rollback after health failure" >&2; exit 1; }
echo "[PASS] Health failure -> previous JAR restored -> HTTP 200"
[[ "$(sha256sum "$JAR" | awk '{print $1}')" == "$ORIGINAL_SHA" ]] || { echo "[FAIL] DEV JAR changed" >&2; exit 1; }
sudo systemctl is-active --quiet main-api-dev.service || { echo "[FAIL] DEV service not active" >&2; exit 1; }
echo "[PASS] DEV JAR hash unchanged and DEV service active"
echo "Result: real systemd drill passed (isolated service, port $PORT)"
