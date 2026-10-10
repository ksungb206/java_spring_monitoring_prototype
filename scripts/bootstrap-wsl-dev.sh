#!/usr/bin/env bash
# One-time setup on the installing developer's OWN WSL instance.
# Run from any branch of a local clone; never changes the developer checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -r | tr '[:upper:]' '[:lower:]')" == *microsoft* ]] || { echo "This prototype bootstrap is WSL-only." >&2; exit 1; }
[[ "$(ps -p 1 -o comm=)" == systemd ]] || { echo "Enable WSL systemd before setup (see docs/wsl-dev-unattended.md)." >&2; exit 1; }
for bin in git curl tar python3 mvn sudo systemctl visudo; do command -v "$bin" >/dev/null || { echo "Missing: $bin" >&2; exit 1; }; done
[[ -f "$ROOT/.env.dev" ]] || { echo "Create $ROOT/.env.dev locally (never commit it)." >&2; exit 1; }
bash "$ROOT/scripts/setup-deploy-checkouts.sh" dev
DEPLOY_ROOT="${DEPLOY_BASE_DIR:-$HOME/deploy-checkouts}/dev"
bash "$DEPLOY_ROOT/scripts/systemd-manager.sh" install dev
UNIT=main-api-dev.service
SYSTEMCTL="$(command -v systemctl)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: %s cat %s, %s show %s -p WorkingDirectory --value, %s restart %s\n' \
  "$(id -un)" "$SYSTEMCTL" "$UNIT" "$SYSTEMCTL" "$UNIT" "$SYSTEMCTL" "$UNIT" > "$TMP"
chmod 440 "$TMP"
sudo visudo -cf "$TMP"
sudo install -m 440 "$TMP" /etc/sudoers.d/main-api-deploy-dev
bash "$ROOT/scripts/register-runner-service.sh" dev
echo "WSL DEV setup complete. Runner is managed by systemd; no ./run.sh needed."
echo "Check: sudo systemctl status $(cat "${RUNNER_DIR:-$HOME/actions-runner-dev}/.service")"
echo "API (after deployment): http://localhost:7002/api/v1/health"
