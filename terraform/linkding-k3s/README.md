# Linkding — Terraform PoC for k3s homelab

This Terraform configuration deploys [linkding](https://github.com/sissbruecker/linkding) to the existing homelab k3s cluster. It is a PoC showing how the current Flux CD + Kustomize GitOps setup could be expressed as Terraform instead.

## Resources created

| Resource | Type |
|---|---|
| `linkding` namespace | `kubernetes_namespace` |
| Superuser credentials | `kubernetes_secret` |
| Cloudflare tunnel credentials | `kubernetes_secret` |
| Data volume | `kubernetes_persistent_volume_claim` (local-path) |
| App workload | `kubernetes_deployment` |
| Internal service | `kubernetes_service` (ClusterIP) |
| LAN/VPN access | `kubernetes_ingress_v1` (Traefik) |
| Cloudflare tunnel config | `kubernetes_config_map` |
| Public tunnel workload | `kubernetes_deployment` (cloudflared, 2 replicas) |

## Prerequisites

- k3s cluster running with Traefik ingress controller (default in k3s)
- `kubectl` access configured (`~/.kube/config`)
- A Cloudflare tunnel created and `credentials.json` available
- DNS entries in Cloudflare:
  - `linkding.milanoid.net` → local cluster IP (LAN/VPN only)
  - `lkd.milanoid.net` → routed via Cloudflare tunnel

## Usage

### 1. Create a `terraform.tfvars` file (never commit this)

```hcl
linkding_superuser_name     = "admin"
linkding_superuser_password = "changeme"
tunnel_credentials_json     = file("~/.cloudflare/cftunnel-credentials.json")
```

### 2. Init, plan, apply

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify

```bash
kubectl get all -n linkding
kubectl get ingress -n linkding
```

## Comparison with current Flux/Kustomize approach

| Concern | Flux + Kustomize | Terraform |
|---|---|---|
| Reconciliation | Automatic (every 1m) | Manual `terraform apply` |
| Secrets | SOPS encrypted in Git | TF vars / remote state encryption |
| Drift detection | Built-in (Flux prune) | `terraform plan` shows drift |
| Cluster infra | Not managed | Can manage cluster itself too |
| Learning curve | Kubernetes-native | Broader IaC ecosystem |

## Notes

- **Secrets**: In this PoC, secrets are passed as Terraform variables. In production, use a remote backend (e.g., Terraform Cloud, S3+DynamoDB) with encryption at rest, or integrate with a secrets manager (Vault, Azure Key Vault). This replaces the SOPS/age approach used in the current GitOps setup.
- **Image pinning**: The default image tag mirrors the current deployment (`1.45.0`). Override via `linkding_image` variable.
- **Storage**: Uses K3s's built-in `local-path` provisioner — data is stored on the node's local disk under `/var/lib/rancher/k3s/storage/`.
