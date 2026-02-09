# Hello World

Deploy as Rancher user `dreimsbach` in namespace `playground`:

```bash
./bin/deploy_hello_world_dreimsbach.sh deploy
./bin/deploy_hello_world_dreimsbach.sh status
kubectl -n playground port-forward svc/hello-world 8088:80  # open http://localhost:8088
```

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
