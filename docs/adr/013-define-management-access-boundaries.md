# ADR-013: Define Management Access Boundaries Now; Enforce with the Talos Firewall Later

Status: Accepted
Date: 2026-10-11

## Decision

Allowed management sources for the Talos API (port 50000) and Kubernetes API (port 6443) are defined now. Talos ingress firewall rules are enforced once networking is stable, rolled out one node at a time with `--mode=try`.

## Context

On a flat home network, every device can reach the node ports. "The APIs need certificates" is not a sufficient boundary: Talos maintenance mode accepts configs without authentication, and Kubernetes accepts bearer tokens as well as certificates. Firewall mistakes during bootstrap can lock the operator out.

This ADR amends one sentence of [ADR-002](002-start-with-flat-network.md), the one under Not Doing Yet (line 26 as of commit `7dd635b`): "VLAN segmentation, firewall policy, and advanced switch configuration are deferred until after the control plane is healthy." ADR-002 deferred firewall policy until the control plane is healthy; this ADR defines the policy now and still enforces it later. ADR-002's decision to start on a flat network still holds.

## Options Considered

- Defer entirely
- Enforce from day one
- Wait for VLANs
- Define now and enforce later (chosen)

## Impact

Until rules are enforced, nodes stay off untrusted networks and are not left in maintenance mode unattended. Rules must keep node-to-node and in-cluster API traffic working; an administrator-only allowlist is not enough.

## Not Doing Yet

VLAN segmentation is deferred (see [ADR-002](002-start-with-flat-network.md)).

## Review Notes

Revisit this decision when VLANs are introduced.
