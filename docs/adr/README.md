# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the home lab project.

## What are ADRs?

ADRs are short documents that describe significant architectural decisions made in this project. Each ADR captures:

- The context for the decision
- The decision itself
- The impact of that decision
- What we are intentionally not doing yet

## Why this repo uses ADRs

This home lab is both an operational platform and a learning portfolio. ADRs help:

- Document the reasoning behind architectural choices
- Make it easier to revisit decisions later
- Provide a clear history of how the platform evolved
- Support learning by explaining trade-offs

## Status Meanings

- **Proposed:** The decision is being considered
- **Accepted:** The decision has been made and is being implemented
- **Implemented:** The decision has been fully implemented
- **Superseded:** The decision has been replaced by a newer decision

## ADR Index

| ADR | Title | Status | Summary |
|-----|-------|--------|---------|
| 001 | Use Talos Linux | Accepted | Use Talos Linux as the base OS for Kubernetes nodes |
| 002 | Start with Flat Network | Accepted | Bootstrap on a simple flat network before VLANs |
| 003 | Use Three Control Plane Nodes | Accepted | Use three GMKtec mini PCs for HA control plane |
| 004 | Defer GitOps Until Control Plane is Healthy | Accepted | Defer Flux installation until cluster is stable |

## Instructions

To create a new ADR:

1. Copy `000-template.md` to a new file with the next sequential number (e.g., `005-decision-name.md`)
2. Fill in the template sections in plain English
3. Keep each ADR focused on a single decision
4. Update this README's index table
5. Use clear, simple language - this is for learning, not academic review

## Notes

- ADRs should be readable by anyone familiar with basic Kubernetes concepts
- Avoid jargon where possible
- Focus on the "why" more than the "what"
- It's okay to change decisions - just create a new ADR that supersedes the old one
