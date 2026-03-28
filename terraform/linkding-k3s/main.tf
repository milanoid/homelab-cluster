# -----------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------
resource "kubernetes_namespace" "linkding" {
  metadata {
    name = "linkding"
  }
}

# -----------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------
resource "kubernetes_secret" "linkding_superuser" {
  metadata {
    name      = "linkding-super-user"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  data = {
    LD_SUPERUSER_NAME     = var.linkding_superuser_name
    LD_SUPERUSER_PASSWORD = var.linkding_superuser_password
  }
}

resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-credentials"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  data = {
    "credentials.json" = var.tunnel_credentials_json
  }
}

# -----------------------------------------------------------------------
# Storage — local-path is the default K3s storage class
# -----------------------------------------------------------------------
resource "kubernetes_persistent_volume_claim" "linkding_data" {
  metadata {
    name      = "linkding-data-pvc"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

# -----------------------------------------------------------------------
# Linkding Deployment
# -----------------------------------------------------------------------
resource "kubernetes_deployment" "linkding" {
  metadata {
    name      = "linkding"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "linkding"
      }
    }

    template {
      metadata {
        labels = {
          app = "linkding"
        }
      }

      spec {
        container {
          name  = "linkding"
          image = var.linkding_image

          port {
            container_port = 9090
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.linkding_superuser.metadata[0].name
            }
          }

          volume_mount {
            name       = "linkding-data"
            mount_path = "/etc/linkding/data"
          }

          security_context {
            allow_privilege_escalation = false
            run_as_user                = 33 # www-data
          }
        }

        volume {
          name = "linkding-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.linkding_data.metadata[0].name
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------
# Service
# -----------------------------------------------------------------------
resource "kubernetes_service" "linkding" {
  metadata {
    name      = "linkding"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    selector = {
      app = "linkding"
    }

    port {
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------
# Traefik Ingress — LAN/VPN access
# -----------------------------------------------------------------------
resource "kubernetes_ingress_v1" "linkding" {
  metadata {
    name      = "linkding"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.linkding_internal_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.linkding.metadata[0].name
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------
# Cloudflare Tunnel — public internet access
# -----------------------------------------------------------------------
resource "kubernetes_config_map" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  data = {
    "config.yaml" = <<-EOT
      tunnel: ${var.tunnel_name}
      credentials-file: /etc/cloudflared/creds/credentials.json
      metrics: 0.0.0.0:2000
      no-autoupdate: true

      ingress:
        - hostname: ${var.linkding_public_hostname}
          service: http://linkding:9090
        - service: http_status:404
    EOT
  }
}

resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:2026.3.0"

          args = [
            "tunnel",
            "--config", "/etc/cloudflared/config/config.yaml",
            "run",
          ]

          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            failure_threshold     = 1
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/cloudflared/config"
            read_only  = true
          }

          volume_mount {
            name       = "creds"
            mount_path = "/etc/cloudflared/creds"
            read_only  = true
          }
        }

        volume {
          name = "creds"
          secret {
            secret_name = kubernetes_secret.tunnel_credentials.metadata[0].name
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.cloudflared.metadata[0].name
            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }
      }
    }
  }
}
