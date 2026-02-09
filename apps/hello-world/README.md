# Hello World

Deploy as Rancher user `dreimsbach` in namespace `playground`:

```bash
./bin/deploy_hello_world_dreimsbach.sh deploy
./bin/deploy_hello_world_dreimsbach.sh status
```

Ingress URL is generated from the current git branch:

- `<branch>-hello-world.localhost`
- Example for branch `rancher`: `http://rancher-hello-world.localhost`

Cleanup:

```bash
./bin/deploy_hello_world_dreimsbach.sh delete
```

Force new rollout:

```bash
./bin/deploy_hello_world_dreimsbach.sh redeploy
```

## GitLab CI/CD

Pipeline file: `.gitlab-ci.yml`

Set this protected CI/CD variable in GitLab:

- `KUBE_CONFIG_B64`: Base64-encoded kubeconfig with access to your cluster.

Example to create it locally:

```bash
base64 < ~/.kube/config | tr -d '\n'
```
