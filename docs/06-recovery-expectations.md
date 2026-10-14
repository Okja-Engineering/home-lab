# Recovery Expectations

What has to be recoverable, how, and how a restore is shown to work. [ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md) requires three separate backups: encrypted configuration, etcd state, and application data. This document applies that to each kind of service.

Proposed unless it cites a decision ([status words](adr/README.md#status-meanings)).

## Recovery Invariants

What must hold for anything the lab relies on. Milestone and issue criteria cite these and record the evidence.

1. **Live storage and backups are distinct** (the owner, 2026-10-14: "Distinguish live application storage from backups"). Proposed: a backup never sits on the device that holds the data it protects.
2. **Off the cluster** means: not on, or served by, any cluster node; on a machine with its own power supply unit (the shared UPS is covered by the [off-site copy](#live-storage-and-backups)); and written with credentials that, where the cluster holds them, can add backups but cannot delete or overwrite existing ones.
3. **Important data gets a backup plan with a tested restore** as each service that holds it is introduced (the owner).
4. **A protected etcd snapshot comes before any disruptive test** (the owner: "Take and protect a snapshot before disruptive testing"). On 2026-10-14 the owner added: "Before disruptive testing, require a protected snapshot at a confirmed off-cluster destination, independently recoverable keys, and verification that the copy can be retrieved and decrypted. Do not mark this complete merely because a destination is proposed." Its wording in issue 26 is pending.
5. **Configuration and source code stay reachable when the cluster or internal Git is down** (the owner).
6. **The age private key that decrypts the Talos secrets bundle never enters the cluster.** When Flux decrypts secrets (Phase 4), it gets its own key. An input to ADR-010's revisit.
7. **Recovery access check:** from the recovery machine (a machine other than the workstation, among [issue 25](https://github.com/Okja-Engineering/home-lab/issues/25)'s management sources), `talosctl` reaches each node at its own address, which needs no etcd quorum. `kubectl` through the VIP is checked too, as a routine check: it needs etcd quorum ([ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md)).

## Two Bars

Each service has a class, learning or reliance. The class sets its bar, the minimum standard for recovering it:

- **Learning bar:** the service can be rebuilt from Git, and has been rebuilt that way at least once. Its data may be lost.
- **Reliance bar:** its data is backed up [off the cluster](#recovery-invariants) on a schedule, and encrypted where it holds secrets. A restore has been exercised and recorded with a date, and is repeated after any change that could break it. Once monitoring exists, a failed backup raises an alert.

The owner, 2026-10-14: the AI work is learning and testing, initially; "The AI experiments can be disposable, but the whole platform should not be treated that way"; and a learning project is not "permission to lose real work or other people's data". The AI class is revisited when Phase 7 lets other people use inference. The reliance bar is the proposed standard for ADR-010's backups and for services that hold important data. Downtime and data-loss targets are open.

## Important Data

Named by the owner on 2026-10-14: real source repositories; databases; user accounts; configuration that cannot easily be recreated; and, if access is ever paid for, account records and usage information. The first applications are not chosen yet.

## Live Storage and Backups

If it is attached to the stateful tower, the [storage of about 8 TB](05-workload-placement.md#candidate-machines) is not off the cluster: it can be a first, fast copy, but not the only one.

Proposed: important data also gets an **independent copy**, with the property each failure calls for. The mechanism and the provider are [open](adr/README.md#open-decisions).

| Failure | What survives it |
|---|---|
| The tower's hardware or power supply fails | A copy on another machine |
| Theft, fire, water or a power surge | A copy off-site |
| Ransomware, or an operator mistake, with write access to the data | A versioned, append-only or immutable copy that the lab's credentials cannot delete |
| Filesystem corruption that a sync copies | A versioned copy that keeps a version from before the corruption |
| If the tower becomes a cluster node, as the working plan has it: an install that picks the wrong disk, upgrades and reboots, or a target served from inside the cluster | A copy off the cluster |

## Recovery Kit and Restore Order

The owner decided (2026-10-14) to add a small recovery kit, a lesson from [deedee-ops/home-ops](https://github.com/deedee-ops/home-ops), a reference newly reviewed on 2026-10-14 and not one of the original research references:

- a local configuration copy;
- independently backed-up keys ([issue 19](https://github.com/Okja-Engineering/home-lab/issues/19));
- the pinned Talos ISO and its checksum ([issue 17](https://github.com/Okja-Engineering/home-lab/issues/17) records the checksum);
- a clean-machine recovery test.

Full offline registries and caching are deferred (the owner). Proposed: the configuration copy is a current clone of this repository, kept outside the cluster, and issue 19's restore test runs on a clean machine.

Proposed restore order, each step needing only the ones before it:

1. The age key, from its independent backup. Any key Flux gets is settled at [ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md)'s revisit.
2. This repository, from GitHub or the local copy.
3. The boot media, checked against its pinned checksum.
4. The control plane: machine configs regenerated from the decrypted bundle, the nodes installed, then etcd restored from the latest protected snapshot ([issue 27](https://github.com/Okja-Engineering/home-lab/issues/27)).
5. Storage and the platform services.
6. Application data from its backups, internal Git included. Nothing earlier waits on internal Git.

## By Kind of Service

| Kind | What is backed up, and where | Restore shown by | Bar |
|---|---|---|---|
| Cluster configuration and secrets | The encrypted secrets bundle, patches and metadata in Git; the age key backed up apart from the workstation and the cluster (ADR-010, issue 19). Machine configs are regenerated, not backed up | Issue 19's restore test | Reliance |
| Cluster state (etcd) | Snapshots encrypted to the age public key, off the cluster and off the workstation's disk ([issue 27](https://github.com/Okja-Engineering/home-lab/issues/27)). The owner prefers encrypted, versioned cloud storage as the independent copy, with a separate external drive as a local copy; issue 27 selects and verifies the exact destination and account | Issue 27's restore, exercised as the [reliance bar](#two-bars) requires | Reliance |
| Internal Git (Phase 4) | The repositories and the service's own data; each repository also keeps a current copy readable without the cluster | A restore into a fresh instance, its repositories cloned and compared | Reliance once it holds real source; learning while it only mirrors |
| Databases and other application data (Phase 3 on) | Each application's data, with the backup tool chosen in Phase 3 ([open](adr/README.md#open-decisions)) | A restore into a separate namespace that the application reads | Reliance for important data; learning for scratch data |
| Accounts and usage records (Phase 7) | User accounts, and, if access is ever paid for, account records and usage information (the owner); records of credentials issued and revoked, and per-user limits (proposed) | An exercised restore; the Milestone 9 spec decides what it shows | Reliance |
| Monitoring data | Dashboards and alert rules in Git; metrics and logs are not backed up, and their retention is bounded ([ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md)) | A rebuild | Learning |
| Platform services that keep no data | Configuration in Git. At the reliance bar instead: a private certificate authority's key, if [issue 30](https://github.com/Okja-Engineering/home-lab/issues/30) chooses one; the secret store behind external-secrets, if it is self-hosted (the Milestone 5 spec decides) | A rebuild | Learning |
| AI experiments (Phases 5 and 6) | Configuration and evaluation records in Git; model files are downloaded again | A rebuild | Learning, initially (the owner) |

## Recovery Access

Invariants 5 and 7 apply. Decided ([ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md), [ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md)), implemented by issue 19 and the installs: per-node `talosctl` access, and the secrets and key kept as in the table above. In place today: this repository is on GitHub, outside the lab.

Proposed:

- GitHub stays the public source of truth for this repository; an internal Git service mirrors it rather than replacing it.
- Nothing needed to rebuild the cluster exists only in the cluster or only in internal Git, and every repository moved in-house keeps a copy readable without the cluster.

Open: where Flux pulls from, and how to recover when that source is down; which service is used for internal Git, and what moves to it.

## Gate: Ready to Hold Important Workloads

The owner asked (2026-10-14) for "control plane validated" ([issue 26](https://github.com/Okja-Engineering/home-lab/issues/26)) to be kept apart from being ready to hold important workloads. Validation shows that the control plane works, not that data can be recovered or that access is controlled. Passing this gate is the last Phase 3 criterion in [Goals](00-goals.md#phases); its conditions are proposed. No important data goes into the cluster until all of these hold, each recorded with a date:

1. An etcd restore has been exercised ([issue 27](https://github.com/Okja-Engineering/home-lab/issues/27)).
2. The [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants) hold on every node, workers included, and for the in-cluster admin surfaces ([issue 25](https://github.com/Okja-Engineering/home-lab/issues/25), [issue 29](https://github.com/Okja-Engineering/home-lab/issues/29)).
3. The storage in use is proven with a test volume, and an application-data backup has been restored from a target [off the cluster](#recovery-invariants).
4. The [independent copy](#live-storage-and-backups) of important data is off-site, an older version restores from it, and the lab's own credentials cannot delete it.
5. Monitoring alerts fire for [move-off triggers](05-workload-placement.md#move-off-triggers) 1 to 4 and for a failed backup, each shown once.
6. The [recovery access check](#recovery-invariants) passes, with issue 29's firewall on.
