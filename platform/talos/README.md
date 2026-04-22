# Talos Linux Working Directory

This directory contains Talos cluster configurations and machine configs for home lab clusters.

## Directory Structure

```
platform/talos/
├── README.md
├── .gitignore
└── clusters/
    └── <CLUSTER_NAME>/
        ├── README.md
        ├── metadata.env
        ├── secrets/
        ├── generated/
        ├── patches/
        └── manifests/
```

## Directory Purposes

- `clusters/`: One directory per Talos cluster
- `metadata.env`: Non-secret cluster metadata (IPs, domain, disk, etc.) - committed to Git
- `secrets/`: Talos secrets bundle and sensitive outputs - never committed
- `generated/`: Machine configs generated from templates and patches - usually not committed
- `patches/`: YAML patches for machine configuration - committed to Git
- `manifests/`: Kubernetes manifests for cluster bootstrap - committed to Git

## Workflow

1. Fill in `metadata.env` with cluster-specific values
2. Generate secrets bundle: `talosctl gen secrets -o clusters/<CLUSTER_NAME>/secrets/secrets.yaml`
3. Generate machine configs using `talosctl gen config` with patches
4. Apply configs to nodes: `talosctl apply-config`
5. Bootstrap cluster: `talosctl bootstrap`

## Security

- Never commit `secrets/` directory contents
- Never commit `generated/` directory (regenerable from source)
- Commit `metadata.env`, `patches/`, and `manifests/`
- Use environment variables or secret managers for any additional sensitive data

## Git Commit Policy

**Commit to Git:**
- `README.md` files - documentation
- `metadata.env` - cluster metadata (non-secret)
- `patches/` - YAML configuration patches
- `manifests/` - Kubernetes manifests for bootstrap
- `.gitignore` - ignore rules

**Never commit:**
- `secrets/` - Talos secrets bundle (cluster root material)
- `generated/` - machine configs containing embedded secrets
- `talosconfig` - Talos client configuration
- `kubeconfig` - Kubernetes admin credentials
- Support bundles (`support-*.tar.gz`)
- Any copied certificate/key material

Talos recommends keeping the secrets bundle as a source input for reproducible configs, but protect it like cluster root material. Store it in a secure location, not in Git.
