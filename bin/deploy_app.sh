#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-deploy}"
APP_NAME_ARG="${2:-}"
NAMESPACE_ARG="${3:-}"

APP_NAME="${APP_NAME_ARG:-${APP_NAME:-}}"
if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 {deploy|redeploy|delete|status|logs} <app_name> [namespace]"
  exit 1
fi

NAMESPACE="${NAMESPACE_ARG:-${NAMESPACE:-$APP_NAME}}"
MANIFEST_TEMPLATE="${MANIFEST_TEMPLATE:-apps/${APP_NAME}/deployment.yaml}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120s}"
AS_USER="${AS_USER:-}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"
HOST_DOMAIN="${HOST_DOMAIN:-localhost}"

KUBECTL_ARGS=()
if [ -n "$AS_USER" ]; then
  KUBECTL_ARGS+=(--as="$AS_USER")
fi

run_kubectl() {
  if [ "${#KUBECTL_ARGS[@]}" -gt 0 ]; then
    kubectl "${KUBECTL_ARGS[@]}" "$@"
    return
  fi
  kubectl "$@"
}

current_branch() {
  local branch
  branch="${BRANCH_NAME:-${CI_COMMIT_REF_SLUG:-${CI_COMMIT_REF_NAME:-}}}"
  if [ -z "$branch" ]; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    branch="local"
  fi
  printf '%s' "$branch"
}

slugify() {
  local raw slug
  raw="$1"
  slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [ -z "$slug" ]; then
    slug="local"
  fi
  printf '%s' "$slug"
}

truncate_name() {
  local value max
  value="$1"
  max="${2:-63}"
  printf '%s' "$value" | cut -c1-"$max" | sed -E 's/-+$//'
}

branch_slug() {
  slugify "$(current_branch)"
}

app_slug() {
  slugify "$APP_NAME"
}

resource_name() {
  local value
  value="$(branch_slug)-$(app_slug)"
  truncate_name "$value" 63
}

ingress_name() {
  local value
  value="$(resource_name)-ingress"
  truncate_name "$value" 63
}

branch_host() {
  printf '%s.%s' "$(resource_name)" "$HOST_DOMAIN"
}

render_manifest() {
  local out_file
  out_file="$1"
  sed \
    -e "s|__APP_INSTANCE__|$(resource_name)|g" \
    -e "s|__APP_NAME__|$(app_slug)|g" \
    -e "s|__NAMESPACE__|${NAMESPACE}|g" \
    -e "s|__BRANCH_SLUG__|$(branch_slug)|g" \
    "$MANIFEST_TEMPLATE" > "$out_file"
}

apply_branch_ingress() {
  local host name
  host="$(branch_host)"
  name="$(ingress_name)"
  cat <<EOF | run_kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
spec:
  ingressClassName: ${INGRESS_CLASS}
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $(resource_name)
                port:
                  number: 80
EOF
  echo "URL: http://${host}"
}

delete_branch_ingress() {
  run_kubectl -n "$NAMESPACE" delete ingress "$(ingress_name)" --ignore-not-found=true
}

deploy() {
  local rendered
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' RETURN
  render_manifest "$rendered"
  run_kubectl apply -f "$rendered"
  apply_branch_ingress
  run_kubectl -n "$NAMESPACE" rollout status "deployment/$(resource_name)" --timeout="$WAIT_TIMEOUT"
  run_kubectl -n "$NAMESPACE" get deployment "$(resource_name)" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$(resource_name)" -o wide
  run_kubectl -n "$NAMESPACE" get ingress "$(ingress_name)" -o wide
}

delete_workload() {
  local rendered
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' RETURN
  render_manifest "$rendered"
  run_kubectl delete -f "$rendered" --ignore-not-found=true
  delete_branch_ingress
}

status() {
  run_kubectl -n "$NAMESPACE" get deployment "$(resource_name)" -o wide
  run_kubectl -n "$NAMESPACE" get pods -l "app=$(resource_name)" -o wide
  run_kubectl -n "$NAMESPACE" get service "$(resource_name)" -o wide
  run_kubectl -n "$NAMESPACE" get ingress "$(ingress_name)" -o wide
  echo "URL: http://$(branch_host)"
}

logs() {
  local pod_name
  pod_name="$(run_kubectl -n "$NAMESPACE" get pods -l "app=$(resource_name)" -o jsonpath='{.items[0].metadata.name}')"
  if [ -z "$pod_name" ]; then
    echo "No pod found for selector app=$(resource_name) in namespace $NAMESPACE"
    exit 1
  fi
  run_kubectl -n "$NAMESPACE" logs "$pod_name" --tail=200
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
    echo "Usage: $0 {deploy|redeploy|delete|status|logs} <app_name> [namespace]"
    exit 1
    ;;
esac
