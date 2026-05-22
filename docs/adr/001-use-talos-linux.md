# ADR-001: Use Talos Linux

Status: Accepted
Date: 2026-05-22

## Decision

Use Talos Linux as the base OS for the Kubernetes cluster.

## Context

This home lab is intended to build practical DevOps/platform engineering skills with an immutable, Kubernetes-focused operating system. Traditional Linux distributions require significant operational overhead including package management, SSH access, security hardening, and configuration drift.

Container-optimized OS options include Talos Linux, Flatcar Linux, and k3s. The lab needs a platform that is secure, minimal, easy to bootstrap, and suitable for learning platform engineering.

## Options Considered

- **Talos Linux:** Immutable, Kubernetes-native, API-driven management, no SSH access
- **Flatcar Linux:** Similar philosophy, but Talos has simpler tooling and is more Kubernetes-focused
- **Traditional Linux (Ubuntu/CentOS):** Familiar but requires more operational overhead and security hardening
- **k3s:** Lightweight Kubernetes, better for edge/IoT but less suitable for learning full platform engineering

## Impact

The lab will use talosctl and declarative machine configuration instead of traditional SSH-based server administration. All configuration is via machine configs stored in Git. Management is API-driven through the Talos API. The system is immutable with no package manager or shell access.

## Not Doing Yet

Do not optimize advanced Talos features before the control plane is stable. Defer advanced Talos configuration until after the cluster is healthy and basic operations are understood.

## Review Notes

Revisit this decision if Talos proves difficult to troubleshoot or if the learning curve becomes a blocker for progress. Consider alternatives if the API-based management model proves unsuitable for the lab's needs.
