terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# The kubernetes provider is configured dynamically from the AKS cluster output.
# This requires the AKS cluster to exist before any kubernetes resources are planned.
# Run `terraform apply -target=azurerm_kubernetes_cluster.linkding` first if bootstrapping.
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.linkding.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.linkding.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.linkding.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.linkding.kube_config[0].cluster_ca_certificate)
}
