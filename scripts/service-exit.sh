#!/usr/bin/env bash
# systemd supplies SERVICE_RESULT / EXIT_CODE / EXIT_STATUS to ExecStopPost.
set -u
PROFILE="${1:-local}"
RESULT="${SERVICE_RESULT:-unknown}"
CODE="${EXIT_CODE:-unknown}"
STATUS="${EXIT_STATUS:-unknown}"
if [[ "$RESULT" == success ]]; then EVENT=SERVICE_STOPPED; else EVENT=SERVICE_FAILED; fi
/bin/bash "$(dirname "$0")/service-event.sh" "$PROFILE" "$EVENT" "result=$RESULT exit_code=$CODE exit_status=$STATUS"
# Only abnormal exits: avoid duplicate email on graceful shutdown.
if [[ "$RESULT" != success ]]; then
  /usr/bin/python3 "$(dirname "$0")/abnormal-exit-email.py" "$PROFILE" "$RESULT" "$CODE" "$STATUS"
fi

