# cp-01 Talos Bootstrap Runbook

This runbook provides detailed execution steps for bootstrapping cp-01, the first control plane node in the home-prod cluster.

**Purpose:** Transform a bare GMKtec mini PC into a Talos Linux control plane node.

**Scope:** This runbook covers cp-01 discovery, hardware confirmation, network preparation, and initial bootstrap. cp-02 and cp-03 are addressed in separate runbooks after cp-01 is stable.

**Prerequisites:**
- Workstation has talosctl and kubectl installed
- GMKtec mini PC (cp-01) is available
- Router access for DHCP reservations and DNS
- TP-Link Omada switch is available (configuration not required)

---

## Stop Point for Issue #13 / cp-01 Discovery

**For Issue #13 (cp-01 Talos Discovery), stop after Part 1 (Discovery and Hardware Confirmation).**

**Do not proceed to:**
- Secrets generation (Part 3)
- Machine config generation (Part 3)
- Config application (Part 4)
- Kubernetes bootstrap (Part 5)
- Kubeconfig retrieval (Part 5)
- Kubernetes validation (Part 5)

Parts 2 and later are future steps. Complete discovery first, then update metadata with confirmed values before generating secrets or configs.

---

## Part 1: Discovery and Hardware Confirmation

**Goal:** Confirm cp-01 hardware, network interface, and disk before proceeding with configuration.

### Step 1: Workstation Prerequisites

Install required tools on your workstation:

```bash
# Install talosctl (macOS)
brew install talosctl

# Install kubectl (macOS)
brew install kubectl

# Verify installations
talosctl version
kubectl version --client
```

**Do not proceed until:** talosctl and kubectl are installed and working.

### Step 2: BIOS/UEFI Configuration

Power on cp-01 and enter BIOS/UEFI setup (typically F2, F10, or Del during boot).

Configure the following settings:

- **Secure Boot:** Disabled
- **Virtualization:** Enabled (VT-x/AMD-V)
- **Boot Order:** USB drive first, then NVMe
- **Network Boot:** Disabled (not needed for initial setup)

**Do not proceed until:** BIOS/UEFI settings are confirmed.

### Step 3: Create Talos Bootable USB

**Use the pinned versions.** The Talos, Kubernetes and Cilium versions, the Image Factory schematic ID, the ISO URL and the installer image are pinned in [`metadata.env`](../../platform/talos/clusters/home-prod/metadata.env) ([ADR-009](../adr/009-pin-versions-and-image-factory-schematic.md)). Read them from there; do not pick a version here.

- `talosctl` on the workstation must be the pinned release: the `Tag` line of `talosctl version --client` must equal `TALOS_VERSION`.
- Download the ISO from `TALOS_ISO_URL` and use that same file for all three nodes. Image Factory builds it from `platform/talos/image/schematic.yaml`.

The first time, run a, b and c. For each later USB drive (cp-02, cp-03, or a new drive), run a and c. The drive is written only if the file matches the recorded checksum.

**a. Every time.** In a terminal at the repository root, read the pins, check `talosctl`, and name the ISO file after the Talos version and the schematic ID. The name keeps it apart from the stock `metal-amd64.iso` used for discovery. The second line prints the `Tag` line only if `talosctl` is the pinned release; if it prints nothing, stop and install that release. If `source` did not set the pins, the lines that use them fail with `run source first`: stop there.

```bash
source platform/talos/clusters/home-prod/metadata.env
talosctl version --client | grep -E "Tag: +${TALOS_VERSION:?run source first}$"
ISO="$HOME/Downloads/talos-${TALOS_VERSION:?run source first}-${TALOS_SCHEMATIC_ID:?run source first}.iso"
echo "$ISO"
```

**b. First time, or if the file is gone.** Download the ISO and print its SHA-256. If the download fails, `curl` exits with an error and no checksum is printed. The first time only, record the 64-character value in `docs/runbooks/cp-01-talos-bootstrap.md`: replace `not recorded yet` in block c with it, and commit that change to the repository. If block c later reports the file missing (`FAILED open or read`), it has written nothing: run b again, then c, which checks the new download against the recorded value. Never replace a recorded value.

```bash
curl -fL -o "$ISO" "${TALOS_ISO_URL:?run source first}" && shasum -a 256 "$ISO"
```

