# Architecture Vision

Where the lab is going, why in this order, and how far each choice has been decided. The status words (accepted, proposed, open, deferred, working plan) are defined in [Status Meanings](adr/README.md#status-meanings). Everything else has one home:

- Phases and their success criteria: [Goals](00-goals.md#phases)
- Decisions: the [ADRs](adr/README.md). Choices not yet made, with their options: the [open decisions](adr/README.md#open-decisions)
- Worker roles, candidate machines, the rules for the control plane, the access and exposure invariants, and the publication rules: [Workload Placement](05-workload-placement.md)
- Each service's class (learning or reliance), the recovery invariants and the recovery kit: [Recovery Expectations](06-recovery-expectations.md)
- Hardware facts and addresses: [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env) is the record; [ADR-014](adr/014-rebase-address-plan-onto-10-0-0-0-24.md) is the address plan

## Destination

The owner set the destination on 2026-10-14:

> A highly available Talos control plane, then stateful and stateless workers, recoverable platform services, GitOps and internal source control, followed by local inference experiments and workflows combining local and frontier models.

The owner added the same day that the eventual goal includes public-facing services: selected people use the lab's compute through an authenticated API gateway, and possibly a website or portal.

Also decided by the owner on 2026-10-14:

- The order of Phases 3 to 6 in [Goals](00-goals.md#phases). The GX10 joins after the workers, the platform services and GitOps.
- The lab starts private. Public access comes later, as its own milestone with clear acceptance criteria. Its place in the sequence, Phase 7, is proposed, with its [prerequisites](00-goals.md#phases).
- Placement, storage selection and any erasure wait for evidence ([Order of Work](05-workload-placement.md#order-of-work)). Until then, the machines' roles are a [working plan](05-workload-placement.md#candidate-machines).
- The [access and exposure](05-workload-placement.md#access-and-exposure-invariants) and [recovery](06-recovery-expectations.md#recovery-invariants) invariants marked as the owner's.
- Local inference uses vLLM, not NVIDIA NIM ([ADR-015](adr/015-use-vllm-for-local-inference.md)). One GX10 is owned; a second, possibly bought with a collaborator, is possible future capacity.
- Pod and Service networking is IPv4-only initially, with future public IPv6 handled at a proxy or gateway in front of the private cluster ([ADR-016](adr/016-use-ipv4-only-pod-and-service-networking-initially.md)).
- The AI work is learning and testing, initially; what that means for each service is in [Recovery Expectations](06-recovery-expectations.md#two-bars).

The decisions and their summary rationale are in [ADR-001](adr/001-use-talos-linux.md) to [ADR-014](adr/014-rebase-address-plan-onto-10-0-0-0-24.md), which stand. The fuller researched reasoning is in the earlier "Review RFC Decisions" work, cited when it is recovered. The reference home labs from the owner's earlier ChatGPT Home Lab project research are not yet recovered either; no names are guessed.

## Why This Order

The order of Phases 3 to 6 is the owner's; the reasons are this document's reading of it.

1. **The control plane first.** Everything else runs on it or talks to its API ([ADR-003](adr/003-use-three-control-plane-nodes.md)).
2. **Workers before the platform services.** etcd shares each control-plane machine's only internal disk ([Workload Placement](05-workload-placement.md#what-is-known-and-what-is-not)), and [ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md) warns that monitoring and storage can slow etcd. Workers give data somewhere else to live.
3. **Platform services before GitOps.** Install and check by hand, then let Flux take over, as the [principles](00-goals.md#principles) "Document before automating" and "Prefer manual validation over premature automation" suggest. [ADR-004](adr/004-defer-gitops-until-control-plane-is-healthy.md) allows either order; its review note suggests GitOps "when adding platform services".
4. **Internal source control with GitOps, never the only way back,** as the owner requires ([Recovery Expectations](06-recovery-expectations.md#recovery-invariants)).
5. **Local inference after GitOps.** The owner decided the GX10 can wait; by then it has DNS, TLS, monitoring and secrets handling to use.
6. **Combined local and frontier workflows next,** because they need a working local endpoint.
7. **Public access: position proposed.** Its prerequisites are in [Goals](00-goals.md#phases).

## The Foundation (Phase 2)

The foundation is accepted in ADR-001 to ADR-014 and ADR-016. What it gives the later phases:

- **Talos on three control-plane nodes** ([ADR-001](adr/001-use-talos-linux.md), [ADR-003](adr/003-use-three-control-plane-nodes.md)), with **workloads allowed on them** under requests, limits and headroom ([ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md)). The safeguards are [proposed](05-workload-placement.md#interim-control-plane-policy).
- **Cilium with kube-proxy replacement from the first boot** ([ADR-005](adr/005-use-cilium-with-kube-proxy-replacement.md)), which Cilium's Gateway API needs to serve application entry points later ([ADR-012](adr/012-use-cilium-gateway-api-for-ingress.md)). Pod and Service networks are IPv4-only at first ([ADR-016](adr/016-use-ipv4-only-pod-and-service-networking-initially.md)).
- **A shared API VIP** ([ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md)) keeps one API address when a control-plane node is lost. `talosctl` talks to each node at its own address, so `talosctl` access does not depend on the VIP.
- **Static addresses and a reserved worker range** ([ADR-007](adr/007-configure-static-node-addresses.md), [ADR-014](adr/014-rebase-address-plan-onto-10-0-0-0-24.md)) let workers join without renumbering.
- **Exact pins and one Image Factory schematic** ([ADR-009](adr/009-pin-versions-and-image-factory-schematic.md)) make nodes reproducible. [Image profiles](05-workload-placement.md#image-profiles) are proposed for hardware that needs more.
- **Secrets in Git, encrypted with SOPS and age, and protected off-cluster etcd snapshots** ([ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md)).
- **Management access defined now and enforced later with the Talos firewall** ([ADR-013](adr/013-define-management-access-boundaries.md)) will keep Talos and Kubernetes administration private; [access and exposure invariant 2](05-workload-placement.md#access-and-exposure-invariants) proposes how far that reaches.
- **A flat network to start** ([ADR-002](adr/002-start-with-flat-network.md)). VLANs are open.

## Intended Services by Layer

### Workers (Phase 3, First)

- **Accepted:** stateful and stateless/platform roles (the owner's destination).
- **Working plan:** which machine fills each role ([Workload Placement](05-workload-placement.md#candidate-machines)).
- **Open:** whether the GPU/inference role is a Kubernetes worker at all.

### Recoverable Platform Services (Phase 3, After the Workers)

- **Accepted:** ingress through Cilium Gateway API, with application addresses from LB IPAM, Cilium's pool of load-balancer addresses ([ADR-012](adr/012-use-cilium-gateway-api-for-ingress.md)); bounded monitoring retention ([ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md)).
- **Proposed:** cert-manager, external-secrets, and Prometheus, Grafana and Loki ([Cluster Design](03-cluster-design.md#cluster-components)).
- **Open:** storage, including the storage of about 8 TB; backups and the independent copy; application DNS and TLS ([issue 30](https://github.com/Okja-Engineering/home-lab/issues/30)); keeping internal services internal; power loss and the UPS.

### GitOps and Internal Source Control (Phase 4)

- **Accepted:** Flux, the GitOps tool [ADR-004](adr/004-defer-gitops-until-control-plane-is-healthy.md) and the Phase 4 criteria name.
- **Deferred:** Flux decrypting secrets, to Phase 4, by [ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md), which is revisited then.
- **Open:** where Flux pulls from, and the break-glass path (the emergency way in); the internal source-control service.

### Local Inference Experiments (Phase 5)

- **Accepted:** vLLM ([ADR-015](adr/015-use-vllm-for-local-inference.md)). The owner has one GX10; a second is possible future capacity.
- **Open:** the GX10's deployment path and first models; how two GX10s would be used.

### Combined Local and Frontier Workflows (Phase 6)

- **Proposed:** frontier API credentials encrypted with SOPS and age, like the cluster's secrets.
- **Open:** the model gateway, frontier data egress, and the success measure.

### Controlled Public Access (Phase 7, Position Proposed)

- **Accepted goals (the owner):** [selected entry points only](05-workload-placement.md#access-and-exposure-invariants); IPv4 and IPv6 both planned; an authenticated API gateway; a public API hostname under a domain we control, still to be confirmed; API credentials issued and revoked for approved users; per-user permissions, usage limits and visibility into consumption; collaboration with others; possibly a portal with Google login or similar.
- **Proposed:** the public API gateway built on the Phase 6 model gateway.
- **Open:** its design, the domain, the account system, and how public traffic reaches the lab.
- **Deferred:** paid access, a possibility for later and not a promise (the owner).

## Three Kinds of Gateway

- **Ingress** ([ADR-012](adr/012-use-cilium-gateway-api-for-ingress.md)): Cilium's Gateway API gives applications an address, routing by hostname, and TLS. DNS names come separately ([issue 30](https://github.com/Okja-Engineering/home-lab/issues/30)). It provides entry points and nothing more.
- **The model gateway** (Phase 6): routes model requests between the local endpoint and frontier APIs, and holds API credentials, quotas and fallback.
- **The public API gateway** (Phase 7): proposed to extend the model gateway with identity, per-user credentials, usage limits and metering.

Both gateways may be reached through ingress; neither is ingress.

## Glossary

- **Control plane validated:** the checks in [issue 26](https://github.com/Okja-Engineering/home-lab/issues/26) have passed (etcd, networking and DNS, VIP failover, recovery access), and the [etcd and disk-latency baseline](05-workload-placement.md#safeguards) is recorded. It is the Milestone 3 gate and says nothing about application data.
- **Ready to hold important workloads:** a later gate, at the end of Phase 3, defined in [Recovery Expectations](06-recovery-expectations.md#gate-ready-to-hold-important-workloads). The owner asked for the two to be kept apart.
