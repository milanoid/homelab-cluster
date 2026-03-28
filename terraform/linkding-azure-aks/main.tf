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

# -----------------------------------------------------------------------
# Storage
# "managed-csi" is the default AKS storage class backed by Azure Managed Disks.
# ReadWriteOnce is required — Azure Disks do not support ReadWriteMany.
# -----------------------------------------------------------------------
resource "kubernetes_persistent_volume_claim" "linkding_data" {
  metadata {
    name      = "linkding-data-pvc"
    namespace = kubernetes_namespace.linkding.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "managed-csi"

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
# Ingress — nginx ingress controller (LoadBalancer, public IP from Azure)
#
# Prerequisites: nginx ingress controller must be installed on the cluster.
# The easiest way is via the AKS HTTP application routing add-on, or by
# deploying the ingress-nginx Helm chart:
#
#   helm install ingress-nginx ingress-nginx/ingress-nginx \
#     --namespace ingress-nginx --create-namespace \
#     --set controller.service.type=LoadBalancer
#
# After apply, point var.linkding_hostname DNS A record to the nginx
# LoadBalancer IP shown in `kubectl get svc -n ingress-nginx`.
# -----------------------------------------------------------------------
resource "kubernetes_ingress_v1" "linkding" {
  metadata {
    name      = "linkding"
    namespace = kubernetes_namespace.linkding.metadata[0].name

    annotations = {
      # Force HTTPS redirect (requires cert-manager or a TLS secret)
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.linkding_hostname

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
