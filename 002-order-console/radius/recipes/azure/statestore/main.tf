terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

variable "context" {
  description = "Radius-provided context for the recipe"
  type        = any
}

variable "location" {
  description = "Azure region for provisioned resources"
  type        = string
}

locals {
  unique_name    = var.context.resource.name
  namespace      = var.context.runtime.kubernetes.namespace
  resource_group = var.context.azure.resourceGroup.name
  location       = var.location
  database       = "dapr_state"
  component_name = var.context.resource.name
  # Create a short unique suffix from the resource group name and location
  suffix = substr(md5("${local.resource_group}-${local.location}"), 0, 6)
}

# ── Azure Database for PostgreSQL Flexible Server ────────────

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}|:?,."
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "${local.unique_name}-pg-${local.suffix}"
  resource_group_name = local.resource_group
  location            = local.location
  version             = "16"

  administrator_login    = "pgadmin"
  administrator_password = random_password.password.result

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  zone = "1"

  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = local.database
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Allow Azure services (including AKS) to connect
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ── Dapr state store component (on AKS) ─────────────────────

resource "kubernetes_secret" "pg_credentials" {
  metadata {
    name      = "${local.unique_name}-pg-credentials"
    namespace = local.namespace
  }

  data = {
    connectionString = "host=${azurerm_postgresql_flexible_server.pg.fqdn} user=pgadmin password=${random_password.password.result} port=5432 database=${local.database} sslmode=require"
  }

  depends_on = [
    azurerm_postgresql_flexible_server_database.db,
    azurerm_postgresql_flexible_server_firewall_rule.allow_azure
  ]
}

resource "kubernetes_manifest" "dapr_statestore" {
  manifest = {
    apiVersion = "dapr.io/v1alpha1"
    kind       = "Component"
    metadata = {
      name      = local.component_name
      namespace = local.namespace
    }
    spec = {
      type    = "state.postgresql"
      version = "v1"
      metadata = [
        {
          name = "connectionString"
          secretKeyRef = {
            name = "${local.unique_name}-pg-credentials"
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