**c. Each USB drive.** Run `diskutil list` on its own and find the USB drive's header, `/dev/diskN (external, physical):`. Its row `0:` shows the drive's size and ends with the identifier to use, such as `disk4`: copy that, without `/dev/`, and not a `disk4s1` row. Copy the block below, put the identifier between the quotes on its first line, then run it; it erases that drive. The drive is unmounted and written only if `shasum` prints `OK` and then `diskutil list` prints that same header for `USB_DISK`, which a partition, an internal disk or a disk image does not; while no checksum is recorded, the check fails.

```bash
USB_DISK=""
ISO_SHA256="not recorded yet"
echo "$ISO_SHA256  $ISO" | shasum -a 256 -c &&
diskutil list "/dev/${USB_DISK:?set it to the USB drive from diskutil list}" | grep -Fx "/dev/$USB_DISK (external, physical):" &&
diskutil unmountDisk "/dev/$USB_DISK" &&
sudo dd if="$ISO" of="/dev/r$USB_DISK" bs=1m
```

**Do not proceed until:** the ISO's SHA-256 is recorded in block c, and block c printed `OK` and wrote the USB drive.

### Step 4: Boot cp-01 from Talos ISO

1. Insert the Talos bootable USB into cp-01
2. Power on cp-01
3. Select the USB drive from the boot menu
4. Talos should boot to a maintenance console

**Do not proceed until:** cp-01 is booted from Talos ISO and shows the maintenance console.

### Step 5: Confirm Network Interface

Identify the primary network interface and confirm DHCP assignment:

```bash
# Set cp-01 IP (use the DHCP-assigned address shown in Talos console)
export CP_01_IP=10.0.0.21

# Confirm interface names
talosctl get --insecure --nodes $CP_01_IP links

# Look for the interface with a DHCP-assigned IP
# Note the interface name (e.g., eth0, enp1s0)
```

**Expected output:** One interface should show a DHCP-assigned IP address.

**Do not proceed until:** Primary network interface is identified and has a DHCP address.

### Step 6: Confirm Install Disk

Identify the NVMe drive that will be used for Talos installation:

```bash
# List disks
talosctl get --insecure --nodes $CP_01_IP disks

# Look for the 1TB NVMe drive (not the USB installer)
# Note the device path (e.g., /dev/nvme0n1)
```

**Expected output:** One NVMe drive should be visible (typically 1TB). The USB installer should also be visible but should not be selected.

**Do not proceed until:** Install disk is identified and confirmed to be the NVMe drive.

### Step 7: Document Discovery Findings

Update the hardware inventory with discovered values:

- **Network interface name:** (e.g., eth0)
- **Install disk path:** (e.g., /dev/nvme0n1)
- **MAC address:** (optional, for DHCP reservation)

**Do not proceed until:** Discovery findings are documented.

---

## Part 2: Network Preparation

**Goal:** Configure DHCP reservation and DNS for cp-01.

### Step 8: Create DHCP Reservation

Access your router or Omada controller and create a static DHCP reservation:

- **MAC address:** (from Step 7)
- **IP address:** 10.0.0.21
- **Hostname:** cp-01

**Verification:** Reboot cp-01 and confirm it receives 10.0.0.21.

```bash
# After reboot, confirm IP address
talosctl get --insecure --nodes 10.0.0.21 links
```

**Do not proceed until:** DHCP reservation is working and cp-01 has 10.0.0.21.

### Step 9: Create DNS Record

Create an A record in your home DNS:

- **Name:** k8s.lab.home.arpa
- **IP:** 10.0.0.21

**Verification:** From your workstation, test DNS resolution:

```bash
# Test DNS resolution
nslookup k8s.lab.home.arpa
# or
dig k8s.lab.home.arpa
```

**Do not proceed until:** DNS record is created and resolving to 10.0.0.21.

### Step 10: Verify Network Connectivity

Confirm your workstation can reach cp-01:

```bash
# Ping test
ping -c 3 10.0.0.21

# Talos API test
talosctl get --insecure --nodes 10.0.0.21 links
```

**Do not proceed until:** Network connectivity is confirmed from workstation to cp-01.

---

## Part 3: Configuration Generation

**Goal:** Generate Talos secrets and machine configs.

**STOP POINT:** If this is your first execution, stop here and review the discovered values before generating configs. Update `platform/talos/clusters/home-prod/metadata.env` with confirmed interface name and disk path.

### Step 11: Update Metadata

