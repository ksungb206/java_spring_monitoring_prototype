#!/usr/bin/env bash
set -euo pipefail
ACTION="${1:-}"; PROFILE="${2:-local}"
case "$ACTION" in start|stop|restart|status|logs|install|uninstall) ;; *) echo "Usage: spring:{start|stop|restart|status|logs|install|uninstall} {local|dev|stage|prod}" >&2; exit 2;; esac
case "$PROFILE" in local|dev|stage|prod) ;; *) echo "Invalid profile: $PROFILE" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env.${PROFILE}"
UNIT="main-api-${PROFILE}.service"
UNIT_PATH="/etc/systemd/system/${UNIT}"
WATCHDOG_UNIT="main-api-watchdog-${PROFILE}.service"
WATCHDOG_UNIT_PATH="/etc/systemd/system/${WATCHDOG_UNIT}"
if ! command -v systemctl >/dev/null || [[ "$(ps -p 1 -o comm= 2>/dev/null)" != systemd ]]; then
  echo 'ERROR: systemd is not PID 1. On WSL enable [boot] systemd=true in /etc/wsl.conf, then from Windows CMD run wsl --shutdown and reopen Ubuntu.' >&2
  exit 1
fi
JAVA=""
for dir in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/temurin-17-*; do
  if [[ -x "$dir/bin/java" ]]; then JAVA="$dir/bin/java"; break; fi
