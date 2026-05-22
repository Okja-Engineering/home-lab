# ADR-002: Start with Flat Network

Status: Accepted
Date: 2026-05-22

## Decision

Start the initial Talos/Kubernetes bootstrap on a simple flat network without VLANs.

## Context

The TP-Link Omada switch and VLAN design are important for the long-term network architecture, but VLANs add complexity that could block the first successful control-plane bootstrap. The lab needs to establish a working control plane before introducing network segmentation.

A flat network simplifies the initial bootstrap by reducing troubleshooting surface area. Issues with VLAN configuration, switch management, or network policies would be harder to debug if introduced before the base cluster is working.

## Options Considered

- **Flat network first:** Simple 192.168.1.0/24 subnet, no VLANs initially
- **VLANs from the start:** Configure Omada switch and VLANs before Talos bootstrap
- **Separate management network:** Dedicate a VLAN for control plane management from the beginning

## Impact

The first milestone prioritizes stable IPs, DHCP reservations, and basic reachability. All control plane nodes will be on the same subnet as the workstation. The TP-Link Omada switch is purchased but its configuration is deferred. Network segmentation, firewall policies, and advanced switch configuration are deferred until after the control plane is healthy.

## Not Doing Yet

VLAN segmentation, firewall policy, and advanced switch configuration are deferred until after the control plane is healthy. The Omada switch will not be configured for VLANs in the initial phase.

## Review Notes

Revisit this decision after the control plane is stable and healthy. Consider implementing VLANs when adding worker nodes or when security requirements become clearer.
