# Hello World

Deploy in namespace `playground`:

```bash
./bin/deploy_hello_world.sh deploy
./bin/deploy_hello_world.sh status
```

Ingress URL is generated from the current git branch:

- `<branch>-hello-world.localhost`
- Example for branch `rancher`: `http://rancher-hello-world.localhost`

Cleanup:

```bash
./bin/deploy_hello_world.sh delete
```

Force new rollout:

```bash
./bin/deploy_hello_world.sh redeploy
```

## GitLab CI/CD

Pipeline file: `.gitlab-ci.yml`

Set this protected CI/CD variable in GitLab:

- `KUBE_CONFIG_B64`: Base64-encoded kubeconfig for ServiceAccount `gitlab-deployer` in namespace `playground`.

Example to create it locally:

```bash
TOKEN="$(kubectl -n playground create token gitlab-deployer)"
SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

cat > /tmp/kubeconfig-gitlab-deployer.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA}
    server: ${SERVER}
  name: local
contexts:
- context:
    cluster: local
    namespace: playground
    user: gitlab-deployer
  name: gitlab-deployer@local
current-context: gitlab-deployer@local
users:
- name: gitlab-deployer
  user:
    token: ${TOKEN}
EOF

base64 < /tmp/kubeconfig-gitlab-deployer.yaml | tr -d '\n'
```
