#!/usr/bin/env bash
# Register one GitHub Actions runner and keep it running via systemd.
set -euo pipefail
PROFILE="${1:-}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Usage: register-runner-service.sh dev|stage|prod" >&2; exit 2;; esac
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner-$PROFILE}"
if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  : "${GITHUB_RUNNER_TOKEN:?Set a short-lived GitHub runner registration token}"
  if [[ -e "$RUNNER_DIR" ]] && [[ -n "$(ls -A "$RUNNER_DIR")" ]]; then
    echo "Existing unconfigured runner directory: $RUNNER_DIR. Resolve manually to avoid overwriting data." >&2
    exit 1
  fi
  mkdir -p "$RUNNER_DIR"
  RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
  ASSET_URL="$(printf '%s' "$RELEASE_JSON" | python3 -c 'import json,sys,platform; d=json.load(sys.stdin); arch={"x86_64":"x64","aarch64":"arm64"}.get(platform.machine()); assert arch, "Unsupported architecture"; a=[x["browser_download_url"] for x in d["assets"] if x["name"].startswith("actions-runner-linux-"+arch+"-") and x["name"].endswith(".tar.gz")]; assert len(a)==1; print(a[0])')"
  ARCHIVE="$(mktemp)"
  trap 'rm -f "$ARCHIVE"' EXIT
  curl -fL --retry 3 "$ASSET_URL" -o "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C "$RUNNER_DIR"
  (cd "$RUNNER_DIR" && ./config.sh --unattended \
    --url "${GITHUB_REPOSITORY_URL:-https://github.com/ksungb206/java_spring_monitoring_prototype}" \
    --token "$GITHUB_RUNNER_TOKEN" \
    --name "$(hostname)-$(id -un)-$PROFILE" \
    --labels "deploy-$PROFILE" \
    --work "_work")
fi
[[ -x "$RUNNER_DIR/svc.sh" ]] || { echo "Runner service script missing: $RUNNER_DIR/svc.sh" >&2; exit 1; }
if [[ ! -s "$RUNNER_DIR/.service" ]]; then
  (cd "$RUNNER_DIR" && sudo ./svc.sh install "$(id -un)")
fi
SERVICE="$(cat "$RUNNER_DIR/.service")"
[[ "$SERVICE" == actions.runner.*.service ]] || { echo "Unexpected service name: $SERVICE" >&2; exit 1; }
sudo mkdir -p "/etc/systemd/system/$SERVICE.d"
OVERRIDE="$(mktemp)"
trap 'rm -f "$OVERRIDE" "${ARCHIVE:-}"' EXIT
printf '[Service]\nRestart=always\nRestartSec=5\n' > "$OVERRIDE"
sudo install -m 644 "$OVERRIDE" "/etc/systemd/system/$SERVICE.d/restart.conf"
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE"
sudo systemctl is-active --quiet "$SERVICE" || { echo "Runner service not active: $SERVICE" >&2; exit 1; }
echo "Runner active and enabled: $SERVICE (deploy-$PROFILE)"
