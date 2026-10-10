#!/usr/bin/env bash
# Prepare a dedicated environment checkout and its application service.
set -euo pipefail
PROFILE="${1:-}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Usage: provision-server.sh dev|stage|prod" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(git -C "$ROOT" branch --show-current)" == "$PROFILE" ]] || { echo "Expected branch $PROFILE" >&2; exit 1; }
[[ "$(ps -p 1 -o comm=)" == systemd ]] || { echo "systemd must be PID 1" >&2; exit 1; }
for bin in git curl tar python3 mvn sudo systemctl visudo; do
  command -v "$bin" >/dev/null || { echo "Missing prerequisite: $bin" >&2; exit 1; }
done
[[ -f "$ROOT/.env.$PROFILE" ]] || { echo "Missing .env.$PROFILE" >&2; exit 1; }
bash "$ROOT/scripts/setup-deploy-checkouts.sh" "$PROFILE"
DEPLOY_ROOT="${DEPLOY_BASE_DIR:-$HOME/deploy-checkouts}/$PROFILE"
bash "$DEPLOY_ROOT/scripts/systemd-manager.sh" install "$PROFILE"
UNIT="main-api-$PROFILE.service"
SYSTEMCTL="$(command -v systemctl)"
SUDOERS_TMP="$(mktemp)"
trap 'rm -f "$SUDOERS_TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: %s cat %s, %s show %s -p WorkingDirectory --value, %s restart %s\n' \
  "$(id -un)" "$SYSTEMCTL" "$UNIT" "$SYSTEMCTL" "$UNIT" "$SYSTEMCTL" "$UNIT" > "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"
sudo visudo -cf "$SUDOERS_TMP"
sudo install -m 440 "$SUDOERS_TMP" "/etc/sudoers.d/main-api-deploy-$PROFILE"
bash "$ROOT/scripts/register-runner-service.sh" "$PROFILE"
echo "Provisioning complete for $PROFILE"
