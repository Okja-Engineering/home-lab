# Workload Placement

Where workloads run and what may reach them: the worker roles, the candidate machines, the interim rules for the control plane, boot-image profiles, and the access and exposure invariants. It also holds the publication rules for all public text.

The rules here are proposed unless they cite a decision. Machine facts carry a "how known" label, and the owner's working plan is marked as such ([status words](adr/README.md#status-meanings)). This document assigns no machine to a role, and does not change [ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md) or [ADR-009](adr/009-pin-versions-and-image-factory-schematic.md).

## Order of Work

The owner set the rule on 2026-10-14: worker placement, storage selection and any request to erase a disk follow the evidence of a non-destructive inventory and the workload requirements. The proposed steps for the workers in Phase 3 ([Goals](00-goals.md#phases)):

1. Inventory each candidate machine, and the storage of about 8 TB, without changing them ([checklist](#pre-placement-inventory)).
2. Write down what each worker role's workloads need, including which of them hold [important data](06-recovery-expectations.md#important-data).
3. On that evidence, confirm or change the [working plan](#candidate-machines): which machine fills which role, how workers get their addresses, and which [image profiles](#image-profiles) they use.
4. Install each worker only after the [owner's go to erase it](#pre-placement-inventory), with the [access and exposure invariants](#access-and-exposure-invariants) holding from its first boot.

## Worker Roles

A role is defined by what its workloads need, not by the machine that fills it; one machine may fill more than one role. The needs below are a starting point for step 2.

| Role | Runs | Needs | How many |
|---|---|---|---|
| Stateful | Databases, internal Git, storage-system replicas, and monitoring and log storage (proposed to move here from the stateless role, because it writes steadily to disk) | A disk for data, sized for what it will hold; wired Ethernet; memory for databases | Open. With one, stored data has no second copy in the cluster; replicated storage needs more than one |
| Stateless/platform | Platform controllers such as cert-manager, external-secrets and Flux; dashboards; applications that keep no data | CPU and memory; no data disk | At least one |
| GPU/inference | Model serving | An NVIDIA GPU with drivers that match its operating system; memory for the models; a local disk for model files | The GX10, in Phase 5. Whether this role is a Kubernetes worker is [open](adr/README.md#open-decisions); any other GPU waits for the inventory |

Metric and log collectors run on every node.

## Interim Control-Plane Policy

This section proposes how to make [ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md) concrete until its revisit at the first worker. With workers first, restoring the taint, the option ADR-008 set aside, is practical again; that choice belongs to the revisit ([open decisions](adr/README.md#open-decisions)).

### What Is Known and What Is Not

- **Discovered on 2026-10-13** ([issue 13](https://github.com/Okja-Engineering/home-lab/issues/13)): each control-plane machine has one internal disk ([`metadata.env`](../platform/talos/clusters/home-prod/metadata.env)), so etcd shares it with anything a workload stores on that node.
- **Decided by the owner on 2026-10-14:** each control-plane machine keeps its single disk, with no second disk for etcd (which the [etcd FAQ](https://etcd.io/docs/latest/faq/) suggests for a slow disk) and no hardware bought now. The [baseline](#safeguards) is recorded during the control plane's validation, and placement is revisited "if measurements justify it". On Talos v1.14 a custom etcd volume is honoured only when a node is provisioned ([Talos system volumes](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/storage-and-disk-management/disk-management/system)), so moving etcd means reinstalling; in the owner's words, "Reinstallation is a recovery procedure, not a reason to schedule unnecessary rebuilds."
- **Not decided:** any absolute rule such as "stateful workloads never run on the control plane". This policy uses limits and move-off triggers instead; a stricter rule is one of the options.

### Allowances

| Workload | On control-plane nodes |
|---|---|
| The cluster's own components: etcd, the API server, scheduler and controller manager, Cilium, CoreDNS | Always |
| Per-node agents, such as metric and log collectors | Yes, with requests and limits |
| Small platform controllers that keep no data, such as cert-manager and external-secrets | Allowed while no stateless/platform worker exists; on workers once one does |
| Workloads that write heavily to disk or keep data: databases, internal Git, monitoring storage, storage-system replicas | Not by default. One that runs here before a stateful worker exists keeps learning-class data only, and moves off at the first trigger |
| Reliance-class data | Never. Any exception is [open](adr/README.md#open-decisions), at ADR-008's revisit; no such data enters the cluster before the [gate](06-recovery-expectations.md#gate-ready-to-hold-important-workloads) |
| Model serving | No; it needs the GPU/inference role |

### Safeguards

1. **Requests and limits** on every workload on a control-plane node, as ADR-008 requires, enforced rather than assumed.
2. **Eviction order:** under memory pressure, applications are evicted before platform services.
3. **Reserved resources** for the system and the kubelet, sized after the baseline.
4. **Bounded retention:** monitoring or log data on a control-plane node has a time limit and a size limit. ADR-008 requires the bound; the numbers are open.
5. **A baseline during validation** (its timing: the owner, 2026-10-14): while the control plane is validated ([issue 26](https://github.com/Okja-Engineering/home-lab/issues/26)), before substantial workloads, record etcd's disk latency and each node's disk write latency, with the date and versions.

The Milestone 4 spec decides how safeguards 1 to 4 are enforced; the Milestone 3 spec decides which metrics the baseline reads.

### Move-Off Triggers

When one fires, the workloads it names move to a worker of the matching role, or are removed, and the reason is recorded. Thresholds are set from the baseline, within etcd's guidance.

1. etcd's fsync or commit latency (99th percentile) stays above its threshold.
2. etcd changes leader outside maintenance, or logs slow-disk warnings.
3. A control-plane node shows memory pressure or evicts pods, or its memory requests pass an agreed share of what it can allocate.
4. Free space on a control-plane disk falls below an agreed floor.
5. A workload needs to keep reliance-class data.
6. A worker of the matching role joins. This is also ADR-008's revisit point.

Until monitoring exists (Phase 3, after the workers), the triggers are checked by hand. After that, triggers 1 to 4 raise alerts.

## Candidate Machines

The control-plane machines' facts are in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env).

| Machine | Known so far | How known | Role in the working plan |
|---|---|---|---|
| GMKtec mini PC with an Intel Core i9 | An Intel Core i9 CPU | Stated by owner, 2026-10-14 | Stateless/platform worker |
| Larger tower | About 64 GB of memory and about 4 TB of storage | Stated by owner, 2026-10-14 | Stateful worker, mainly for its storage |
| Storage, about 8 TB | Enclosure and connection not known; it may be an external drive on the tower, which would serve it over the network | Stated by owner, 2026-10-14 | Shared storage or a backup target at first; the arrangement is proposed after inspection |
| UPS | Everything is on it | Stated by owner, 2026-10-13 | Model, capacity and shutdown signalling not known |
| ASUS GX10 | One owned. An Arm CPU and an NVIDIA GB10 chip with an integrated GPU ([ASUS specifications](https://www.asus.com/networking-iot-servers/desktop-ai-supercomputer/ultra-small-ai-supercomputers/asus-ascent-gx10/techspec/)) | Owned: stated by owner, 2026-10-14. Hardware: vendor specification | GPU/inference, in Phase 5 |

The working plan is the owner's starting placement (2026-10-14). Both machines may be able to fill other roles, so [step 3](#order-of-work) checks it against the evidence.

- On 2026-10-13 the owner also described a GMKtec with 64 GB of memory, and a machine with 64 GB of memory, an NVIDIA RTX 2080 Ti and 4 TB on two SSDs. Whether these are the Core i9 GMKtec and the tower, the inventory will show.
- A collaborator may contribute more memory for the tower, and a second GX10 may be bought together: possible future capacity, not owned hardware.

## Pre-Placement Inventory

**Nothing on a candidate machine is erased, repartitioned, reinstalled or reconfigured without the owner's explicit go for that machine.** This is the owner's rule (2026-10-14): "Do not infer permission to wipe anything." The owner's direction that day also "does not approve … hardware changes". Installing Talos takes over the whole install disk. This inventory only reads. Proposed: the go to erase is asked for at installation, and its dated record is kept in the issue that installs the machine.

For each candidate machine, record:

1. **Current use:** what runs on it, what depends on it, and whether it must keep running while the lab is built.
2. **Operating system,** whether its disks are encrypted, and whether the recovery key is in hand.
3. **Data that must be kept:** what on each disk the owner wants to keep, and whether any of it is the only copy.
4. **Disks:** each disk's type (NVMe, SATA or USB), size, model, partitions and filesystems, which one the machine boots from, and which must be detached or excluded before Talos is installed.
5. **CPU:** vendor, model, cores and threads, and architecture. Intel or AMD decides the microcode extension ([ADR-009](adr/009-pin-versions-and-image-factory-schematic.md)).
6. **Memory:** the total.
7. **GPU:** the model, if there is one.
8. **Network:** each Ethernet port's name, driver and maximum speed, and the speed it links at on the switch in use.
9. **Firmware:** UEFI or legacy boot, the Secure Boot state, and whether there is a one-time boot override.
10. **Power:** whether it is on the UPS.

For the storage of about 8 TB, also record what kind of device it is (its own enclosure, disks inside a machine, or an external drive); how it connects, and to which machine; its capacity, filesystem, any RAID, contents and free space; and what it depends on, including that machine's power. If it hangs off the stateful tower, it shares the tower's failures ([Recovery Expectations](06-recovery-expectations.md#live-storage-and-backups)).

### Reading a Machine Without Changing It

Read from the operating system already on the machine where possible. Booting the Talos ISO needs the owner's go for that machine and the [maintenance-mode invariant](#access-and-exposure-invariants), and never applies a configuration, which would install Talos over the disk. Changing firmware settings on a machine with an encrypted disk can require its recovery key. The Milestone 4 spec decides how.

### Where the Facts Are Recorded

Proposed. Before a machine joins, its recorded inventory is dated, labelled discovered and kept in two parts:

- **Public, in the inventory issue:** the checklist, except the private fields.
- **Private, off GitHub:** what personal data a disk holds, which data is the only copy, disk-encryption details, and the Secure Boot state. A recovery key is recorded only as "in hand: yes or no". Where this private record lives is [open](adr/README.md#open-decisions).

When a machine joins the cluster, its facts go into [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env), the one record of hardware facts ([issue 14](https://github.com/Okja-Engineering/home-lab/issues/14)), and the [Hardware Inventory](01-hardware-inventory.md) is filled from there ([issue 24](https://github.com/Okja-Engineering/home-lab/issues/24)).

## Publication Rules

This repository, its commit messages, and its pull request and issue text are public. What stays out of them:

- **The owner, 2026-10-13:** say "the ISP-supplied gateway"; never name the ISP, its gateway's brand or model, or its resolver addresses.
- **The owner, 2026-10-14, for network records:** "Keep screenshots and detailed network information private." Once checked, the public repository may record "a dated, sanitized summary of the policy and verification method—no gateway identity, public addresses, IPv6 prefixes, or screenshots."
- **The owner, 2026-10-14:** "Avoid publishing collaborator identities or sensitive network details, but leave room to document a deliberately public service hostname once its domain and publication are approved."
- **The owner's current direction, 2026-10-14:** no MAC addresses, serial numbers, hardware UUIDs, public addresses, IPv6 addresses (of every scope) or prefixes, collaborator identities, or unapproved public hostnames; the network-record terms above apply to all public text. Useful hardware facts that are not sensitive, and private IPv4 plans, are still documented.

## Image Profiles

[ADR-009](adr/009-pin-versions-and-image-factory-schematic.md) pins one Image Factory schematic, which fits the three identical control-plane machines. Whether later machines change that is an [open decision](adr/README.md#open-decisions). **Proposed:** a profile is defined by what the hardware requires, not by the type of machine: the system extensions, kernel arguments and machine-config settings it needs. A new machine reuses a profile when its requirements match. The Milestone 4 spec decides how profiles are built.

| Profile | What it adds | When |
|---|---|---|
| Intel CPU, no GPU in use | `siderolabs/intel-ucode` | Now: the control-plane schematic from [issue 17](https://github.com/Okja-Engineering/home-lab/issues/17). May fit Intel workers such as the Core i9 GMKtec, if its inventory needs nothing more |
| AMD CPU, no GPU in use | `siderolabs/amd-ucode`, in its own schematic or added to the Intel one (to be tested) | Only if an AMD machine joins |
| An NVIDIA GPU the cluster uses | NVIDIA driver and container-toolkit extensions matched to the Talos release, and the kernel-module settings the [Talos NVIDIA guide](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/hardware-and-drivers/nvidia-gpu-proprietary) gives | Only if a GPU is used in the cluster, after the inventory |
| The GX10 (arm64, NVIDIA GB10) | The NVIDIA extensions and the kernel settings the Talos NVIDIA guide gives for the GB10. The Milestone 7 spec decides how | Only if the GX10 becomes a Talos node (open, Phase 5) |

Storage that needs host extensions, such as Longhorn ([Longhorn on Talos](https://longhorn.io/docs/latest/advanced-resources/os-distro-specific/talos-linux-support/)), needs them on every node that may run a pod using it; with workloads on the control plane, that means a new control-plane schematic and a rolling upgrade. Each profile is rebuilt and tested at every Talos upgrade ([issue 28](https://github.com/Okja-Engineering/home-lab/issues/28)), so fewer profiles means less upgrade work.

## Access and Exposure Invariants

What must hold for every lab host and service. Criteria cite these and record the evidence; how each is checked belongs to the issue that checks it. Proposed unless marked as the owner's.

1. **Selected entry points only** (the owner, 2026-10-14). Public access exposes selected application entry points; Talos, Kubernetes administration, storage management and the inference backends stay behind controlled boundaries.
2. **Every exposure check is an allowlist.** It shows that what answers is exactly the intended list, at the layer where services share an address: the port, then the hostname or route. It covers every address of every lab host and service, over IPv4 and IPv6: the hosts' LAN IPv4 addresses, their IPv6 addresses of every enabled scope, the shared VIP, LoadBalancer addresses, and the public IPv4 address through the ISP-supplied gateway. The owner decided on 2026-10-14 to keep host IPv6 for now, with the access policy covering every enabled scope; disabling it is not an automatic bootstrap change, and if that filtering cannot be established, the install uses a verified isolated network.
3. **Firewall defaults.** Management boundaries block by default, with no any-source allowance on either family, and keep node-to-node and in-cluster API traffic working ([ADR-013](adr/013-define-management-access-boundaries.md)). Management is from the home network only, initially (the owner, 2026-10-14), meaning no remote access; the management sources are explicitly listed machines, not the whole network.
4. **Maintenance mode** (the owner, 2026-10-14, except where marked otherwise). Talos behaviour ([the insecure flag](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/system-configuration/insecure); [the listen address](https://github.com/siderolabs/talos/blob/v1.14.2/internal/app/machined/pkg/controllers/runtime/maintenance_config.go#L102-L104)): in maintenance mode, Talos accepts a configuration on port 50000 without authentication, on every address. Before the next maintenance-mode boot, without waiting for [issue 29](https://github.com/Okja-Engineering/home-lab/issues/29), confirm that port 50000 is unreachable from outside the home over IPv4 and IPv6, with the ISP-supplied gateway's exceptions and forwarding rules checked (port forwards, DMZ, UPnP, IPv6 pinholes), and again before each later ISO boot. This document reads that check as the outside half of "Verify maintenance-mode isolation before ISO boots", and the home network as the other half, at the end of this item. If the result is uncertain, the finding stays private and the install uses a verified isolated network. Being present is not protection. A public record of the check follows the [rules for network records](#publication-rules) and says whether the ISP-supplied gateway is "configured to block unsolicited inbound traffic" or "externally tested and blocked". This document's reading: until issue 29 enforces the Talos firewall, installed nodes rely on the same inbound policy, and inside the home any device can reach a machine in maintenance mode. The owner decided on 2026-10-14 how that is handled, per machine. On the three control-plane machines, which are empty, that exposure to other home devices while each is in maintenance mode for its install is accepted deliberately: the outside check above comes first, and the window is kept short. Being present is still not protection; this is a deliberate acceptance of the risk. Each worker candidate is inventoried from its existing operating system, and at its install, after the owner's go to erase it, the owner decides between that accepted window and a verified isolated install network.
5. **In-cluster admin surfaces** (storage UIs, dashboards, internal admin endpoints) refuse devices that are not management sources, over IPv4 and IPv6. The Talos firewall "doesn't affect the traffic between the Kubernetes pods/services" ([Talos ingress firewall](https://docs.siderolabs.com/talos/v1.14/networking/ingress-firewall)), so this boundary is set inside the cluster ([open decision](adr/README.md#open-decisions)). The model gateway accepts only authenticated or allowed callers.
