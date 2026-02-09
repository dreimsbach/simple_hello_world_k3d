#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-deploy}"

MANIFEST_PATH="${MANIFEST_PATH:-apps/hello-world/deployment.yaml}"
NAMESPACE="${NAMESPACE:-playground}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-hello-world}"
APP_LABEL="${APP_LABEL:-hello-world}"
AS_USER="${AS_USER:-}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120s}"
INGRESS_NAME="${INGRESS_NAME:-${DEPLOYMENT_NAME}-ingress}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"
HOST_SUFFIX="${HOST_SUFFIX:-hello-world.localhost}"

KUBECTL_ARGS=()
if [ -n "$AS_USER" ]; then
  KUBECTL_ARGS+=(--as="$AS_USER")
fi

current_branch() {
  local branch
  branch="${BRANCH_NAME:-${CI_COMMIT_REF_NAME:-}}"
  if [ -z "$branch" ]; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    branch="local"
  fi
  printf '%s' "$branch"
}

branch_slug() {
  local raw slug
  raw="$(current_branch)"
  slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [ -z "$slug" ]; then
    slug="local"
  fi
  printf '%s' "$slug"
}

branch_host() {
  printf '%s-%s' "$(branch_slug)" "$HOST_SUFFIX"
}

run_kubectl() {
  kubectl "${KUBECTL_ARGS[@]}" "$@"
}

apply_branch_ingress() {
  local host
  host="$(branch_host)"
  cat <<EOF | run_kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${INGRESS_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: ${INGRESS_CLASS}
spec:
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${DEPLOYMENT_NAME}
                port:
                  number: 80
EOF
  echo "URL: http://${host}"
}

delete_branch_ingress() {
  run_kubectl -n "$NAMESPACE" delete ingress "$INGRESS_NAME" --ignore-not-found=true
}

deploy() {
  run_kubectl apply -f "$MANIFEST_PATH"
  apply_branch_ingress
  run_kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT_NAME" --timeout="$WAIT_TIMEOUT"
  run_kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT_NAME" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$APP_LABEL" -o wide
  run_kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" -o wide
}

delete_workload() {
  run_kubectl delete -f "$MANIFEST_PATH" --ignore-not-found=true
  delete_branch_ingress
}

status() {
  run_kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT_NAME" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$APP_LABEL" -o wide
  run_kubectl -n "$NAMESPACE" get service "$DEPLOYMENT_NAME" -o wide
  run_kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" -o wide
  echo "URL: http://$(branch_host)"
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
