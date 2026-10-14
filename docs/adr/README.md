# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the home lab project.

## What are ADRs?

ADRs are short documents that describe significant architectural decisions made in this project. Each ADR captures:

- The context for the decision
- The decision itself
- The impact of that decision
- What we are intentionally not doing yet

## Why this repo uses ADRs

This home lab is both an operational platform and a learning portfolio. ADRs help:

- Document the reasoning behind architectural choices
- Make it easier to revisit decisions later
- Provide a clear history of how the platform evolved
- Support learning by explaining trade-offs

## Status Meanings

An ADR has one of the first four. The other documents use these words for any choice:

- **Proposed:** The decision is being considered. Elsewhere: written down for review, not decided
- **Accepted:** The decision has been made and is being implemented. Elsewhere: decided by the owner, or in the text of an accepted ADR, and nothing else
- **Implemented:** The decision has been fully implemented
- **Superseded:** The decision has been replaced by a newer decision
- **Open:** Not decided. Each open choice is listed under [Open Decisions](#open-decisions) with its options
- **Deferred:** Decided not to do yet, by the owner, in an ADR's "Not Doing Yet", or as a [non-goal](../00-goals.md#non-goals)
- **Working plan:** The owner's starting assignment of machines to roles, which the inventory confirms or changes. It is not a decision, and not permission to erase anything

Older documents say "planned" or "deferred" to mean "later". Where the owner, an ADR or a non-goal settled the item, it has that status; otherwise read it as proposed.

A milestone's spec is its description and issue bodies on GitHub, as the owner approves them. A criterion the owner has merged or approved is accepted, even where it cites proposed text, such as an invariant or a gate's conditions; the cited text stays proposed until the owner approves spec text that quotes it, and is then accepted, in that form, for that milestone.

A hardware fact is **discovered** (read from the machine with a tool, and dated), **stated by owner** (from memory, not checked) or a **vendor specification** (published by the maker, not checked on this unit).

## ADR Index

| ADR | Title | Status | Summary |
|-----|-------|--------|---------|
| 001 | Use Talos Linux | Accepted | Use Talos Linux for Kubernetes nodes |
| 002 | Start with Flat Network | Accepted | Bootstrap on a simple flat network before VLANs |
| 003 | Use Three Control Plane Nodes | Accepted | Use three GMKtec mini PCs for HA control plane |
| 004 | Defer GitOps Until Control Plane is Healthy | Accepted | Defer Flux installation until cluster is stable |
| 005 | Use Cilium with kube-proxy Replacement from Bootstrap | Accepted | Install Cilium as the CNI during bootstrap, with Flannel and kube-proxy disabled |
| 006 | Use a Talos Shared VIP for the Kubernetes API Endpoint | Accepted | Serve the Kubernetes API endpoint from a Talos shared VIP |
| 007 | Configure Static Node Addresses in the Talos Machine Config | Accepted | Set static node addresses in the per-node Talos patches |
| 008 | Allow Workloads on Control-Plane Nodes | Accepted | Allow workloads to be scheduled on the three control-plane nodes |
| 009 | Pin Exact Versions and One Image Factory Schematic | Accepted | Pin exact Talos, Kubernetes, and Cilium versions and one Image Factory schematic |
| 010 | Store the Talos Secrets Bundle Encrypted with SOPS and age | Accepted | Commit the Talos secrets bundle encrypted with SOPS and age |
| 011 | Bootstrap Once on cp-01, Then Join cp-02 and cp-03 | Accepted | Run `talosctl bootstrap` once on cp-01, then join cp-02 and cp-03 |
| 012 | Use Cilium Gateway API for Ingress (Phase 3) | Accepted | Use Cilium's Gateway API for Phase 3 ingress |
| 013 | Define Management Access Boundaries Now; Enforce with the Talos Firewall Later | Accepted | Define allowed management sources now and enforce them with the Talos firewall later |
| 014 | Re-base the Address Plan onto 10.0.0.0/24 | Accepted | Move the planned addresses onto 10.0.0.0/24, the home network's subnet, keeping the host numbers and the design |
| 015 | Use vLLM for Local Inference | Accepted | Serve Phase 5 models with vLLM; the GX10's operating system, deployment path and models stay open |
| 016 | Use IPv4-Only Pod and Service Networking Initially | Accepted | Keep pod and Service networks IPv4-only for the bootstrap; serve future public IPv6 from a proxy or gateway in front of the cluster |

## Open Decisions

Choices the destination needs that have not been made. Where a document proposes an option, the row links it; when a choice is made, an ADR or the owner's dated decision records it, and its row goes. Milestone numbers are the proposed ones in [Goals](../00-goals.md#phases).

| Decision | Options | Needed by |
|---|---|---|
| Workloads on the control plane, at ADR-008's revisit | Keep [ADR-008](008-allow-workloads-on-control-plane-nodes.md) with the [proposed safeguards and move-off triggers](../05-workload-placement.md#interim-control-plane-policy); restore the control-plane taint (the option ADR-008 set aside); or the taint with named exceptions. Reliance-class data: never ([proposed](../05-workload-placement.md#allowances)), or named exceptions | The first worker (Milestone 4) |
| Addresses for workers and other hosts | Static in the Talos config ([ADR-007](007-configure-static-node-addresses.md)), or reserved in DHCP; fixed addresses for the GX10, the storage and later hosts beyond the six worker addresses ([ADR-014](014-rebase-address-plan-onto-10-0-0-0-24.md)) | Workers joining (Milestone 4) |
| Image profiles, revisiting ADR-009's one schematic | One per set of hardware requirements ([proposed](../05-workload-placement.md#image-profiles)); one per type of machine; or one for every machine | The first Talos node that is not a control-plane machine (Milestone 4) |
| Private inventory record | Where the [private inventory fields](../05-workload-placement.md#where-the-facts-are-recorded) are kept: a private document or repository, or a password manager; never this repository | The first inventory (Milestone 4) |
| VLANs and managed switching, revisiting ADR-002 | Flat on the unmanaged Netgear GS308, wired directly to the ISP-supplied gateway (the owner's bootstrap choice); or VLANs, needing a managed switch and a router or firewall between them. Phase 7 weighs in | [ADR-002](002-start-with-flat-network.md) suggests deciding when workers are added (Milestone 4) |
| Recovery access once the firewall is on | Which machine is the [recovery machine](../06-recovery-expectations.md#recovery-invariants), and its stable address. The owner prefers a second, explicitly listed management machine to a takeover of the workstation's address (2026-10-14) | Issue 25 (Milestone 2), before issue 29 enforces it |
| Arrangement of the storage of about 8 TB | Shared storage, a backup target, or both; attached to the tower and served over the network, or not ([what each shares](../06-recovery-expectations.md#live-storage-and-backups)) | Inspected in Milestone 4, decided in Milestone 5 |
| Recovery targets | Downtime and data-loss targets for each service, and the first applications | Each service that holds [important data](../06-recovery-expectations.md#important-data), when it is introduced |
| Persistent storage | local-path-provisioner, Longhorn, or NFS or iSCSI from network storage ([Cluster Design](../03-cluster-design.md#storage-design)), depending on the tower's disks, the 8 TB arrangement and the number of stateful workers. Some need [host extensions](../05-workload-placement.md#image-profiles) | Stateful services (Milestone 5) |
| Application backups | A tool, such as Velero or per-application dumps; a target [off the cluster](../06-recovery-expectations.md#recovery-invariants); an [independent copy](../06-recovery-expectations.md#live-storage-and-backups) of important data. No provider chosen | The [gate](../06-recovery-expectations.md#gate-ready-to-hold-important-workloads) (Milestone 5) |
| Monitoring stack and retention | Prometheus, Grafana and Loki ([Cluster Design](../03-cluster-design.md#cluster-components)); the retention limits [ADR-008](008-allow-workloads-on-control-plane-nodes.md) requires | The gate's alerts (Milestone 5) |
| In-cluster exposure | Which Services get LoadBalancer addresses or NodePorts (each LoadBalancer Service gets one), whether public and private routes share a Gateway, and the default network policy | The first platform service with a web UI (Milestone 5) |
| Application DNS and TLS | A private certificate authority, or a real domain with DNS-01 (certificates issued by proving control of the domain's DNS); records from the router's DNS, or automated | [Issue 30](https://github.com/Okja-Engineering/home-lab/issues/30) (Milestone 5) |
| Power loss and the UPS | Record the UPS and what a power cut does to the nodes; a clean shutdown on a signal from the UPS, or not | Milestone 5 |
| GitOps source and break-glass path | Flux pulls from GitHub, an internal Git service, or a mirror; the break-glass path (the emergency way in) when that source is down | Milestone 6 |
| Internal source control | Which service; what moves in-house and what stays on GitHub | Milestone 6 |
| GX10 deployment path and first models | A separate service on its vendor operating system; k3s (a small Kubernetes distribution) on it, as a second cluster; or a Talos node, chosen after the checks in Phase 5's first criterion | Milestone 7 |
| A second GX10 | If one is added: independent instances behind the model gateway, or distributed inference over a suitable high-speed interconnect, subject to verifying the hardware and deployment support. Distributed inference is an experiment to evaluate, not a promised performance improvement. Chosen on models, compatibility, measured performance and the experiment's goals | Milestone 7 (research) |
| Model gateway | Which gateway, and how it routes requests, holds API credentials, enforces quotas and falls back. Separate from Gateway API ingress ([ADR-012](012-use-cilium-gateway-api-for-ingress.md)) | Milestone 8 |
| Frontier data egress | What may be sent to hosted model providers, and where that is enforced | Milestone 8 |
| Phase 6 success measure | Quality, latency, cost, privacy, or a mix in a stated order | Milestone 8 |
| Domain | A domain we control, its spelling and ownership confirmed before any use; publishing a hostname follows the [publication rules](../05-workload-placement.md#publication-rules) | Public hostnames (Milestone 9); possibly issue 30's TLS |
| Public API gateway and accounts | Extend the model gateway with identity, per-user credentials, usage limits and metering (proposed); an account system, such as a portal with Google login; how credentials are issued and revoked | Milestone 9 |
| How public traffic reaches the lab | A static public IP (possible, not required), or not; a separate public Gateway with its own address; the proxy or gateway that serves public IPv6 ([ADR-016](016-use-ipv4-only-pod-and-service-networking-initially.md)) | Milestone 9 |

## Instructions

To create a new ADR:

1. Copy `000-template.md` to a new file named `NNN-decision-name.md`, where `NNN` is the next number after the last ADR in the index above
2. Fill in the template sections in plain English
3. Keep each ADR focused on a single decision
4. Update this README's index table, and remove the decision's row from Open Decisions if it has one
5. Use clear, simple language - this is for learning, not academic review

## Notes

- ADRs should be readable by anyone familiar with basic Kubernetes concepts
- Avoid jargon where possible
- Focus on the "why" more than the "what"
- It's okay to change decisions - just create a new ADR that supersedes the old one
