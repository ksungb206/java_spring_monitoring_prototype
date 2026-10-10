#!/usr/bin/env bash
# Create independent deployment checkouts without touching the developer workspace.
set -euo pipefail

SOURCE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this script from inside the source Git repository." >&2
  exit 1
}
REMOTE_URL="$(git -C "$SOURCE_ROOT" remote get-url origin)"
BASE_DIR="${DEPLOY_BASE_DIR:-$HOME/deploy-checkouts}"

if [[ $# -eq 0 ]]; then
  set -- dev
fi

for profile in "$@"; do
  case "$profile" in dev|stage|prod) ;; *) echo "Invalid profile: $profile (use dev, stage, prod)" >&2; exit 2;; esac

  SOURCE_ENV="$SOURCE_ROOT/.env.$profile"
  DEST="$BASE_DIR/$profile"

  [[ -f "$SOURCE_ENV" ]] || {
    echo "Missing source config $SOURCE_ENV; refusing to create an unconfigured checkout." >&2
    exit 1
  }

  if [[ -e "$DEST" ]]; then
    [[ -d "$DEST/.git" ]] || {
      echo "Destination exists but is not a Git checkout: $DEST" >&2
      exit 1
    }
    DEST_REMOTE="$(git -C "$DEST" remote get-url origin)"
    [[ "$DEST_REMOTE" == "$REMOTE_URL" ]] || {
      echo "Origin mismatch in $DEST: expected $REMOTE_URL, found $DEST_REMOTE" >&2
      exit 1
    }
    [[ "$(git -C "$DEST" branch --show-current)" == "$profile" ]] || {
      echo "Checkout $DEST must be on branch $profile; refusing to switch it automatically." >&2
      exit 1
    }
    [[ -z "$(git -C "$DEST" status --porcelain --untracked-files=no)" ]] || {
      echo "Tracked changes found in $DEST; refusing to update it." >&2
      exit 1
    }
    git -C "$DEST" fetch --prune origin "$profile"
    git -C "$DEST" merge --ff-only "origin/$profile"
  else
    mkdir -p "$BASE_DIR"
    git clone --single-branch --branch "$profile" "$REMOTE_URL" "$DEST"
  fi

  # Never overwrite a previously provisioned environment file.
  if [[ ! -f "$DEST/.env.$profile" ]]; then
    install -m 600 "$SOURCE_ENV" "$DEST/.env.$profile"
    echo "Copied .env.$profile with owner-only permissions."
  else
    echo "$DEST/.env.$profile already exists; kept existing environment settings."
  fi

  echo "Prepared $profile checkout: $DEST"
done

cat <<EOF

Next steps for a newly isolated DEV checkout:
  1. Review $BASE_DIR/dev/.env.dev locally; do not print or commit secrets.
  2. Install/update its systemd unit (builds the JAR but does not start it):
     bash "$BASE_DIR/dev/scripts/systemd-manager.sh" install dev
  3. In GitHub Settings > Environments > dev, set the Environment variable:
     DEPLOY_ROOT=$BASE_DIR/dev
  4. Only after the checkout, .env, systemd unit, and GitHub variable are ready,
     merge/push the deployment workflow to dev and run the deployment test.

For stage/prod, prepare each environment separately and install its systemd unit
from that environment's checkout before enabling deployment.
EOF
