provider "google" {
  project = var.project
  region  = var.region
}

data "google_client_config" "default" {
}

data "google_container_cluster" "default" {
  name     = var.cluster
  location = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.default.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.default.master_auth[0].cluster_ca_certificate)
}

# ip & dns record & certificate
resource "google_compute_global_address" "default" {
  name = "appchain-faucet-global-address"
}

data "google_dns_managed_zone" "default" {
  name = var.dns_zone
}

resource "google_dns_record_set" "a" {
  name         = "appchain.faucet.${data.google_dns_managed_zone.default.dns_name}"
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.default.address]
}

resource "google_dns_record_set" "caa" {
  name         = "appchain.faucet.${data.google_dns_managed_zone.default.dns_name}"
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "CAA"
  ttl          = 300
  rrdatas      = ["0 issue \"pki.goog\""]
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "appchain-faucet-managed-certificate"
      namespace = var.namespace
    }
    spec = {
      domains = [trimsuffix(google_dns_record_set.a.name, ".")]
    }
  }
}

resource "kubernetes_config_map" "default" {
  metadata {
    name      = "appchain-faucet-config-map"
    namespace = var.namespace
  }
  data = var.APPCHAIN_CONF
}

# sts svc ing...
resource "kubernetes_stateful_set" "default" {
  metadata {
    name = "appchain-faucet"
    labels = {
      app = "appchain-faucet"
    }
    namespace = data.kubernetes_namespace.default.metadata.0.name
  }
  spec {
    replicas = var.appchain_faucet.replicas
    selector {
      match_labels = {
        app = "appchain-faucet"
      }
    }
    template {
      metadata {
        labels = {
          app = "appchain-faucet"
        }
      }
      spec {
        container {
          name  = "appchain-faucet"
          image = var.appchain_faucet.image
          env_from {
            config_map_ref {
              name = kubernetes_config_map.default.metadata.0.name
            }
          }
          resources {
            limits = {
              cpu    = var.appchain_faucet.resources.cpu_limits
              memory = var.appchain_faucet.resources.memory_limits
            }
            requests = {
              cpu    = var.appchain_faucet.resources.cpu_requests
              memory = var.appchain_faucet.resources.memory_requests
            }
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].resources
    ]
  }
}

resource "kubernetes_manifest" "default" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "appchain-faucet-backendconfig"
      namespace = var.namespace
    }
    spec = {
      healthCheck = {
        type        = "HTTP"
        requestPath = "/status"
        port        = 80
      }
    }
  }
}

resource "kubernetes_service" "default" {
  metadata {
    name      = "appchain-faucet"
    namespace = var.namespace
    labels = {
      app  = "appchain-faucet"
    }
    annotations = {
      "cloud.google.com/neg"            = "{\"ingress\": true}"
      "cloud.google.com/backend-config" = "{\"default\": \"appchain-faucet-backendconfig\"}"
    }
  }
  spec {
    type = "NodePort"
    selector = {
      app = "appchain-faucet"
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      name        = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "default" {
  metadata {
    name      = "appchain-faucet-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.default.name
      "networking.gke.io/managed-certificates"      = "appchain-faucet-managed-certificate"
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.allow-http"            = "true"
    }
  }
  spec {
    default_backend {
      service {
        name = "appchain-faucet"
        port {
          number = 80
        }
      }
    }
  }
}