# home-prod

Talos Linux cluster configuration for home production environment.

## Cluster Details

- **Name**: home-prod
- **Domain**: lab.home.arpa
- **Control Plane Nodes**: 3
- **Endpoint**: k8s.lab.home.arpa

## Node IPs

- cp-01: 192.168.1.21
- cp-02: 192.168.1.22
- cp-03: 192.168.1.23

## Configuration

- **Install Disk**: /dev/nvme0n1 (confirm with talosctl)
- **Metadata**: See `metadata.env`
- **Patches**: See `patches/` directory

## Bootstrap Plan

The bootstrap process transforms bare GMKtec mini PCs into a Talos Kubernetes control plane. This is a high-level plan; detailed execution steps are in the cp-01 runbook.

### Prerequisites

- Workstation has talosctl and kubectl installed
- 3x GMKtec mini PCs are available
- TP-Link Omada switch is available (configuration not required)
- Router access for DHCP reservations and DNS

### Phase 1: Hardware Preparation

- Configure BIOS/UEFI settings on all 3 nodes (secure boot off, virtualization enabled)
- Create Talos bootable USB media
- Boot cp-01 from Talos ISO
- Confirm hardware (interface names, disk paths)

### Phase 2: Network Preparation

- Create DHCP reservations for cp-01 (192.168.1.21), cp-02 (192.168.1.22), cp-03 (192.168.1.23)
- Create DNS A record: k8s.lab.home.arpa → 192.168.1.21
- Verify network connectivity from workstation to nodes

### Phase 3: Configuration Generation

- Generate Talos secrets bundle (store securely, not in Git)
- Generate machine configs using talosctl gen config with patches
- Review generated configs for correctness

### Phase 4: Config Application

- Apply machine config to cp-01
- Apply machine config to cp-02
- Apply machine config to cp-03
- Verify all nodes are in maintenance mode

### Phase 5: Cluster Bootstrap

- Bootstrap cluster on cp-01 (run once)
- Retrieve kubeconfig (store securely, not in Git)
- Verify cluster health via kubectl

### Validation Gates

- After Phase 1: Hardware confirmed on cp-01
- After Phase 2: DHCP reservations working, DNS resolving
- After Phase 3: Generated configs reviewed
- After Phase 4: All nodes in maintenance mode
- After Phase 5: kubectl can access cluster

See [docs/runbooks/cp-01-talos-bootstrap.md](../../../docs/runbooks/cp-01-talos-bootstrap.md) for detailed execution steps.

## Notes

- Run bootstrap only once after all control plane nodes are configured
- Store `kubeconfig` securely, do not commit to Git
- Regenerate machine configs after modifying `metadata.env` or patches
- MAC addresses are documented locally for DHCP reservations, not committed to Git
- Network interface names must be confirmed via Talos before config generation
- Version pins are provisional - verify Talos/Kubernetes compatibility before use
