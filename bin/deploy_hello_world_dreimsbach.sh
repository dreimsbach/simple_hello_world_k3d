#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-deploy}"

MANIFEST_PATH="${MANIFEST_PATH:-apps/hello-world-dreimsbach/deployment.yaml}"
NAMESPACE="${NAMESPACE:-playground}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-hello-world-dreimsbach}"
APP_LABEL="${APP_LABEL:-hello-world-dreimsbach}"
AS_USER="${AS_USER:-dreimsbach}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120s}"

KUBECTL_ARGS=()
if [ -n "$AS_USER" ]; then
  KUBECTL_ARGS+=(--as="$AS_USER")
fi

run_kubectl() {
  kubectl "${KUBECTL_ARGS[@]}" "$@"
}

deploy() {
  # Remove legacy pod from the previous standalone Pod setup.
  run_kubectl -n "$NAMESPACE" delete pod "$DEPLOYMENT_NAME" --ignore-not-found=true >/dev/null 2>&1 || true
  run_kubectl apply -f "$MANIFEST_PATH"
  run_kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT_NAME" --timeout="$WAIT_TIMEOUT"
  run_kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT_NAME" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$APP_LABEL" -o wide
}

delete_workload() {
  run_kubectl delete -f "$MANIFEST_PATH" --ignore-not-found=true
}

status() {
  run_kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT_NAME" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$APP_LABEL" -o wide
  run_kubectl -n "$NAMESPACE" get service "$DEPLOYMENT_NAME" -o wide
}

logs() {
  POD_NAME="$(run_kubectl -n "$NAMESPACE" get pods -l "app=$APP_LABEL" -o jsonpath='{.items[0].metadata.name}')"
  if [ -z "$POD_NAME" ]; then
    echo "No pod found for selector app=$APP_LABEL in namespace $NAMESPACE"
    exit 1
  fi
  run_kubectl -n "$NAMESPACE" logs "$POD_NAME" --tail=200
}

case "$ACTION" in
  deploy)
    deploy
    ;;
  redeploy)
    delete_workload
    deploy
    ;;
  delete)
    delete_workload
    ;;
  status)
    status
    ;;
  logs)
    logs
    ;;
  *)
    echo "Usage: $0 {deploy|redeploy|delete|status|logs}"
    exit 1
    ;;
esac
