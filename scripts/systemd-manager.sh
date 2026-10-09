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
JAR="$ROOT/target/main-api-spring-0.1.0.jar"
install_unit() {
  [[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found. Edit or create .env.${PROFILE} with your settings." >&2; exit 1; }
  command -v mvn >/dev/null || { echo 'ERROR: Maven missing' >&2; exit 1; }
  echo "Building $PROFILE (tests included)..."
  (cd "$ROOT" && JAVA_HOME="$(dirname "$(dirname "$JAVA")")" PATH="$(dirname "$JAVA"):$PATH" mvn clean package)
  [[ -f "$JAR" ]] || { echo "ERROR: Built JAR missing: $JAR" >&2; exit 1; }
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
case "$ACTION" in
  install) install_unit;;
  start)
    if [[ ! -f "$UNIT_PATH" ]] || ! grep -Fq "WorkingDirectory=$ROOT" "$UNIT_PATH" || [[ ! -f "$JAR" ]]; then install_unit; fi
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_START "requested_by=$(id -un)"
    sudo systemctl start "$UNIT"
    sudo systemctl --no-pager status "$UNIT" || true
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    ;;
  stop)
    mkdir -p "$ROOT/run/$PROFILE"
    printf 'MANUAL_STOP\n' > "$ROOT/run/$PROFILE/shutdown-reason"
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_STOP "requested_by=$(id -un)"
    sudo systemctl stop "$UNIT"
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    ;;
  restart)
    if [[ ! -f "$UNIT_PATH" ]] || ! grep -Fq "WorkingDirectory=$ROOT" "$UNIT_PATH" || [[ ! -f "$JAR" ]]; then install_unit; fi
    mkdir -p "$ROOT/run/$PROFILE"
    printf 'MANUAL_RESTART\n' > "$ROOT/run/$PROFILE/shutdown-reason"
    bash "$ROOT/scripts/service-event.sh" "$PROFILE" MANUAL_RESTART "requested_by=$(id -un)"
    sudo systemctl restart "$UNIT"
    sudo systemctl stop "$WATCHDOG_UNIT" 2>/dev/null || true
    sudo systemctl --no-pager status "$UNIT" || true
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
