#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-hello-world}"
NAMESPACE="${NAMESPACE:-playground}"
MANIFEST_TEMPLATE="${MANIFEST_TEMPLATE:-apps/hello-world/deployment.yaml}"

exec env \
  MANIFEST_TEMPLATE="$MANIFEST_TEMPLATE" \
  "$(dirname "$0")/deploy_app.sh" "${1:-deploy}" "$APP_NAME" "$NAMESPACE"
