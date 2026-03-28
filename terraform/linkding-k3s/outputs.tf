output "namespace" {
  description = "Kubernetes namespace where linkding is deployed"
  value       = kubernetes_namespace.linkding.metadata[0].name
}

output "internal_url" {
  description = "Internal URL for linkding (accessible via LAN/VPN through Traefik)"
  value       = "https://${var.linkding_internal_hostname}"
}

output "public_url" {
  description = "Public URL for linkding (accessible via Cloudflare tunnel)"
  value       = "https://${var.linkding_public_hostname}"
}

output "service_cluster_ip" {
  description = "ClusterIP of the linkding service"
  value       = kubernetes_service.linkding.spec[0].cluster_ip
}
