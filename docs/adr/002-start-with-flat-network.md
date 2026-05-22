# ADR-002: Start with Flat Network

Status: Accepted
Date: 2026-05-22

## Decision

Start the initial Talos and Kubernetes bootstrap on a simple flat network.

## Context

The TP-Link Omada switch and VLAN design are important, but VLANs should not block the first successful control-plane bootstrap.

## Options Considered

- Flat network first
- VLANs from the start
- Separate management network

## Impact

The first milestone prioritizes stable IPs, DHCP reservations, basic reachability, and a working Kubernetes API.

## Not Doing Yet

VLAN segmentation, firewall policy, and advanced switch configuration are deferred until after the control plane is healthy.

## Review Notes

Revisit this decision after the control plane is stable and healthy. Consider implementing VLANs when adding worker nodes or when security requirements become clearer.
