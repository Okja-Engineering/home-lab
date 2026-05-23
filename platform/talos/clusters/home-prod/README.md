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

## Bootstrap Commands

### Step 1: Boot first node and confirm hardware

```bash
# Boot cp-01 from Talos ISO, then set its IP
export CP_01_IP=192.168.1.21

# Confirm interface name (note the primary NIC with DHCP address)
talosctl get --insecure --nodes $CP_01_IP links

# Confirm install disk (identify the 1TB NVMe, not USB installer)
talosctl get --insecure --nodes $CP_01_IP disks
```

### Step 2: Create DNS record

Create an A record in your home DNS:
```
k8s.lab.home.arpa -> 192.168.1.21
```

### Step 3: Generate secrets and machine configs

```bash
# Navigate to cluster directory
cd platform/talos/clusters/home-prod

# Generate cluster secrets (first time only)
talosctl gen secrets -o secrets/secrets.yaml

# Generate machine configs
talosctl gen config "home-prod" "https://k8s.lab.home.arpa:6443" \
  --with-secrets secrets/secrets.yaml \
  --install-disk "/dev/nvme0n1" \
  --output-dir generated
```

### Step 4: Apply configs to control plane nodes

```bash
# Apply to cp-01
talosctl apply-config --insecure \
  --nodes 192.168.1.21 \
  --file generated/controlplane-1.yaml

# Apply to cp-02
talosctl apply-config --insecure \
  --nodes 192.168.1.22 \
  --file generated/controlplane-2.yaml

# Apply to cp-03
talosctl apply-config --insecure \
  --nodes 192.168.1.23 \
  --file generated/controlplane-3.yaml
```

### Step 5: Configure talosctl endpoints

```bash
# Set talosctl to use all control plane nodes
export TALOSAPI=192.168.1.21,192.168.1.22,192.168.1.23
```

### Step 6: Bootstrap cluster

```bash
# Bootstrap cluster (run once on first control plane node)
talosctl bootstrap --nodes 192.168.1.21

# Get kubeconfig
talosctl kubeconfig --nodes 192.168.1.21 > kubeconfig
```

## Notes

- Run bootstrap only once after all control plane nodes are configured
- Store `kubeconfig` securely, do not commit to Git
- Regenerate machine configs after modifying `metadata.env` or patches
- MAC addresses are documented locally for DHCP reservations, not committed to Git
- Network interface names must be confirmed via Talos before config generation
- Version pins are provisional - verify Talos/Kubernetes compatibility before use