done
[[ -n "$JAVA" ]] || { echo 'ERROR: Java 17 missing. Install openjdk-17-jdk.' >&2; exit 1; }
JAR="$ROOT/run/$PROFILE/application.jar"
BUILD_DIR=""
BUILT_JAR=""
cleanup_build() { if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then rm -rf "$BUILD_DIR"; fi; }
trap cleanup_build EXIT
build_jar() {
  [[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found." >&2; return 1; }
  command -v mvn >/dev/null || { echo 'ERROR: Maven missing' >&2; return 1; }
  command -v tar >/dev/null || { echo 'ERROR: tar missing' >&2; return 1; }
  BUILD_DIR="$(mktemp -d)"
  echo "Building $PROFILE in isolated directory (tests included)..."
  # Never clean/overwrite a JAR used by a running systemd service.
  (cd "$ROOT" && tar --exclude='./.git' --exclude='./target' --exclude='./run' --exclude='./.env*' -cf - .) | (cd "$BUILD_DIR" && tar -xf -)
  (cd "$BUILD_DIR" && JAVA_HOME="$(dirname "$(dirname "$JAVA")")" PATH="$(dirname "$JAVA"):$PATH" mvn clean package)
  BUILT_JAR="$BUILD_DIR/target/main-api-spring-0.1.0.jar"
  [[ -s "$BUILT_JAR" ]] || { echo "ERROR: Built JAR missing: $BUILT_JAR" >&2; return 1; }
}
deploy_jar() {
  mkdir -p "$ROOT/run/$PROFILE"
  local staged="$ROOT/run/$PROFILE/.application.jar.new.$$"
  cp "$BUILT_JAR" "$staged"
  mv -f "$staged" "$JAR"
}
# Resolve the same PORT value that systemd loads from EnvironmentFile.
# Do not source .env files: they are environment files, not shell scripts.
health_port() {
  local value
  value="$(sed -nE 's/^[[:space:]]*PORT[[:space:]]*=[[:space:]]*(.*)$/\\1/p' "$ENV_FILE" | tail -n 1)"
  value="${value//[[:space:]]/}"
  value="${value:-7001}"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( 10#$value < 1 || 10#$value > 65535 )); then
    echo "ERROR: Invalid PORT in $ENV_FILE: $value" >&2
    return 1
  fi
  printf '%s' "$value"
}
wait_for_health() {
  command -v curl >/dev/null || { echo 'ERROR: curl missing; cannot check readiness.' >&2; return 1; }
  local port url attempt http_code
  port="$(health_port)" || return 1
  url="http://127.0.0.1:${port}/api/v1/health"
  echo "Waiting up to 30 seconds for $PROFILE health: $url"
  for ((attempt=1; attempt<=30; attempt++)); do
    if ! sudo systemctl is-active --quiet "$UNIT"; then
      echo "ERROR: $UNIT stopped before readiness." >&2
      sudo journalctl -u "$UNIT" -n 40 --no-pager >&2 || true
      return 1
    fi
    http_code="$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' --max-time 2 "$url" || true)"
    if [[ "$http_code" == 200 ]]; then
      echo "[OK] $PROFILE server ready (HTTP 200): $url"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: $PROFILE health did not return HTTP 200 within the readiness window: $url (last HTTP: $http_code)" >&2
  sudo journalctl -u "$UNIT" -n 40 --no-pager >&2 || true
  return 1
}
install_unit() {
  local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<EOF
[Unit]
Description=Main API Spring Boot ($PROFILE)
After=network.target
[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$ROOT
EnvironmentFile=$ENV_FILE
ExecStart=$JAVA -jar $JAR --spring.profiles.active=$PROFILE
Restart=on-failure
RestartSec=5
Environment=LOG_PROFILE=$PROFILE
Environment=SHUTDOWN_REASON_FILE=$ROOT/run/$PROFILE/shutdown-reason
ExecStartPre=/bin/bash $ROOT/scripts/service-start.sh $PROFILE
ExecStopPost=/bin/bash $ROOT/scripts/service-exit.sh $PROFILE
SuccessExitStatus=143
TimeoutStopSec=45
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF
  sudo install -m 644 "$tmp" "$UNIT_PATH"
  rm -f "$tmp"
  local watchdog_tmp; watchdog_tmp="$(mktemp)"
  cat > "$watchdog_tmp" <<EOF
[Unit]
Description=Independent MSA Monitoring Watchdog ($PROFILE)
After=network.target
[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$ROOT
EnvironmentFile=$ENV_FILE
Environment=LOG_PROFILE=$PROFILE
Environment=MONITORING_PROJECT_ROOT=$ROOT
ExecStart=/usr/bin/python3 $ROOT/scripts/monitoring-watchdog.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF
  # Retire previously installed independent watchdog; lifecycle email now belongs to Spring.
  sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
  sudo systemctl disable "$WATCHDOG_UNIT" >/dev/null 2>&1 || true
  sudo rm -f "$WATCHDOG_UNIT_PATH"
  # No independent watchdog unit installed.
  # sudo install -m 644 "$watchdog_tmp" "$WATCHDOG_UNIT_PATH"
  rm -f "$watchdog_tmp"
  sudo systemctl daemon-reload
  sudo systemctl disable "$UNIT" >/dev/null 2>&1 || true
  sudo systemctl disable "$WATCHDOG_UNIT" >/dev/null 2>&1 || true
  echo "Service installed: $UNIT (not enabled for boot auto-start)"
  echo "Independent watchdog removed; Spring lifecycle owns email alerts."
}
deployment_log() {
  mkdir -p "$ROOT/logs/$PROFILE/deployment"
  printf '%s profile=%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$PROFILE" "$*" >> "$ROOT/logs/$PROFILE/deployment/deployment-$(date '+%Y-%m-%d').log"
}
send_deploy_email() {
  local event="$1" detail="$2"
  if /usr/bin/python3 "$ROOT/scripts/deployment-email.py" "$PROFILE" "$event" "$detail"; then
    deployment_log "event=EMAIL_SENT type=$event"
  else
    deployment_log "event=EMAIL_FAILED type=$event"
    echo "WARNING: Could not send $event email for $PROFILE" >&2
  fi
}
build_with_notification() {
  if build_jar; then
    deployment_log "event=BUILD_SUCCEEDED"
    send_deploy_email BUILD_SUCCEEDED "Maven build and tests passed; deployment has not started."
  else
    local rc=$?
    deployment_log "event=BUILD_FAILED exit=$rc"
    send_deploy_email BUILD_FAILED "Maven build or tests failed (exit=$rc); existing service left untouched."
    return "$rc"
  fi
}
apply_build() {
  local was_active=false had_previous=false failure="" rollback="not_needed"
  local previous="$ROOT/run/$PROFILE/previous.jar"
  # Before any disruption, validate unit configuration and stage a recovery copy.
  if [[ ! -f "$UNIT_PATH" ]] || ! grep -Fq "WorkingDirectory=$ROOT" "$UNIT_PATH" || ! grep -Fq "ExecStart=$JAVA -jar $JAR " "$UNIT_PATH"; then
    if ! install_unit; then
      failure="unit_install_failed"
    fi
  fi
  mkdir -p "$ROOT/run/$PROFILE"
  if [[ -z "$failure" && -f "$JAR" ]]; then
    if cp "$JAR" "$previous"; then had_previous=true; else failure="backup_failed"; fi
  fi
  if [[ -z "$failure" ]] && sudo systemctl is-active --quiet "$UNIT" 2>/dev/null; then
    was_active=true
    printf 'MANUAL_RESTART\n' > "$ROOT/run/$PROFILE/shutdown-reason"
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_RESTART "requested_by=$(id -un)" || true
    if ! sudo systemctl stop "$UNIT"; then failure="stop_failed"; fi
  elif [[ -z "$failure" ]]; then
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_START "requested_by=$(id -un)" || true
  fi
  if [[ -z "$failure" ]]; then
    if ! deploy_jar; then failure="jar_install_failed"; fi
  fi
  if [[ -z "$failure" ]]; then
    if ! sudo systemctl start "$UNIT"; then failure="start_failed"
    elif ! wait_for_health; then failure="health_failed"; fi
  fi
  if [[ -z "$failure" ]]; then
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    deployment_log "event=DEPLOY_SUCCEEDED"
    send_deploy_email DEPLOY_SUCCEEDED "New JAR applied and health endpoint returned HTTP 200."
    sudo systemctl --no-pager status "$UNIT" || true
    return 0
  fi
  deployment_log "event=DEPLOY_FAILED reason=$failure"
  # If an earlier deployed JAR exists, restore it even when the new start failed.
  if [[ "$had_previous" == true ]]; then
    if sudo systemctl stop "$UNIT" && cp "$previous" "$JAR" && { [[ "$was_active" != true ]] || { sudo systemctl start "$UNIT" && wait_for_health; }; }; then
      rollback="succeeded"
    else
      rollback="failed"
    fi
  else
    rollback="unavailable_no_previous_jar"
  fi
  deployment_log "event=ROLLBACK result=$rollback"
  send_deploy_email DEPLOY_FAILED "Deployment failed ($failure); rollback=$rollback."
  return 1
}
case "$ACTION" in
  install)
    if sudo systemctl is-active --quiet "$UNIT" 2>/dev/null; then
      echo "ERROR: $UNIT is running; use restart to deploy a new build." >&2
      exit 1
    fi
    build_with_notification
    deploy_jar
    install_unit
    ;;
  start|restart)
    build_with_notification
    apply_build
    ;;
  stop)
    mkdir -p "$ROOT/run/$PROFILE"
    printf 'MANUAL_STOP\n' > "$ROOT/run/$PROFILE/shutdown-reason"
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_STOP "requested_by=$(id -un)"
    sudo systemctl stop "$UNIT"
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    ;;
  status) sudo systemctl --no-pager status "$UNIT";;
  logs) sudo journalctl -u "$UNIT" -f -n 100;;
  uninstall)
    sudo systemctl stop "$UNIT" 2>/dev/null || true
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    sudo systemctl disable "$UNIT" 2>/dev/null || true
    sudo systemctl disable "$WATCHDOG_UNIT" 2>/dev/null || true
    sudo rm -f "$UNIT_PATH" "$WATCHDOG_UNIT_PATH"
    sudo systemctl daemon-reload
    echo "Service and watchdog uninstalled: $UNIT, $WATCHDOG_UNIT"
    ;;
esac
