resource "kubernetes_deployment" "metaflow-ui-backend-service" {
  wait_for_rollout = false
  metadata {
    name = "metaflow-ui-backend-service"
    namespace= "default"
  }
  spec {
    selector {
      match_labels = {
        app = "metaflow-ui-backend-service"
      }
    }
    template {
      metadata {
        labels = {
          app  = "metaflow-ui-backend-service"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.metaflow_service_account.metadata[0].name
        container {
          name = "metaflow-ui-backend-service-cloud-sql-proxy"
          # image = "gcr.io/cloudsql-docker/gce-proxy:1.28.0"
          # command = ["/cloud_sql_proxy", "-ip_address_types=PRIVATE", "-log_debug_stdout",
          #   "-instances=${var.db_connection_name}=tcp:${var.metaflow_db_port}"]

          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.7.1"
          args = [
            "--private-ip",
            "--structured-logs",
            "--port=${var.metaflow_db_port}",
            "${var.db_connection_name}"
          ]

          security_context {
            run_as_non_root = true
          }
          resources {
            requests = {
              memory = "1Gi"
              cpu = "1000m"
            }
          }
        }
        container {
          image = var.metaflow_ui_backend_service_image
          name  = "metaflow-ui-backend-service"
          command = ["/opt/latest/bin/python3", "-m", "services.ui_backend_service.ui_server" ]
          port {
            container_port = 8083
            name =  "http"
            protocol = "TCP"
          }
          liveness_probe {
            http_get {
              path = "/api/ping"
              port = "http"
            }
          }
          readiness_probe {
            http_get {
              path = "/api/ping"
              port = "http"
            }
          }
          resources {
            requests = {
              memory = "2G"
              cpu = "1000m"
            }
          }
          env {
            name = "UI_ENABLED"
            value = "1"
          }
          env {
            name = "PATH_PREFIX"
            value = "/api"
          }
          env {
            name = "MF_DATASTORE_ROOT"
            value = var.metaflow_datastore_sysroot_gs
          }
          env {
            # "metadata" service is more accurate.
            name = "METAFLOW_SERVICE_URL"
            value = "http://metadata-service:8080/"
          }
          env {
            name = "METAFLOW_DEFAULT_DATASTORE"
            value = "gs"
          }
          env {
            name = "METAFLOW_DATASTORE_SYSROOT_GS"
            value = var.metaflow_datastore_sysroot_gs
          }
          env {
            name ="METAFLOW_DEFAULT_METADATA"
            value = "service"
          }
          env {
            name = "MF_METADATA_DB_NAME"
            value = var.metaflow_db_name
          }
          env {
            name = "MF_METADATA_DB_PORT"
            value = var.metaflow_db_port
          }
          env {
            name = "MF_METADATA_DB_USER"
            value = var.metaflow_db_user
          }
          env {
            name = "MF_METADATA_DB_PSWD"
            value = var.metaflow_db_password
          }
          env {
            name = "MF_METADATA_DB_HOST"
            value = var.metaflow_db_host
          }
          env {
            name = "ORIGIN_TO_ALLOW_CORS_FROM"
            value = "*"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "metaflow-ui-backend-service" {
  metadata {
    name = "metaflow-ui-backend-service"
    namespace = "default"
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = "metaflow-ui-backend-service"
    }
    port {
      port        = 8083
      target_port = 8083
      protocol = "TCP"
    }
  }
}