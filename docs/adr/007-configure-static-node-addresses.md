# ADR-007: Configure Static Node Addresses in the Talos Machine Config

Status: Accepted
Date: 2026-10-11

## Decision

cp-01 to cp-03 get static addresses (10.0.0.21 to 10.0.0.23) in their per-node Talos patches, outside the router's DHCP range.

## Context

etcd members find each other by IP, so an unplanned address change can disrupt the cluster and access to it. DHCP reservations would also work. Static config keeps the address plan reproducible from Git without relying on router settings surviving a reset.

This ADR amends one sentence of [ADR-002](002-start-with-flat-network.md), the one under Impact (line 22 as of commit `7dd635b`): "The first milestone prioritizes stable IPs, DHCP reservations, basic reachability, and a working Kubernetes API." Static addresses in the Talos config replace the DHCP reservations that sentence lists. ADR-002's decision to start on a flat network still holds.

## Options Considered

- DHCP reservations only
- Static addresses in the Talos config (chosen)
- Both

## Impact

Each node's patch carries its IP. The DHCP pool must exclude the reserved ranges. Network ports are selected without MAC addresses, for example with `physical: true` or a bus path.

## Not Doing Yet

VLANs are deferred (see [ADR-002](002-start-with-flat-network.md)).

## Review Notes

Revisit this decision when VLANs are introduced.

## Clarifying Note

Added 2026-10-13. The accepted text above is unchanged except for the addresses under Decision, which were re-based on this date.

The addresses under Decision were 192.168.1.21 to 192.168.1.23. The router check for [issue 16](https://github.com/Okja-Engineering/home-lab/issues/16) found that the home network is 10.0.0.0/24, not 192.168.1.0/24, so the planned node addresses moved to the same host numbers on that subnet. [ADR-014](014-rebase-address-plan-onto-10-0-0-0-24.md) records the decision. The new addresses are still planned: they are not yet confirmed on the gateway.
