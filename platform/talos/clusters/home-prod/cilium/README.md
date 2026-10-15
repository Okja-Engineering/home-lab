# Cilium

Cilium is the cluster's CNI from the first boot, with kube-proxy replacement ([ADR-005](../../../../../docs/adr/005-use-cilium-with-kube-proxy-replacement.md)). This directory holds its Helm values and the two steps that install it and check it:

- [`values.yaml`](values.yaml): the Helm values, each with a comment giving its reason.
- In [`metadata.env`](../metadata.env): `CILIUM_VERSION` is the chart version, and `CILIUM_CHART_SHA256` is the SHA-256 of that chart file. helm doesn't check the file; the install step does.

These steps live here until [issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) carries them into the runbooks.

## What the Values Do

- **IPv4 only** ([ADR-016](../../../../../docs/adr/016-use-ipv4-only-pod-and-service-networking-initially.md)). Pod addresses come from the range Kubernetes assigns to each node (`ipam.mode: kubernetes`), not from Cilium's default pool, 10.0.0.0/8, which contains the node network ([ADR-014](../../../../../docs/adr/014-rebase-address-plan-onto-10-0-0-0-24.md)).
- **No kube-proxy.** Cilium replaces it, and reaches the API server through KubePrism, Talos's load balancer on every node at `localhost:7445`.
- **Talos's mounts.** Talos mounts cgroup2 and the BPF filesystem itself, so Cilium mounts neither. The chart then runs no privileged container.
- **Native routing.** Pod traffic between nodes is routed on the one L2 segment, not tunnelled.
- **Capabilities** are the Talos guide's lists: no `SYS_MODULE`, and no `SYSLOG`, which the chart adds by default.
- **No metrics listeners.** The operator's and Envoy's Prometheus endpoints (9963 and 9964) are off.
- **Left at the chart's defaults:** `bpf.masquerade` (off), Gateway API and L2 announcements (off until Phase 3), and two operator replicas.

## Before You Start

- **Tools.** On the workstation, as well as `talosctl` and `kubectl`: `brew install helm cilium-cli`.
- **When.** Install Cilium on cp-01 straight after `talosctl bootstrap` and fetching the kubeconfig, as the Talos guide does. The guide also warns of a wait at boot phase 18/19 (`retrying error: node not ready`) with a 10-minute window. Talos v1.14.2 has no such wait: its boot sequence ends once Talos's own services have started, and no step in it waits for the node to be Ready ([`v1alpha1_sequencer.go`](https://github.com/siderolabs/talos/blob/v1.14.2/internal/app/machined/pkg/runtime/v1alpha1/v1alpha1_sequencer.go#L214-L254)). So there is no deadline.
- **Expected until Cilium runs:** every node reports `NotReady`, and CoreDNS stays `Pending`.
- **The kubeconfig.** `KUBECONFIG` must name the one kubeconfig file fetched after bootstrap, by its full path, and that file's current context must point at `CLUSTER_ENDPOINT` from `metadata.env`. Both steps stop otherwise. They export `KUBECONFIG` after checking it, so helm, kubectl and cilium all use that file, even if it wasn't exported.
- **Not `talosctl health`.** With Talos's default CNI disabled, `talosctl health` skips its node-Ready and CoreDNS checks, so a pass says nothing about Cilium. It checks etcd, the control-plane pods, apid and the kubelet, and can follow. Cilium's readiness is checked in two stages, below.

## Install Cilium on cp-01

Paste this from anywhere inside the repository. It installs only committed files: it reads `metadata.env` and `values.yaml` from the current commit, and stops, installing nothing, if either has uncommitted changes. It also stops if any variable whose name starts with `HELM_` is set, if `KUBECONFIG` isn't one file, or if the current context doesn't point at `CLUSTER_ENDPOINT`. helm reads `HELM_` variables, and they can change where and how it installs: `HELM_KUBEAPISERVER` sends it to another API server, `HELM_DEBUG` prints the rendered manifest with the Cilium CA's private key, and `HELM_DRIVER` moves the release record. It downloads the chart, checks it against `CILIUM_CHART_SHA256`, and installs from the checked file. Then it waits for the agent and Envoy to roll out, for the operator to be available and for every node to be Ready, and lists the nodes.

