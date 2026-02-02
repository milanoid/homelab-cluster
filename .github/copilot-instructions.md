# Copilot Instructions for HomeLab Cluster

This repository manages a K3s Kubernetes cluster using GitOps with Flux CD. All cluster changes are driven by Git commits—no manual `kubectl` commands are needed.

## Architecture Overview

### Repository Structure

The repository follows a **base + overlay pattern** with Kustomize:

- **`apps/base/`**: Base application manifests (Deployments, Services, PVCs, Namespaces)
- **`apps/staging/`**: Environment-specific overlays (Secrets, Ingresses, Cloudflare configs)
  - Each app has a `kustomization.yaml` that references `../../base/<app>` and adds environment-specific resources
- **`clusters/staging/`**: Flux CD bootstrap configuration
  - `flux-system/`: Core Flux components
  - `apps.yaml`, `infrastructure.yaml`, etc.: Flux Kustomization resources pointing to paths in this repo
- **`infrastructure/controllers/`**: Kubernetes controllers and operators (e.g., Renovate)
- **`monitoring/`**: Observability stack (kube-prometheus-stack via HelmRelease)
- **`persistent-volumes/`**: PersistentVolume definitions

### GitOps Workflow

1. **Flux watches this repository** and syncs changes automatically
2. **Flux Kustomization resources** (in `clusters/staging/`) define what paths to reconcile:
   - `apps.yaml` → reconciles `./apps/staging`
   - `infrastructure.yaml` → reconciles `./infrastructure/controllers/staging`
   - Each Kustomization has `interval: 1m0s`, `prune: true`, and SOPS decryption enabled
3. **Changes are applied** by pushing to the repository—Flux handles the rest

### Secrets Management

- Secrets are encrypted with **SOPS** using age encryption
- Configuration: `.sops.yaml` specifies age recipient and encryption rules
- Pattern: `encrypted_regex: ^(data|stringData)$` (only encrypts Secret data fields)
- All Flux Kustomizations have `decryption.provider: sops` configured

## Key Conventions

### Application Deployment Pattern

When adding a new application:

1. Create base manifests in `apps/base/<app>/`:
   - `deployment.yaml`: Container specs with image version pinned (e.g., `image: sissbruecker/linkding:1.45.0`)
   - `service.yaml`: ClusterIP service
   - `storage.yaml`: PersistentVolumeClaim if needed
   - `namespace.yaml`: Dedicated namespace
   - `kustomization.yaml`: Lists all resources

2. Create environment overlay in `apps/staging/<app>/`:
   - `kustomization.yaml`: References base with `resources: [../../base/<app>]`, sets namespace
   - `ingress.yaml`: Traefik ingress with `ingressClassName: traefik`
   - Encrypted secrets (e.g., `*-secrets.yaml`) encrypted with SOPS
   - Optional: `cloudflare.yaml` for Cloudflare tunnel configs

3. Register in `apps/staging/kustomization.yaml`:
   - Add `- <app>` to the resources list
   - Use comments to indicate optional apps (e.g., `# Comment out this line to exclude from deployment`)

### Helm Usage

Helm charts are deployed via Flux **HelmRelease** resources:
- Example: `monitoring/controllers/base/kube-prometheus-stack/release.yaml`
- Specify chart version explicitly (e.g., `version: "77.6.2"`)
- Set `install.crds: Create` and `upgrade.crds: CreateReplace` for CRD management
- Use `driftDetection.mode: enabled` for automated drift correction

### Ingress Configuration

All apps use **Traefik** as the ingress controller:
- Set `ingressClassName: traefik`
- Hostnames are subdomains of `milanoid.net` (e.g., `linkding.milanoid.net`)
- Pattern: DNS points to local IP for LAN/VPN access

### Security Context

Containers should run as non-root:
- Set `securityContext.allowPrivilegeEscalation: false`
- Specify `runAsUser` with appropriate UID (e.g., `runAsUser: 33` for www-data)

## Tools & Automation

### Renovate

Automated dependency updates are configured via:
- `renovate.json`: Monitors YAML files for Kubernetes image updates
- Deployed as a CronJob in the cluster (`infrastructure/controllers/base/renovate/`)

### No Build/Test Commands

This repository contains declarative YAML manifests only—there are no build, test, or lint commands. Validation happens through:
- Flux dry-run validation during reconciliation
- Kubernetes API server validation on apply

## Common Tasks

### Adding a new application
Follow the three-step pattern above (base → overlay → register).

### Updating an application image
Edit the image tag in `apps/base/<app>/deployment.yaml`. Renovate will also create PRs for updates automatically.

