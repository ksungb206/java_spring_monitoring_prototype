#!/usr/bin/env bash
# Register one official GitHub Actions runner and enable its boot service.
set -euo pipefail
PROFILE="${1:-}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Usage: register-runner-service.sh dev|stage|prod" >&2; exit 2;; esac
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner-$PROFILE}"
if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  : "${GITHUB_RUNNER_TOKEN:?Set a short-lived GitHub runner registration token}"
  [[ ! -e "$RUNNER_DIR" ]] || { echo "Runner directory exists but is not configured: $RUNNER_DIR" >&2; exit 1; }
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
    --name "$(hostname)-$PROFILE" \
    --labels "deploy-$PROFILE" \
    --work "_work")
fi
if ! sudo "$RUNNER_DIR/svc.sh" status >/dev/null 2>&1; then
  sudo "$RUNNER_DIR/svc.sh" install "$(id -un)"
fi
sudo "$RUNNER_DIR/svc.sh" start
sudo "$RUNNER_DIR/svc.sh" status
