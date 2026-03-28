variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "linkding-poc-rg"
}

# -----------------------------------------------------------------------
# AKS cluster
# -----------------------------------------------------------------------
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "linkding-poc-aks"
}

variable "aks_node_vm_size" {
  description = "VM size for the AKS system node pool"
  type        = string
  default     = "Standard_B2s" # 2 vCPU, 4 GB RAM — cheap PoC node
}

variable "aks_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster (leave empty for latest stable)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------
# Application
# -----------------------------------------------------------------------
variable "linkding_image" {
  description = "Linkding container image with tag"
  type        = string
  default     = "sissbruecker/linkding:1.45.0"
}

variable "linkding_superuser_name" {
  description = "Linkding superuser username"
  type        = string
  sensitive   = true
}

variable "linkding_superuser_password" {
  description = "Linkding superuser password"
  type        = string
  sensitive   = true
}

variable "linkding_hostname" {
  description = "Hostname for the nginx ingress (must resolve to the ingress LoadBalancer IP)"
  type        = string
  default     = "linkding.example.com"
}

variable "storage_size" {
  description = "PVC size for linkding data"
  type        = string
  default     = "1Gi"
}
