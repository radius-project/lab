terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

variable "context" {
  description = "This variable contains Radius Recipe context."
  type        = any
}

variable "memory" {
  description = "Memory limits for the PostgreSQL container"
  type = map(object({
    memoryRequest = string
  }))
  default = {
    S = {
      memoryRequest = "512Mi"
    },
    M = {
      memoryRequest = "1Gi"
    },
    L = {
      memoryRequest = "2Gi"
    }
  }
}

locals {
  uniqueName    = var.context.resource.name
  port          = 5432
  namespace     = var.context.runtime.kubernetes.namespace
  size          = try(var.context.resource.properties.size, "S")
  database      = "dapr_state"
  componentName = var.context.resource.name
}

resource "random_password" "password" {
  length  = 16
  special = false
}

# ── PostgreSQL deployment (backing store) ────────────────────

resource "kubernetes_deployment" "postgresql" {
  metadata {
    name      = "${local.uniqueName}-pg"
    namespace = local.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "${local.uniqueName}-pg"
      }
    }

    template {
      metadata {
        labels = {
          app = "${local.uniqueName}-pg"
        }
      }

      spec {
        container {
          image = "postgres:16-alpine"
          name  = "postgres"
          resources {
            requests = {
              memory = var.memory[local.size].memoryRequest
            }
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = random_password.password.result
          }
          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_DB"
            value = local.database
          }
          port {
            container_port = local.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgresql" {
  metadata {
    name      = "${local.uniqueName}-pg"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "${local.uniqueName}-pg"
    }

    port {
      port        = local.port
      target_port = local.port
    }
  }
}

# ── Dapr state store component ───────────────────────────────

resource "kubernetes_secret" "pg_credentials" {
  metadata {
    name      = "${local.uniqueName}-pg-credentials"
    namespace = local.namespace
  }

  data = {
    connectionString = "host=${local.uniqueName}-pg.${local.namespace}.svc.cluster.local user=postgres password=${random_password.password.result} port=${local.port} database=${local.database} sslmode=disable"
  }

  depends_on = [kubernetes_service.postgresql]
}

resource "kubernetes_manifest" "dapr_statestore" {
  manifest = {
    apiVersion = "dapr.io/v1alpha1"
    kind       = "Component"
    metadata = {
      name      = local.componentName
      namespace = local.namespace
    }
    spec = {
      type    = "state.postgresql"
      version = "v1"
      metadata = [
        {
          name = "connectionString"
          secretKeyRef = {
            name = "${local.uniqueName}-pg-credentials"
            key  = "connectionString"
          }
        },
        {
          name  = "actorStateStore"
          value = "false"
        },
        {
          name  = "keyPrefix"
          value = "none"
        }
      ]
    }
  }

  depends_on = [kubernetes_secret.pg_credentials]
}

# ── Output ───────────────────────────────────────────────────

output "result" {
  value = {
    values = {
      componentName = var.context.resource.name
    }
  }
}
