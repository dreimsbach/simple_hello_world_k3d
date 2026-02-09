
#!/usr/bin/env bash
set -euo pipefail

clusterName="hello-world-test"

# Local base folder from git resources
localVolumePath="$(pwd)/k3dvolume"

# Create folders if not exists
mkdir -p "$localVolumePath/rancher"

# Keep Rancher login deterministic across rebuilds.
# Set RESET_RANCHER_DATA=false to keep an existing Rancher DB.
if [ "${RESET_RANCHER_DATA:-true}" = "true" ]; then
  rm -rf "$localVolumePath/rancher/"*
fi

# Create k3d Cluster with NGINX as Ingress and mount local folder als Volume
k3d cluster create "$clusterName" \
  --port 8089:8089@loadbalancer  \
  --port 80:80@loadbalancer  \
  --port 443:443@loadbalancer  \
  --servers 1  \
  --volume "$localVolumePath:/usr/share/k3dvolume/" \
  --volume "$(pwd)/base/helm/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml" \
  --k3s-arg '--disable=traefik@server:*' \
  --servers-memory=2g

# Kustomize apply
kubectl apply -k .

# Wait for Rancher and management CRDs, then apply local user/bindings.
kubectl wait --for=condition=available deployment/rancher -n cattle-system --timeout=300s
kubectl wait --for=condition=Established crd/users.management.cattle.io --timeout=180s

for _ in {1..60}; do
  if kubectl get namespace local >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl get namespace local >/dev/null
kubectl apply -f base/rancher-access.yaml
