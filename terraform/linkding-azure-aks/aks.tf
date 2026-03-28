# -----------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------
resource "azurerm_resource_group" "linkding" {
  name     = var.resource_group_name
  location = var.location
}

# -----------------------------------------------------------------------
# AKS Cluster
# A minimal single-node cluster sufficient for a PoC.
# -----------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "linkding" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.linkding.location
  resource_group_name = azurerm_resource_group.linkding.name
  dns_prefix          = var.aks_cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_vm_size

    # Use Azure managed disks (CSI driver is enabled by default on AKS)
    os_disk_size_gb = 30
  }

  # Use system-assigned managed identity — no service principal needed
  identity {
    type = "SystemAssigned"
  }

  # Enable the Azure CNI overlay network plugin for production-grade networking.
  # For a minimal PoC you can also use kubenet (network_plugin = "kubenet").
  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }

  tags = {
    environment = "poc"
    app         = "linkding"
  }
}
