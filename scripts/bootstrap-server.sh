#!/usr/bin/env bash
# Bootstrap a clean dev/stage/prod host with a single environment checkout.
set -euo pipefail
PROFILE="${1:-}"
case "$PROFILE" in dev|stage|prod) ;; *) echo "Usage: bootstrap-server.sh dev|stage|prod" >&2; exit 2;; esac
: "${ENV_FILE_SOURCE:?Set ENV_FILE_SOURCE to the local environment configuration file}"
[[ -f "$ENV_FILE_SOURCE" ]] || { echo "Environment configuration file missing" >&2; exit 1; }
SOURCE_ROOT="${SOURCE_ROOT:-$HOME/monitoring-source}"
REPO_URL="${REPO_URL:-https://github.com/ksungb206/java_spring_monitoring_prototype.git}"
if [[ ! -e "$SOURCE_ROOT" ]]; then
  git clone --single-branch --branch "$PROFILE" "$REPO_URL" "$SOURCE_ROOT"
else
  [[ -d "$SOURCE_ROOT/.git" ]] || { echo "Existing path is not a Git checkout" >&2; exit 1; }
  [[ "$(git -C "$SOURCE_ROOT" branch --show-current)" == "$PROFILE" ]] || { echo "Wrong checkout branch" >&2; exit 1; }
  [[ -z "$(git -C "$SOURCE_ROOT" status --porcelain --untracked-files=no)" ]] || { echo "Tracked changes present" >&2; exit 1; }
  git -C "$SOURCE_ROOT" fetch origin "$PROFILE"
  git -C "$SOURCE_ROOT" merge --ff-only "origin/$PROFILE"
fi
install -m 600 "$ENV_FILE_SOURCE" "$SOURCE_ROOT/.env.$PROFILE"
exec bash "$SOURCE_ROOT/scripts/provision-server.sh" "$PROFILE"
