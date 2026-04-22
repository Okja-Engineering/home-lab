# home-lab

Talos Linux cluster configuration for home lab.

## Cluster Details

- **Name**: home-lab
- **Domain**: <DOMAIN>
- **Control Plane Nodes**: 3
- **Endpoint**: <CLUSTER_ENDPOINT>

## Node IPs

- CP01: <CP01_IP>
- CP02: <CP02_IP>
- CP03: <CP03_IP>

## Configuration

- **Install Disk**: <INSTALL_DISK>
- **Metadata**: See `metadata.env`
- **Patches**: See `patches/` directory

## Bootstrap Commands

### Step 1: Boot first node and confirm hardware

```bash
# Boot cp01 from Talos ISO, then set its IP
export CP01_IP=192.168.1.21

# Confirm interface name (note the primary NIC with DHCP address)
talosctl get --insecure --nodes $CP01_IP network

# Confirm install disk (identify the 1TB NVMe, not USB installer)
talosctl get --insecure --nodes $CP01_IP disks
```

### Step 2: Create DNS record

Create an A record in your home DNS:
```
k8s.lab.home.arpa -> 192.168.1.21
```

### Step 3: Generate secrets and machine configs

```bash
# Navigate to cluster directory
cd platform/talos/clusters/home-lab

# Generate cluster secrets (first time only)
talosctl gen secrets -o secrets/secrets.yaml

# Generate machine configs
talosctl gen config "home-lab" "https://k8s.lab.home.arpa:6443" \
  --with-secrets secrets/secrets.yaml \
  --install-disk "/dev/nvme0n1" \
  --output-dir generated
```

### Step 4: Apply configs to control plane nodes

```bash
# Apply to cp01
talosctl apply-config --insecure \
  --nodes 192.168.1.21 \
  --file generated/controlplane-1.yaml

# Apply to cp02
talosctl apply-config --insecure \
  --nodes 192.168.1.22 \
  --file generated/controlplane-2.yaml

# Apply to cp03
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