Update `platform/talos/clusters/home-prod/metadata.env` with discovered values:

```bash
# Edit metadata.env
cd platform/talos/clusters/home-prod
nano metadata.env

# Update these fields with discovered values:
# NETWORK_INTERFACE="eth0"  # from Step 5
# INSTALL_DISK="/dev/nvme0n1"  # from Step 6
```

**Do not proceed until:** metadata.env is updated with confirmed values.

### Step 12: Generate Talos Secrets

Generate the Talos secrets bundle:

```bash
# Navigate to cluster directory
cd platform/talos/clusters/home-prod

# Generate secrets bundle
talosctl gen secrets -o secrets/secrets.yaml

# IMPORTANT: Store secrets/secrets.yaml securely, not in Git
# This file contains cluster root material
```

**Do not proceed until:** Secrets bundle is generated and stored securely.

### Step 13: Generate Machine Configs

Generate machine configs using the secrets and patches:

```bash
# Generate machine configs
talosctl gen config "home-prod" "https://k8s.lab.home.arpa:6443" \
  --with-secrets secrets/secrets.yaml \
  --install-disk "/dev/nvme0n1" \
  --output-dir generated

# Review generated configs
ls generated/
```

**Do not proceed until:** Machine configs are generated and reviewed for correctness.

---

## Part 4: Config Application

**Goal:** Apply machine config to cp-01.

### Step 14: Apply Config to cp-01

Apply the control plane machine config to cp-01:

```bash
# Apply config to cp-01
talosctl apply-config --insecure \
  --nodes 10.0.0.21 \
  --file generated/controlplane-1.yaml
```

**Expected output:** Talos will apply the config and reboot the node.

### Step 15: Verify cp-01 in Maintenance Mode

After reboot, verify cp-01 is in maintenance mode:

```bash
# Check node status
talosctl get --insecure --nodes 10.0.0.21 members

# Expected: cp-01 should show as "MEMBERSHIP_JOINED" or similar
```

**Do not proceed until:** cp-01 is in maintenance mode and responding to Talos API.

---

## Part 5: Cluster Bootstrap

**Goal:** Bootstrap the Kubernetes cluster on cp-01.

**NOTE:** Do not proceed to this step until cp-02 and cp-03 are also configured and in maintenance mode. The bootstrap should only run once after all 3 control plane nodes are ready.

### Step 16: Bootstrap Cluster

Bootstrap the Kubernetes cluster (run once on cp-01):

```bash
# Bootstrap cluster
talosctl bootstrap --nodes 10.0.0.21
```

**Expected output:** Talos will initialize etcd and start Kubernetes control plane components.

### Step 17: Retrieve Kubeconfig

Retrieve the Kubernetes admin kubeconfig:

```bash
# Get kubeconfig
talosctl kubeconfig --nodes 10.0.0.21 > kubeconfig

# IMPORTANT: Store kubeconfig securely, not in Git
# This file grants admin access to the cluster
```

### Step 18: Verify Cluster Health

Verify the cluster is healthy:

```bash
# Set kubeconfig
export KUBECONFIG=kubeconfig

# Check nodes
kubectl get nodes

# Expected: cp-01 should be Ready
```

**Do not proceed until:** kubectl can access the cluster and cp-01 is Ready.

---

## Validation Gates

- **After Part 1:** Hardware confirmed (interface, disk, MAC)
- **After Part 2:** DHCP reservation working, DNS resolving, connectivity confirmed
- **After Part 3:** metadata.env updated, secrets generated securely, configs reviewed
- **After Part 4:** cp-01 in maintenance mode
- **After Part 5:** kubectl can access cluster, cp-01 is Ready

---

## Notes

- This runbook is discovery-focused for the first execution
- Stop after Part 2 to review findings before generating configs
- Update metadata.env with confirmed values before Part 3
- Bootstrap should only run once after all 3 control plane nodes are configured
- Store secrets/secrets.yaml and kubeconfig securely, not in Git
- Do not commit generated machine configs to Git
- MAC addresses are optional but useful for DHCP reservations
- Versions are pinned in metadata.env - use those versions

---

## Next Steps

After cp-01 is bootstrapped and healthy:

1. Proceed to cp-02 bootstrap runbook
2. Proceed to cp-03 bootstrap runbook
3. Verify 3-node etcd quorum
4. Install Cilium CNI
5. Configure ingress controller
