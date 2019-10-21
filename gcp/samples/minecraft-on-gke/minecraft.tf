locals {
  port_minecraft      = 25565
  label_app_minecraft = "minecraft"
}

provider "kubernetes" {
  host                   = "${google_container_cluster.minecraft-on-gke.endpoint}"
  token                  = "${data.google_client_config.current.access_token}"
  client_certificate     = "${base64decode(google_container_cluster.minecraft-on-gke.master_auth.0.client_certificate)}"
  client_key             = "${base64decode(google_container_cluster.minecraft-on-gke.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.minecraft-on-gke.master_auth.0.cluster_ca_certificate)}"
}

resource "google_compute_address" "default" {
  name   = "${local.network_name}"
  region = "${var.region}"
}

resource "kubernetes_namespace" "minecraft" {
  metadata {
    name = "${local.label_app_minecraft}"
  }
}

resource "kubernetes_persistent_volume_claim" "minecraft-data" {
  metadata {
    name      = "minecraft-data"
    namespace = "${kubernetes_namespace.minecraft.metadata.0.name}"

    labels = {
      app = "${local.label_app_minecraft}"
    }
  }
  spec {
    storage_class_name = "standard"
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_service" "minecraft" {
  metadata {
    name      = "${local.label_app_minecraft}"
    namespace = "${kubernetes_namespace.minecraft.metadata.0.name}"
  }

  spec {
    selector = {
      app = "${kubernetes_replication_controller.minecraft.metadata.0.labels.app}"
    }

    session_affinity = "ClientIP"

    port {
      protocol    = "TCP"
      port        = "${local.port_minecraft}"
      target_port = "${local.port_minecraft}"
    }

    type             = "LoadBalancer"
    load_balancer_ip = "${google_compute_address.default.address}"
  }
}

resource "kubernetes_replication_controller" "minecraft" {
  metadata {
    name      = "${local.label_app_minecraft}"
    namespace = "${kubernetes_namespace.minecraft.metadata.0.name}"

    labels = {
      app = "${local.label_app_minecraft}"
    }
  }

  spec {
    selector = {
      app = "${local.label_app_minecraft}"
    }

    template {
      metadata {
        labels = {
          app = "${local.label_app_minecraft}"
        }
      }
      spec {
        container {
          image = "itzg/minecraft-server:latest"
          name  = "${local.label_app_minecraft}"

          env {
            name  = "EULA"
            value = "true"
          }

          volume_mount {
            name       = "minecraft-data"
            mount_path = "/data"
          }

          liveness_probe {
            tcp_socket {
              port = "${local.port_minecraft}"
            }

            initial_delay_seconds = 30
            period_seconds        = 15
          }

          resources {
            limits {
              cpu    = "1.0"
              memory = "1.5Gi"
            }

            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }

        volume {
          name = "minecraft-data"
          persistent_volume_claim {
            claim_name = "minecraft-data"
          }
        }
      }
    }
  }
}

output "load-balancer-ip" {
  value = "${google_compute_address.default.address}"
}