<!-- cilium-install:begin -->
```bash
(
  set -eu
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
  d=platform/talos/clusters/home-prod
  if test -z "$top" || ! test -f "$top/$d/metadata.env"; then
    echo "Stopping: run this inside the home-lab repository. Nothing was installed." >&2
    exit 1
  fi
  cd "$top/$d"
  if test -n "$(git status --porcelain --untracked-files=no -- metadata.env cilium/values.yaml)"; then
    echo "Stopping: metadata.env or cilium/values.yaml has uncommitted changes. Cilium is installed only from committed files. Nothing was installed." >&2
    exit 1
  fi
  h="$(env | awk -F= '/^HELM_/ { s = s " " $1 } END { print s }')"
  if test -n "$h"; then
    echo "Stopping: helm would read these variables:$h. Unset them, then paste again. Nothing was installed." >&2
    exit 1
  fi
  if test -z "${KUBECONFIG:-}" || ! test -f "$KUBECONFIG"; then
    echo "Stopping: KUBECONFIG must name the one kubeconfig file fetched after bootstrap. Nothing was installed." >&2
    exit 1
  fi
  export KUBECONFIG
  t="$(mktemp -d)"
  git -C "$top" archive -o "$t/in.tar" "HEAD:$d" metadata.env cilium/values.yaml
  tar -x -C "$t" -f "$t/in.tar"
  source "$t/metadata.env"
  if test -z "${CILIUM_VERSION:-}" || test -z "${CILIUM_CHART_SHA256:-}" || test -z "${CLUSTER_ENDPOINT:-}"; then
    echo "Stopping: CILIUM_VERSION, CILIUM_CHART_SHA256 or CLUSTER_ENDPOINT is empty in metadata.env. Nothing was installed." >&2
    exit 1
  fi
  ctx="$(kubectl config current-context)" || ctx=""
  server="$(kubectl config view --minify --context "$ctx" -o 'jsonpath={.clusters[0].cluster.server}')" || server=""
  if test -z "$ctx" || test -z "$server" || test "$server" != "$CLUSTER_ENDPOINT"; then
    echo "Stopping: the current kubeconfig context does not point at $CLUSTER_ENDPOINT. Nothing was installed." >&2
    exit 1
  fi
  helm pull cilium --repo https://helm.cilium.io/ --version "$CILIUM_VERSION" --destination "$t"
  if ! printf '%s  %s\n' "$CILIUM_CHART_SHA256" "$t/cilium-$CILIUM_VERSION.tgz" | shasum -a 256 -c - >/dev/null; then
    echo "Stopping: the downloaded chart does not match CILIUM_CHART_SHA256. Nothing was installed." >&2
    exit 1
  fi
  helm install cilium "$t/cilium-$CILIUM_VERSION.tgz" --kubeconfig "$KUBECONFIG" --kube-context "$ctx" \
    --namespace kube-system -f "$t/cilium/values.yaml"
  rm -rf "$t"
  kubectl --context "$ctx" -n kube-system rollout status daemonset/cilium --timeout=10m
  kubectl --context "$ctx" -n kube-system rollout status daemonset/cilium-envoy --timeout=10m
  kubectl --context "$ctx" -n kube-system wait --for=condition=Available deployment/cilium-operator --timeout=10m
  kubectl --context "$ctx" wait --for=condition=Ready nodes --all --timeout=10m
  kubectl --context "$ctx" get nodes
)
```
<!-- cilium-install:end -->

Done means the agent and Envoy have rolled out, the operator is available, and cp-01 is `Ready`. Of the operator's two replicas, one stays `Pending` until a second node joins: the two must run on different nodes. One running replica is enough for the operator to count as available, but not for `cilium status`, which is why that check waits for the next step.

- **Pasting it again** stops at `helm install` with "cannot reuse a name that is still in use", by design. That means a release named `cilium` exists, not that it deployed: helm 4 gives the same error after an install that failed or was interrupted. `helm status cilium --namespace kube-system --kubeconfig "$KUBECONFIG"` shows its status, which is `deployed` once an install has finished.
- **A run that stops partway** can leave a `tmp.*` directory in the per-user temporary folder (`getconf DARWIN_USER_TEMP_DIR`). It holds copies of the committed `metadata.env` and `values.yaml`, and perhaps the public chart. Nothing in it is secret, and it can be deleted.

## Check Readiness After cp-02 and cp-03 Join

Once cp-02 and cp-03 have joined, paste this. It changes nothing, and reads `metadata.env` from the working tree. It runs Cilium's full health check, `cilium status --wait`, which now includes both operator replicas and gives up after 5 minutes. Then it waits for every node to be `Ready`, stops unless there are exactly three, and lists them.

<!-- cilium-ready:begin -->
```bash
(
  set -eu
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
  d=platform/talos/clusters/home-prod
  if test -z "$top" || ! test -f "$top/$d/metadata.env"; then
    echo "Stopping: run this inside the home-lab repository. Nothing was checked." >&2
    exit 1
  fi
  cd "$top/$d"
  source ./metadata.env
  if test -z "${CLUSTER_ENDPOINT:-}" || test -z "${KUBECONFIG:-}" || ! test -f "$KUBECONFIG"; then
    echo "Stopping: CLUSTER_ENDPOINT is empty, or KUBECONFIG does not name the kubeconfig file fetched after bootstrap. Nothing was checked." >&2
    exit 1
  fi
  export KUBECONFIG
  ctx="$(kubectl config current-context)" || ctx=""
  server="$(kubectl config view --minify --context "$ctx" -o 'jsonpath={.clusters[0].cluster.server}')" || server=""
  if test -z "$ctx" || test -z "$server" || test "$server" != "$CLUSTER_ENDPOINT"; then
    echo "Stopping: the current kubeconfig context does not point at $CLUSTER_ENDPOINT. Nothing was checked." >&2
    exit 1
  fi
  cilium status --wait --context "$ctx"
  kubectl --context "$ctx" wait --for=condition=Ready nodes --all --timeout=10m
  n="$(kubectl --context "$ctx" get nodes -o name | wc -l | tr -d ' ')"
  if test "$n" != 3; then
    echo "Stopping: expected 3 nodes, found $n." >&2
    exit 1
  fi
  kubectl --context "$ctx" get nodes
)
```
<!-- cilium-ready:end -->

## Notes

- **Flux takes over** this Helm release in Phase 4 ([ADR-004](../../../../../docs/adr/004-defer-gitops-until-control-plane-is-healthy.md)). Until then, helm manages it from the workstation.
- **Never commit or publish the output of `helm template`** for this chart: it contains generated keys and certificates, the Cilium CA and the Hubble server certificate among them.
- **Issue 22** carries these steps into the runbooks. A runbook links to the two marked blocks above, or moves each one with its markers; it never keeps a second copy.
