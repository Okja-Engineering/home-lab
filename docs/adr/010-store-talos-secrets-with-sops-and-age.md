# ADR-010: Store the Talos Secrets Bundle Encrypted with SOPS and age

Status: Accepted
Date: 2026-10-11

## Decision

The Talos secrets bundle is committed to Git, encrypted with SOPS and age. The age private key is backed up independently of the workstation and the cluster. etcd gets protected, off-cluster snapshots.

## Context

The bundle holds the cluster's root keys, and keeping it only on one laptop risks losing it. If the bundle and the generated configs are both lost, the secrets can still be recovered from a surviving control-plane node's config, but only while authorized access remains.

## Options Considered

- Gitignored file on the workstation
- Password-manager attachment
- SOPS + age in Git (chosen)

## Impact

Encrypted config, etcd state, and application data each need their own backup. Decryption and credential regeneration are tested from another machine.

## Not Doing Yet

Flux-managed decryption is deferred to Phase 4.

## Review Notes

Revisit this decision when Flux is introduced.
