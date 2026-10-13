# ADR-014: Re-base the Address Plan onto 10.0.0.0/24

Status: Accepted
Date: 2026-10-13

## Decision

The address plan moves from 192.168.1.0/24 to 10.0.0.0/24, the subnet the home network uses. Every planned address keeps its host number. The design does not change.

## Context

The plan assumed the home network was 192.168.1.0/24, and that had never been checked. The router check for [issue 16](https://github.com/Okja-Engineering/home-lab/issues/16) found that the network is 10.0.0.0/24, behind an ISP-supplied gateway at 10.0.0.1 that serves DHCP. The nodes will be wired through the switch to that gateway, so this is the network they will be on.

Nothing is installed on any node yet, and the cluster's secrets and machine configs have not been generated, so the move changes only text: this repository and its issues.

This ADR changes the addresses in two accepted ADRs, in place, and nothing else in them: the endpoint under Decision in [ADR-006](006-use-talos-vip-for-kubernetes-api-endpoint.md) (line 8 as of commit `9a7d5a0`), which was `https://192.168.1.20:6443`, and the node addresses under Decision in [ADR-007](007-configure-static-node-addresses.md) (line 8 as of the same commit), which were 192.168.1.21 to 192.168.1.23. Each now ends with a dated note giving the old value. The decisions themselves, a shared VIP and static node addresses, still hold.

## Options Considered

- Re-base the plan onto 10.0.0.0/24 and keep the design (chosen)
- Renumber the gateway's LAN to 192.168.1.0/24: no change to the repo, but every device in the house gets a new address
- Put the lab behind its own router: the workstation could not reach the nodes without extra routing, and it adds a device

## Impact

The values are now:

| Use | Was | Now |
|---|---|---|
| Subnet | 192.168.1.0/24 | 10.0.0.0/24 |
| Gateway | 192.168.1.1 | 10.0.0.1 |
| Kubernetes API VIP ([ADR-006](006-use-talos-vip-for-kubernetes-api-endpoint.md)) | 192.168.1.20 | 10.0.0.20 |
| cp-01, cp-02, cp-03 ([ADR-007](007-configure-static-node-addresses.md)) | 192.168.1.21, 192.168.1.22, 192.168.1.23 | 10.0.0.21, 10.0.0.22, 10.0.0.23 |
| Future worker nodes | 192.168.1.24 to 192.168.1.29 | 10.0.0.24 to 10.0.0.29 |
| Application address pool ([ADR-012](012-use-cilium-gateway-api-for-ingress.md)) | 192.168.1.240 to 192.168.1.249 | 10.0.0.240 to 10.0.0.249 |

The subnet and the gateway address are what the router check found. Every other value is planned and not yet confirmed on the gateway: its DHCP pool has not been read, so none of these addresses is known to be outside the pool or unused. Confirming them is the work of issue 16. If the pool cannot be made to exclude the VIP, node, worker and application ranges, the numbers change again.

The gateway is not carried over as a DNS server for the nodes. The old plan listed the router first among the DNS servers, but the gateway's DHCP hands out public resolvers, not its own address. The DNS servers are marked as to be confirmed in issue 16.

The planned node addresses are now inside 10.0.0.0/8, which the old ones were not. That matters for pod addresses. Checked on 2026-10-13 against the current stable releases, Cilium 1.20.2 and Talos v1.14.2:

- Cilium's default IPAM mode is `cluster-pool`, and its default pod address pool is 10.0.0.0/8. The node network is inside that block. Cilium's documentation says that nodes then lose connectivity to each other.
- Talos's default pod subnet is 10.244.0.0/16 and its default service subnet is 10.96.0.0/12. Neither overlaps 10.0.0.0/24.
- With `ipam.mode: kubernetes`, Cilium allocates pod addresses from the range Kubernetes assigns to each node, and on Talos Kubernetes takes those ranges from the pod subnet. Talos's guide for deploying Cilium requires this mode.

So `ipam.mode: kubernetes`, which [issue 21](https://github.com/Okja-Engineering/home-lab/issues/21) plans, is now required for a second reason: with Cilium's default mode, pods would be given addresses from the block the nodes are in. The Talos pod and service subnets must also stay clear of 10.0.0.0/24, as the defaults do. Both are to be checked again when the versions are pinned ([issue 17](https://github.com/Okja-Engineering/home-lab/issues/17)).

## Not Doing Yet

Confirming the addresses on the gateway, choosing the DNS servers for the nodes, deciding whether to keep the name `k8s.lab.home.arpa`, and giving the workstation a stable address all stay with issue 16.

## Review Notes

Revisit this decision if the gateway's DHCP pool cannot be made to exclude the planned ranges, or if the nodes turn out to be on a different network.
