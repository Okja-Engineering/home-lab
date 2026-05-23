# Three-Node Control Plane Bootstrap Runbook

This runbook documents the path from one validated Talos node to three healthy control-plane nodes in the home-prod cluster.

**Purpose:** Safely scale from a single validated cp-01 to a full three-node Talos Kubernetes control plane with etcd quorum.

**Scope:** This runbook covers cp-02/cp-03 preparation, config application sequence, Kubernetes bootstrap, etcd health validation, and basic recovery notes.

---

## Scope

### In Scope

- cp-02 and cp-03 hardware and network preparation
- Applying Talos configs to all three control-plane nodes
- Kubernetes bootstrap (run once)
- etcd health validation
- kubectl validation
- Basic recovery notes

### Out of Scope

- Cilium CNI installation
- Flux/GitOps
- Application deployment
- Storage configuration
- VLAN implementation
- Worker nodes
- Advanced platform services

---

## Preconditions

Before proceeding with this runbook, ensure the following are complete:

- **cp-01 discovery completed:** Hardware, network interface, disk path confirmed via cp-01 runbook
- **cp-01 hardware/network/disk/interface values confirmed:** Documented in metadata.env
- **DHCP reservations exist for all three nodes:**
  - cp-01: 192.168.1.21
  - cp-02: 192.168.1.22
  - cp-03: 192.168.1.23
- **DNS record exists:** k8s.lab.home.arpa → 192.168.1.21
- **Talos/Kubernetes version compatibility verified:** See metadata.env for version pins
- **Secrets storage location selected:** Outside Git, secure location for secrets/secrets.yaml
- **Generated configs are ignored:** .gitignore protects generated/ directory
- **Workstation tools installed:** talosctl and kubectl available

**Do not proceed until:** All preconditions are satisfied.

---

## cp-02 and cp-03 Preparation

Prepare cp-02 and cp-03 following the same process used for cp-01.

### Hardware Preparation

For each node (cp-02, cp-03):

1. **BIOS/UEFI Configuration**
   - Secure Boot: Disabled
   - Virtualization: Enabled (VT-x/AMD-V)
   - Boot Order: USB drive first, then NVMe
   - Network Boot: Disabled

2. **Create Talos Bootable USB**
   - Use the same Talos ISO as cp-01
   - Create bootable USB drive (same process as cp-01 runbook)

3. **Boot from Talos ISO**
   - Insert USB and boot node
   - Confirm Talos maintenance console is accessible

### Network Preparation

For each node (cp-02, cp-03):

1. **Confirm Network Interface**
   ```bash
   # Set node IP
   export CP_02_IP=192.168.1.22  # or CP_03_IP=192.168.1.23
   
   # Confirm interface names
   talosctl get --insecure --nodes $CP_02_IP links
   ```

   **Expected:** Interface name matches cp-01 (e.g., eth0)

2. **Confirm Install Disk**
   ```bash
   # List disks
   talosctl get --insecure --nodes $CP_02_IP disks
   ```

   **Expected:** NVMe drive visible (typically 1TB)

3. **Verify DHCP Reservation**
   - Reboot node
   - Confirm it receives the reserved IP (192.168.1.22 or 192.168.1.23)
   - Test connectivity from workstation

4. **Document MAC Addresses**
   - Note MAC address for each node
   - Store locally or in router only
   - **Do not commit MAC addresses to Git**

**Do not proceed until:** cp-02 and cp-03 hardware and network are confirmed.

---

## Config Generation Checkpoint

Generate Talos secrets and machine configs once, then apply to all three nodes.

### Generate Secrets Bundle

Generate the Talos secrets bundle (if not already done for cp-01):

```bash
# Navigate to cluster directory
cd platform/talos/clusters/home-prod

# Generate secrets bundle (only once)
talosctl gen secrets -o secrets/secrets.yaml

# IMPORTANT: Store secrets/secrets.yaml securely, not in Git
# This file contains cluster root material
```

**Do not proceed until:** Secrets bundle is generated and stored securely.

### Generate Machine Configs

Generate machine configs using the secrets bundle and patches:

