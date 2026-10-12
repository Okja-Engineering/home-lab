# ADR-011: Bootstrap Once on cp-01, Then Join cp-02 and cp-03

Status: Accepted
Date: 2026-10-11

## Decision

`talosctl bootstrap` runs exactly once, on cp-01. cp-02 and cp-03 join afterwards with the same cluster identity.

## Context

Talos needs bootstrap run only once, on any one control-plane node. Joining one node at a time is a debugging preference, not a Talos requirement.

## Options Considered

- Configure all three, then bootstrap
- Bootstrap cp-01, then join the others (chosen)

## Impact

Neither the one-member nor the two-member stage tolerates a member failure, so failure testing waits until all three have joined. If a cluster already exists, inspect its membership and join nodes without repeating bootstrap.

## Not Doing Yet

Nothing is deferred.

## Review Notes

None.