### Modifying secrets
Use `sops` CLI to edit encrypted files:
```bash
sops apps/staging/<app>/<app>-secrets.yaml
```

### Checking Flux sync status
SSH to the cluster and run:
```bash
flux get kustomizations
flux logs
```

## Cloudflare Tunnels

Applications exposed to the internet use **Cloudflare Tunnels** (cloudflared) for secure access without opening firewall ports.

### Tunnel Deployment Pattern

Each tunneled application has its own cloudflared Deployment in the app's staging overlay:

1. **Cloudflared Deployment** (`cloudflare.yaml`):
   - Runs `cloudflare/cloudflared` container with 2 replicas for HA
   - Mounts tunnel credentials from a Secret (e.g., `tunnel-credentials`)
   - Mounts tunnel configuration from a ConfigMap (defines hostname → service routing)
   - Includes `/ready` liveness probe on port 2000

2. **Tunnel Credentials Secret** (`*-tunnel-credentials.yaml`):
   - Contains `credentials.json` encrypted with SOPS
   - Generated from Cloudflare Zero Trust dashboard
   - Each tunnel has a unique credentials file

3. **ConfigMap Configuration**:
   - Embedded in `cloudflare.yaml` as ConfigMap resource
   - Defines ingress rules mapping hostnames to Kubernetes services
   - Example: `lkd.milanoid.net → http://linkding:9090`
   - Always includes catch-all rule: `- service: http_status:404`

### Tunnel vs Ingress

The repository uses **two access patterns**:

- **Cloudflare Tunnel**: For public internet access (e.g., `lkd.milanoid.net` for Linkding)
  - Traffic: Internet → Cloudflare → Tunnel → Service
  - No ingress resource needed; routing defined in cloudflared ConfigMap
  
- **Traefik Ingress**: For LAN/VPN access (e.g., `linkding.milanoid.net`)
  - Traffic: LAN → Traefik → Service
  - DNS points subdomain to local IP
  - Uses standard Kubernetes Ingress with `ingressClassName: traefik`

Some apps have both (different hostnames for internal vs external access).

## Persistent Volumes

Storage is handled through a combination of **NFS for shared data** and **local volumes for app configs**.

### NFS Persistent Volume

A centralized NFS volume backed by a Synology NAS:

- **PersistentVolume**: `persistent-volumes/base/nfs-pv.yaml`
  - Name: `synology-nfs-pv`
  - Capacity: 500Gi
  - Access mode: `ReadWriteMany` (multi-pod access)
  - NFS server: `192.168.1.36` at `/volume1/k8s`
  - Mount options optimized for performance: NFSv4.1, 128KB buffers, async writes, 10-min attribute caching
  - Reclaim policy: `Retain` (data survives PVC deletion)

- **Shared PVC**: `apps/base/downloaders-pvc/storage.yaml`
  - Single PVC (`synology-nfs-pvc`) in `downloaders` namespace
  - Bound to `synology-nfs-pv` via `volumeName: synology-nfs-pv`
  - Shared by multiple apps: prowlarr, sonarr, radarr, bazarr, torrent-client
  - Used for large shared data (movies, TV shows, downloads)

**Important**: Due to 1:1 PV-to-PVC binding, only one PVC can claim an NFS PV. Apps needing access to the same NFS volume must share the same PVC and namespace.

### Local Storage Pattern

Each application also uses local `ReadWriteOnce` PVCs for configuration data:

- **Pattern**: Defined in `apps/base/<app>/storage.yaml`
- **Example**: Linkding uses `linkding-data-pvc` (1Gi) for its database
- **Example**: Media apps use separate config PVCs (e.g., `prowlarr-config-pvc`, `sonarr-config-pvc`)
- **Access mode**: `ReadWriteOnce` (single-node, single-pod)
- **Storage class**: Default (unspecified) uses local-path provisioner from K3s

### Volume Mount Patterns

Apps typically mount:
1. **Config volume**: App-specific PVC for configuration/database (`ReadWriteOnce`)
2. **Data volume**: Shared NFS PVC for large media files (`ReadWriteMany`, if needed)

Example from bazarr:
```yaml
- name: bazarr-config
  persistentVolumeClaim:
    claimName: bazarr-config-pvc  # Local config
- name: bazarr-data
  persistentVolumeClaim:
    claimName: synology-nfs-pvc   # Shared NFS
```

## Hardware Context

The cluster runs on a single-node HP EliteDesk 705 G2 Mini (AMD A8-8600B, 8GB RAM, 128GB SSD) with Ubuntu 24 LTS and K3s. This is a homelab environment for learning—not production-grade.