```bash
# Generate machine configs
talosctl gen config "home-prod" "https://k8s.lab.home.arpa:6443" \
  --with-secrets secrets/secrets.yaml \
  --install-disk "/dev/nvme0n1" \
  --output-dir generated

# Review generated configs
ls generated/
# Expected: controlplane-1.yaml, controlplane-2.yaml, controlplane-3.yaml, etc.
```

**Review generated configs:**
- Verify install disk matches discovered values
- Verify network interface matches discovered values
- Verify cluster endpoint is correct
- Verify no sensitive values are accidentally committed

**Do not proceed until:** Machine configs are generated and reviewed for correctness.

**Important:** Never commit secrets/secrets.yaml or generated/ directory contents to Git.

---

## Config Application Sequence

Apply machine configs to all three control plane nodes in sequence.

### Apply Config to cp-01

```bash
# Apply config to cp-01
talosctl apply-config --insecure \
  --nodes 192.168.1.21 \
  --file generated/controlplane-1.yaml
```

**Expected:** Talos will apply the config and reboot cp-01.

**Stop/Go Gate:** Wait for cp-01 to reboot and respond to Talos API.

```bash
# Verify cp-01 is in maintenance mode
talosctl get --insecure --nodes 192.168.1.21 members
```

**Do not proceed until:** cp-01 is in maintenance mode and responding.

### Apply Config to cp-02

```bash
# Apply config to cp-02
talosctl apply-config --insecure \
  --nodes 192.168.1.22 \
  --file generated/controlplane-2.yaml
```

**Expected:** Talos will apply the config and reboot cp-02.

**Stop/Go Gate:** Wait for cp-02 to reboot and respond to Talos API.

```bash
# Verify cp-02 is in maintenance mode
talosctl get --insecure --nodes 192.168.1.22 members
```

**Do not proceed until:** cp-02 is in maintenance mode and responding.

### Apply Config to cp-03

```bash
# Apply config to cp-03
talosctl apply-config --insecure \
  --nodes 192.168.1.23 \
  --file generated/controlplane-3.yaml
```

**Expected:** Talos will apply the config and reboot cp-03.

**Stop/Go Gate:** Wait for cp-03 to reboot and respond to Talos API.

```bash
# Verify cp-03 is in maintenance mode
talosctl get --insecure --nodes 192.168.1.23 members
```

**Do not proceed until:** cp-03 is in maintenance mode and responding.

### Verify All Nodes in Maintenance Mode

```bash
# Check all three nodes
talosctl get --insecure --nodes 192.168.1.21,192.168.1.22,192.168.1.23 members
```

**Expected:** All three nodes show as joined/maintenance mode.

**Do not proceed until:** All three nodes are in maintenance mode.

---

## Bootstrap Sequence

Bootstrap the Kubernetes cluster. This should only run once.

### Bootstrap Cluster

Bootstrap the Kubernetes cluster on cp-01:

```bash
# Bootstrap cluster (run once)
talosctl bootstrap --nodes 192.168.1.21
```

**Expected:** Talos will initialize etcd and start Kubernetes control plane components.

**Important:**
- Bootstrap should only run once
- Do not run bootstrap multiple times
- If bootstrap fails, investigate before retrying

### Wait for Control Plane Services to Settle

Allow time for control plane services to start and stabilize. This may take 1-2 minutes.

### Retrieve Kubeconfig

Retrieve the Kubernetes admin kubeconfig:

```bash
# Get kubeconfig
talosctl kubeconfig --nodes 192.168.1.21 > kubeconfig

# IMPORTANT: Store kubeconfig securely, not in Git
# This file grants admin access to the cluster
```

**Do not proceed until:** Kubeconfig is retrieved and stored securely.

---

## Validation Commands

Validate the health of the three-node control plane.

### Talos Health Checks

```bash
# Check Talos cluster health
talosctl health --nodes 192.168.1.21,192.168.1.22,192.168.1.23

# Check cluster members
talosctl get members --nodes 192.168.1.21

# Check etcd service
talosctl service etcd --nodes 192.168.1.21

# Check kubelet service
talosctl service kubelet --nodes 192.168.1.21

# Check kube-apiserver service
talosctl service kube-apiserver --nodes 192.168.1.21

# Check etcd health
talosctl etcd health --nodes 192.168.1.21
```

