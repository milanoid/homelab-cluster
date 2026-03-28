variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the k3s cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubeconfig context to use (leave empty to use current context)"
  type        = string
  default     = ""
}

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

variable "tunnel_credentials_json" {
  description = "Cloudflare tunnel credentials JSON (contents of credentials.json)"
  type        = string
  sensitive   = true
}

variable "tunnel_name" {
  description = "Cloudflare tunnel name as configured in the tunnel credentials"
  type        = string
  default     = "cftunnel"
}

variable "linkding_internal_hostname" {
  description = "Internal hostname for Traefik ingress (LAN/VPN access)"
  type        = string
  default     = "linkding.milanoid.net"
}

variable "linkding_public_hostname" {
  description = "Public hostname routed through Cloudflare tunnel"
  type        = string
  default     = "lkd.milanoid.net"
}

variable "storage_size" {
  description = "PVC size for linkding data"
  type        = string
  default     = "1Gi"
}
