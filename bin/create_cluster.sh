
#Local Base Folder from GIT resources
localVolumePath=$(pwd)/../k3dvolume

# Create Folder if not exists
mkdir -p $localVolumePath/hello-world

# add index html file local
echo "<html><head></head><body><h1>Local HTML File Hello World<h1></body></html>" > $localVolumePath/hello-world/index.html

# Create k3d Cluster with NGINX as Ingress and mount local folder als Volume
k3d cluster create hello-world-test \
  --no-lb  \
  --servers 1  \
  --volume "$localVolumePath:/usr/share/k3dvolume/" \
  --volume "$(pwd)/base/helm/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml" \
  --k3s-arg '--no-deploy=traefik@server:*' \
  --servers-memory=2g \
  --network host \
  --api-port 37.120.174.11:6443 \
  --k3s-arg '--advertise-address=37.120.174.11@server:*' \
  --k3s-arg '--tls-san=37.120.174.11@server:*'


#Kustomize apply
kubectl apply -k .

