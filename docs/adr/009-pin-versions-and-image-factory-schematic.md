# ADR-009: Pin Exact Versions and One Image Factory Schematic

Status: Accepted
Date: 2026-10-11

## Decision

Record an exact Talos patch release, compatible Kubernetes and Cilium versions, and one Image Factory schematic. The same schematic builds the boot ISO and the installed image.

## Context

The docs disagreed: Talos v1.8.0 in `metadata.env`, v1.13.2 in the runbook. Kubernetes 1.31 is end-of-life. Image Factory only adds the extensions you select, so CPU microcode needs the `intel-ucode` (or `amd-ucode`) extension.

## Options Considered

- Stock ISO from GitHub releases
- Image Factory schematic (chosen)

## Impact

Versions are recorded in one place (`metadata.env`). The installer image in the Talos patch repeats the Talos version and must match it. Talos and Kubernetes upgrades are separate operations, each with a documented upgrade and rollback procedure.

## Not Doing Yet

Automated upgrades are deferred.

## Review Notes

Revisit this decision at each Talos minor release.