### Kubernetes Health Checks

```bash
# Set kubeconfig
export KUBECONFIG=kubeconfig

# Check nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A

# Check control plane components
kubectl get pods -n kube-system
```

**Expected:**
- All three nodes visible
- All three nodes in Ready state
- etcd healthy with quorum
- Control plane pods running
- No CNI pods expected yet (Cilium is deferred)

**Do not proceed until:** All validation commands show healthy state.

---

## Expected Healthy State

After successful three-node bootstrap, the cluster should be in the following state:

### Node State

- **cp-01 (192.168.1.21):** Ready, control plane
- **cp-02 (192.168.1.22):** Ready, control plane
- **cp-03 (192.168.1.23):** Ready, control plane

### etcd State

- **etcd quorum:** Healthy (3/3 members)
- **etcd leader:** Elected
- **etcd replication:** Working

### Kubernetes State

- **Kubernetes API:** Reachable
- **kubectl access:** Working
- **Control plane pods:** Running
- **CNI:** Not yet installed (Cilium deferred)
- **Flux:** Not yet installed (deferred)
- **Apps:** Not yet deployed (deferred)

---

## Basic Recovery Notes

### If One Node Fails Before Bootstrap

- Stop and fix the failed node before proceeding
- Do not apply configs to remaining nodes until all three are ready
- Common causes: Wrong disk, wrong interface, DHCP reservation issue

### If DHCP Reservation is Wrong

- Stop and fix networking in router or Omada controller
- Reboot affected node
- Verify IP address is correct
- Re-apply config if necessary

### If Install Disk Differs

- Stop and update metadata.env with correct disk path
- Regenerate machine configs
- Re-apply config to affected node

### If Bootstrap Was Accidentally Run Twice

- Stop and investigate
- Check etcd health
- If etcd is corrupted, may need to wipe and reinstall
- Do not proceed to platform services until etcd is healthy

### If etcd Health is Bad

- Do not proceed to platform services
- Investigate etcd logs
- Check for network partition
- May need to recover from backup or reinstall
- See Talos documentation for etcd recovery procedures

### Do Not Reset/Wipe Nodes Casually

- Document what happened before wiping
- Wiping destroys data and requires re-installation
- Only wipe as last resort
- Consider etcd backup/restore first

---

## Completion Criteria

This runbook is complete when:

- cp-01, cp-02, and cp-03 have Talos configs applied
- Kubernetes has been bootstrapped once
- Kubeconfig retrieved and stored securely
- kubectl access works
- etcd health is validated (3/3 members healthy)
- All three nodes are Ready
- Issue #10 can be closed

---

## Links

- [cp-01 Talos Bootstrap Runbook](cp-01-talos-bootstrap.md) - Detailed cp-01 discovery and bootstrap
- [platform/talos/clusters/home-prod/README.md](../../../platform/talos/clusters/home-prod/README.md) - Cluster configuration and high-level bootstrap plan
- [docs/02-network-plan.md](../02-network-plan.md) - Network topology and IP addressing
- [docs/03-cluster-design.md](../03-cluster-design.md) - Cluster architecture and scope

---

## Notes

- This runbook builds on the cp-01 runbook
- Configs should be generated once and applied to all three nodes
- Bootstrap should only run once
- etcd quorum requires 2/3 nodes to be healthy
- Cilium CNI is deferred until after control plane is healthy
- Flux/GitOps is deferred until after control plane is healthy
- Store secrets/secrets.yaml and kubeconfig securely, not in Git
- Do not commit generated machine configs to Git
- MAC addresses are optional but useful for DHCP reservations
- Version pins in metadata.env are provisional - verify compatibility before use

---

## Next Steps

After the three-node control plane is healthy:

1. Install Cilium CNI
2. Configure ingress controller
3. Set up storage classes
4. Implement Flux/GitOps
5. Deploy platform services (monitoring, logging)
