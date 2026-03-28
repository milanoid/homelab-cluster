# Linkding — Terraform PoC for Azure AKS

This Terraform configuration provisions a minimal AKS cluster on Azure and deploys [linkding](https://github.com/sissbruecker/linkding) onto it. It is a PoC showing how the app could be expressed as Terraform targeting a cloud Kubernetes service rather than the on-prem k3s homelab.

## Resources created

### Azure (azurerm)

| Resource | Type |
|---|---|
| Resource group | `azurerm_resource_group` |
| AKS cluster (1 × Standard_B2s node) | `azurerm_kubernetes_cluster` |

### Kubernetes (in the AKS cluster)

| Resource | Type |
|---|---|
| `linkding` namespace | `kubernetes_namespace` |
| Superuser credentials | `kubernetes_secret` |
| Data volume (Azure Managed Disk) | `kubernetes_persistent_volume_claim` (managed-csi) |
| App workload | `kubernetes_deployment` |
| Internal service | `kubernetes_service` (ClusterIP) |
| Public ingress | `kubernetes_ingress_v1` (nginx) |

## Prerequisites

- Azure CLI authenticated: `az login`
- An Azure subscription — set `subscription_id` in your tfvars
- Terraform >= 1.5
- **nginx ingress controller** installed on the cluster (see below)

> **Note:** The AKS cluster is created in this same Terraform configuration. On first run, target AKS first, then apply everything else (see Bootstrap section).

## Usage

### 1. Create `terraform.tfvars` (never commit this)

```hcl
subscription_id             = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
linkding_superuser_name     = "admin"
linkding_superuser_password = "changeme"
linkding_hostname           = "linkding.example.com"
```

### 2. Bootstrap: provision AKS first

The `kubernetes` provider needs the cluster to exist before it can be initialised.
On a fresh deployment, apply AKS first:

```bash
terraform init
terraform apply -target=azurerm_kubernetes_cluster.linkding
```

### 3. Install nginx ingress controller

```bash
# Merge kubeconfig
az aks get-credentials --resource-group linkding-poc-rg --name linkding-poc-aks

# Install ingress-nginx via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer

# Get the public IP assigned to the LoadBalancer
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Point your DNS A record (`linkding_hostname`) to that IP.

### 4. Apply everything

```bash
terraform apply
```

### 5. Verify

```bash
kubectl get all -n linkding
kubectl get ingress -n linkding
curl http://<your-hostname>
```

### Tear down

```bash
terraform destroy
```

This removes the AKS cluster, resource group, and all Azure resources. The data PVC (Azure Disk) is also deleted.

## Comparison with homelab k3s version

| Concern | homelab k3s | Azure AKS |
|---|---|---|
| Cluster infra | Pre-existing (not in TF) | Provisioned by TF (`aks.tf`) |
| Storage class | `local-path` (node disk) | `managed-csi` (Azure Managed Disk) |
| Ingress controller | Traefik (built into k3s) | nginx (manually installed) |
| Public access | Cloudflare tunnel (zero-trust) | nginx LoadBalancer + public IP |
| Cost | Electricity only | ~$30–50/month for Standard_B2s |
| HA tunnel | 2× cloudflared replicas | N/A |

## Key differences vs current Flux/Kustomize setup

| Concern | Flux + Kustomize | Terraform |
|---|---|---|
| Reconciliation | Automatic (every 1m, Git-driven) | Manual `terraform apply` |
| Secrets | SOPS encrypted in Git | TF vars + encrypted remote state |
| Drift detection | Built-in (Flux prune) | `terraform plan` shows drift |
| Cluster lifecycle | Manual / separate tool | Managed in same codebase |
| Multi-env | base + overlay pattern | Workspaces or separate dirs |

## Notes

- **Secrets management**: In production, consider storing sensitive variables in Azure Key Vault and reading them with the `azurerm_key_vault_secret` data source, rather than passing them as plain TF variables.
- **TLS**: The ingress has SSL redirect disabled for simplicity. In production, add cert-manager with a Let's Encrypt `ClusterIssuer` and a TLS block in the ingress spec.
- **Replicas**: Linkding is kept at 1 replica because the PVC uses `ReadWriteOnce` (Azure Disk). For HA, switch to Azure Files (`azurefile-csi`) with `ReadWriteMany`.
