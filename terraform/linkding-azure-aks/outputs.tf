output "resource_group_name" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.linkding.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.linkding.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS API server"
  value       = azurerm_kubernetes_cluster.linkding.fqdn
}

output "kubeconfig" {
  description = "Raw kubeconfig for the AKS cluster (use with kubectl)"
  value       = azurerm_kubernetes_cluster.linkding.kube_config_raw
  sensitive   = true
}

output "kubeconfig_command" {
  description = "az CLI command to merge the AKS kubeconfig into ~/.kube/config"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.linkding.name} --name ${azurerm_kubernetes_cluster.linkding.name}"
}

output "namespace" {
  description = "Kubernetes namespace where linkding is deployed"
  value       = kubernetes_namespace.linkding.metadata[0].name
}

output "linkding_url" {
  description = "URL for linkding (after DNS is pointed to the nginx ingress LoadBalancer IP)"
  value       = "http://${var.linkding_hostname}"
}
