# ADR-001: Use Talos Linux

Status: Accepted
Date: 2026-05-22

## Decision

Use Talos Linux for Kubernetes nodes.

## Context

This home lab is intended to build practical DevOps and platform engineering skills with an immutable, Kubernetes-focused operating system.

## Options Considered

- Talos Linux
- Flatcar Linux
- Traditional Linux (Ubuntu/CentOS)
- k3s

## Impact

The lab will use talosctl and declarative machine configuration instead of traditional SSH-based server administration.

## Not Doing Yet

Do not optimize advanced Talos features before the control plane is stable.

## Review Notes

Revisit this decision if Talos proves difficult to troubleshoot or if the learning curve becomes a blocker for progress.
