# home-prod

Talos Linux cluster configuration for home production environment.

## Cluster Details

- **Name**: home-prod
- **Domain**: lab.home.arpa
- **Control Plane Nodes**: 3
- **Endpoint**: A Talos shared virtual IP (VIP) on port 6443, not a DNS name ([ADR-006](../../../../docs/adr/006-use-talos-vip-for-kubernetes-api-endpoint.md))

## Node IPs

- cp-01: 10.0.0.21
- cp-02: 10.0.0.22
- cp-03: 10.0.0.23

## Configuration

- **Metadata**: `metadata.env` records every value the machine configs use. The patches are plain YAML and `talosctl` substitutes nothing, so a value changed in `metadata.env` must also be changed in the patch that copies it. Each patch's comments name the keys it copies.
- **Patches**: Talos v1.14 configuration documents, applied by the block in [Generating the machine configs](#generating-the-machine-configs):
  - `patches/all-nodes.yaml`, for every node: the install disk and installer image, the time servers (with NTS), the name servers, and the pod and Service subnets;
  - `patches/control-plane.yaml`, for the control-plane nodes: no default CNI, no kube-proxy, workloads allowed on control-plane nodes, and the VIP;
  - `nodes/cp-01.yaml` to `nodes/cp-03.yaml`, one per node: the hostname, the port alias `lan0` (selected by bus path) and the static address with its default route.
- **Install disk**: selected by `disk.transport == "nvme"` (`INSTALL_DISK_TRANSPORT`), not by a device path. Only NVMe disks match, and each machine has one, its install disk (`INSTALL_DISK`). The boot drive (for example a KVM's built-in drive) is not an NVMe disk. The install erases the selected disk.

## Bootstrap Plan

**Not yet updated for ADR-005 to ADR-013.** This section, parts of the [Notes](#notes) below and both runbooks still follow the original plan: DHCP reservations for the nodes, a DNS name pointing at cp-01 as the endpoint, and bootstrap after all three nodes are configured. Where any of them disagrees with an [ADR](../../../../docs/adr/README.md), the ADR is current. [Issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) will rewrite this section and the runbooks. [Issue 24](https://github.com/Okja-Engineering/home-lab/issues/24) will then check that nothing else, the Notes included, contradicts the ADRs.

The bootstrap process transforms bare GMKtec mini PCs into a Talos Kubernetes control plane. This is a high-level plan; detailed execution steps are in the cp-01 runbook.

### Prerequisites

- Workstation has talosctl and kubectl installed
- 3x GMKtec mini PCs are available
- Netgear GS308 switch is plugged directly into a LAN port on the ISP-supplied gateway (unmanaged: no configuration), and cp-01, cp-02 and cp-03 are cabled to it
- Access to the ISP-supplied gateway for DHCP reservations and DNS

### Step 1: Hardware Preparation

- Configure BIOS/UEFI settings on all 3 nodes (secure boot off, virtualization enabled)
- Create Talos bootable USB media
- Boot cp-01 from Talos ISO
- Confirm hardware (interface names, disk paths)

### Step 2: Network Preparation

- Create DHCP reservations for cp-01 (10.0.0.21), cp-02 (10.0.0.22), cp-03 (10.0.0.23)
- Create DNS A record: k8s.lab.home.arpa → 10.0.0.21
- Verify network connectivity from workstation to nodes

### Step 3: Configuration Generation

- Generate Talos secrets bundle (store securely, not in Git)
- Generate machine configs using talosctl gen config with patches
- Review generated configs for correctness

### Step 4: Config Application

- Apply machine config to cp-01
- Apply machine config to cp-02
- Apply machine config to cp-03
- Verify all nodes are in maintenance mode

### Step 5: Cluster Bootstrap

- Bootstrap cluster on cp-01 (run once)
- Retrieve kubeconfig (store securely, not in Git)
- Verify cluster health via kubectl

### Validation Gates

- After Step 1: Hardware confirmed on cp-01
- After Step 2: DHCP reservations working, DNS resolving
- After Step 3: Generated configs reviewed
- After Step 4: All nodes in maintenance mode
- After Step 5: kubectl can access cluster

See [docs/runbooks/cp-01-talos-bootstrap.md](../../../../docs/runbooks/cp-01-talos-bootstrap.md) for detailed cp-01 execution steps.

See [docs/runbooks/three-node-control-plane-bootstrap.md](../../../../docs/runbooks/three-node-control-plane-bootstrap.md) for the three-node control plane bootstrap runbook.

## Notes

- Run bootstrap only once after all control plane nodes are configured
- Store `kubeconfig` securely, do not commit to Git
- Regenerate machine configs after modifying `metadata.env` or patches
- MAC addresses are documented locally for DHCP reservations, not committed to Git
- Network interface names must be confirmed via Talos before config generation
- Versions are pinned in `metadata.env` - use those versions

## Generating the machine configs

The block below writes `generated/cp-01.yaml` to `generated/cp-03.yaml` and `generated/talosconfig`, and validates each node's config for bare metal. Paste it into zsh or bash anywhere inside the repository. It needs `talosctl` at the `TALOS_VERSION` that `metadata.env` pins, `sops`, and the age key that opens `secrets.sops.yaml` ([issue 19](https://github.com/Okja-Engineering/home-lab/issues/19)).

- **Configs come only from committed files.** The block reads `metadata.env`, `patches/`, `nodes/` and `secrets.sops.yaml` as committed, and stops if any of them has uncommitted changes.
- **It decrypts the committed bundle itself, every time,** to `secrets/secrets.yaml` (mode 0600). A file already there is never used: it is replaced, and only when the decrypt succeeds.
- **It stops at the first error.** Each refusal starts with `Stopping:` and gives its reason. A run that stops partway may leave a temporary directory in the system's temporary folder; it holds committed files only, with the bundle still encrypted.
- **Never commit `generated/`.** The machine configs and `talosconfig` hold the cluster's secrets. Git ignores `generated/` and `secrets/`.
- **To test the block,** run it in a scratch clone whose committed `secrets.sops.yaml` is a throwaway bundle encrypted to a throwaway age key. This repository's `secrets/` never holds a throwaway.

<!-- talos-generate-configs:begin -->
```bash
(
  set -eu
  umask 077
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
  d=platform/talos/clusters/home-prod
  if test -z "$top" || ! test -f "$top/$d/metadata.env"; then
    echo "Stopping: run this inside the home-lab repository." >&2
    exit 1
  fi
  cd "$top/$d"
  if ! git rev-parse --verify --quiet HEAD:./secrets.sops.yaml >/dev/null; then
    echo "Stopping: secrets.sops.yaml is not committed. Generate and commit it as issue 19 describes." >&2
    exit 1
  fi
  if test -n "$(git status --porcelain --untracked-files=no -- metadata.env patches nodes secrets.sops.yaml)"; then
    echo "Stopping: metadata.env, patches, nodes or secrets.sops.yaml has uncommitted changes. Configs come only from committed files." >&2
    exit 1
  fi
  if test -L secrets; then
    echo "Stopping: secrets is a symbolic link. The plaintext is written only inside this directory." >&2
    exit 1
  elif test -e secrets && ! test -d secrets; then
    echo "Stopping: secrets is not a directory. The plaintext is written to secrets/secrets.yaml, so secrets must be a directory." >&2
    exit 1
  elif test -L secrets/secrets.yaml; then
    echo "Stopping: secrets/secrets.yaml is a symbolic link. The plaintext is written only to a regular file inside this directory." >&2
    exit 1
  elif test -d secrets/secrets.yaml; then
    echo "Stopping: secrets/secrets.yaml is a directory. The plaintext is written only to a regular file inside this directory." >&2
    exit 1
  fi
  t="$(mktemp -d)"
  git -C "$top" archive -o "$t/in.tar" "HEAD:$d" metadata.env patches nodes secrets.sops.yaml
  tar -x -C "$t" -f "$t/in.tar"
  source "$t/metadata.env"
  if ! talosctl version --client --short | grep -qxF "Talos $TALOS_VERSION"; then
    echo "Stopping: talosctl is not $TALOS_VERSION, the version metadata.env pins. Install that version first." >&2
    exit 1
  fi
  mkdir -p secrets
  new="$(mktemp secrets/.secrets.yaml.XXXXXX)"
  if ! sops --decrypt "$t/secrets.sops.yaml" >| "$new"; then
    rm -f "$new"
    echo "Stopping: the committed bundle did not decrypt with your age key. secrets/secrets.yaml was not changed." >&2
    exit 1
  fi
  mv -f "$new" secrets/secrets.yaml
  rm -rf generated
  talosctl gen config home-prod "$CLUSTER_ENDPOINT" \
    --with-secrets secrets/secrets.yaml \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --config-patch @"$t/patches/all-nodes.yaml" \
    --config-patch-control-plane @"$t/patches/control-plane.yaml" \
    --output-types controlplane,talosconfig \
    --output generated
  for n in cp-01 cp-02 cp-03; do
    talosctl machineconfig patch generated/controlplane.yaml \
      --patch @"$t/nodes/$n.yaml" --output generated/$n.yaml
    talosctl validate --config generated/$n.yaml --mode metal --strict
  done
  talosctl --talosconfig generated/talosconfig config endpoint "$CP_01_IP" "$CP_02_IP" "$CP_03_IP"
  rm -rf "$t"
)
```
<!-- talos-generate-configs:end -->

The block removes `generated/` before it generates, so nothing stale is reused. Run again, it gives byte-identical machine configs; only `talosconfig` differs, because each run issues a new client certificate. The `talosctl` endpoints it sets are the node IPs, not the VIP ([ADR-006](../../../../docs/adr/006-use-talos-vip-for-kubernetes-api-endpoint.md)).

## Patch Readiness Warning

The patches are ready to generate configs from, within these limits:

- Talos discovery is done on all three machines, and what it found is in `metadata.env`. The versions are pinned there too ([ADR-009](../../../../docs/adr/009-pin-versions-and-image-factory-schematic.md)).
- The block validates each node's config with `talosctl validate --mode metal --strict`, and stops unless `talosctl` reports the `TALOS_VERSION` that `metadata.env` pins.
- **Stop point:** don't generate configs from the cluster's real secrets until the stop point in the [repository README](../../../../README.md#current-status) allows it.
- **The install erases the selected disk, whatever `provisioning.wipe` says.** The generated config's `wipe: false` does not keep the disk's contents.
- Validation can't show what only the machines can: that the alias `lan0` matches the live port, that the static address and the VIP come up on it, which node holds the VIP, the live disk list, NTS time sync over the network, and Cilium. [Issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) (install day) and [issue 26](https://github.com/Okja-Engineering/home-lab/issues/26) check them on the machines.
