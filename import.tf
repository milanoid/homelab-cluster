terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"  # Default kubeconfig location
  # OR if you want to be explicit about context:
  # config_context = "your-cluster-context"
}

# deployments.tf
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = "linkding" # adjust if different
  }

  spec {
    replicas = 1 # check actual replica count

    selector {
      match_labels = {
        app = "cloudflared" # check actual labels
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
          image = "cloudflare/cloudflared:latest" # check actual image
          # Add other container specs as needed
        }
      }
    }
  }
}

resource "kubernetes_deployment" "linkding" {
  metadata {
    name      = "linkding"
    namespace = "linkding"
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
          image = "sissbruecker/linkding:1.42.0"
          # Add other container specs
        }
      }
    }
  }
}
