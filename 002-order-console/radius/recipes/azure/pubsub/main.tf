###############################################################################
# Radius Recipe – Dapr pub/sub backed by Azure Event Hubs (Kafka protocol)
#
# Provisions:
#   • Azure Event Hubs Namespace (Standard, Kafka-enabled)
#   • Event Hub (topic: "orders")
#   • Consumer Group (fulfillment-group)
#   • Authorization Rule (Send + Listen)
#   • Kubernetes Secret with the Event Hubs connection string
#   • Dapr Component (pubsub.kafka) pointing to Event Hubs via SASL
###############################################################################

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
  }
}

# ── Radius context ───────────────────────────────────────────

variable "context" {
  description = "Radius-provided context for the recipe"
  type        = any
}

variable "location" {
  description = "Azure region for provisioned resources"
  type        = string
}

locals {
  name           = var.context.resource.name
  namespace      = var.context.runtime.kubernetes.namespace
  resource_group = var.context.azure.resourceGroup.name
  location       = var.location
  topic          = "orders"
  consumer_group = "fulfillment-group"
  # Create a short unique suffix from the resource group name and location
  suffix = substr(md5("${local.resource_group}-${local.location}"), 0, 6)
}

# ── Event Hubs Namespace (Kafka-enabled) ─────────────────────

resource "azurerm_eventhub_namespace" "ns" {
  name                = "${local.name}-${local.suffix}"
  location            = local.location
  resource_group_name = local.resource_group
  sku                 = "Standard"
  capacity            = 1

  tags = {
    "radius-app" = local.name
  }
}

# ── Event Hub (= Kafka topic) ───────────────────────────────

resource "azurerm_eventhub" "topic" {
  name              = local.topic
  namespace_id      = azurerm_eventhub_namespace.ns.id
  partition_count   = 2
  message_retention = 1
}

# ── Consumer Group ───────────────────────────────────────────

resource "azurerm_eventhub_consumer_group" "cg" {
  name                = local.consumer_group
  namespace_name      = azurerm_eventhub_namespace.ns.name
  eventhub_name       = azurerm_eventhub.topic.name
  resource_group_name = local.resource_group
}

# ── Shared Access Policy (Send + Listen) ─────────────────────

resource "azurerm_eventhub_namespace_authorization_rule" "dapr" {
  name                = "dapr-pubsub"
  namespace_name      = azurerm_eventhub_namespace.ns.name
  resource_group_name = local.resource_group
  listen              = true
  send                = true
  manage              = false
}

# ── Kubernetes Secret with connection string ─────────────────

resource "kubernetes_secret" "eventhub_credentials" {
  metadata {
    name      = "${local.name}-eventhub-credentials"
    namespace = local.namespace
  }

  data = {
    connectionString = azurerm_eventhub_namespace_authorization_rule.dapr.primary_connection_string
  }
}

# ── Dapr Component (pubsub.kafka over Event Hubs SASL) ──────

resource "kubernetes_manifest" "dapr_pubsub" {
  manifest = {
    apiVersion = "dapr.io/v1alpha1"
    kind       = "Component"
    metadata = {
      name      = local.name
      namespace = local.namespace
    }
    spec = {
      type    = "pubsub.kafka"
      version = "v1"
      metadata = [
        {
          name  = "brokers"
          value = "${azurerm_eventhub_namespace.ns.name}.servicebus.windows.net:9093"
        },
        {
          name  = "authType"
          value = "password"
        },
        {
          name  = "saslUsername"
          value = "$ConnectionString"
        },
        {
          name = "saslPassword"
          secretKeyRef = {
            name = "${local.name}-eventhub-credentials"
            key  = "connectionString"
          }
        },
        {
          name  = "saslMechanism"
          value = "PLAIN"
        },
        {
          name  = "initialOffset"
          value = "oldest"
        },
        {
          name  = "maxMessageBytes"
          value = "1048576"
        },
        {
          name  = "consumeRetryInterval"
          value = "200ms"
        },
        {
          name  = "version"
          value = "1.0.0"
        },
        {
          name  = "disableTls"
          value = "false"
        },
        {
          name  = "consumerGroup"
          value = local.consumer_group
        }
      ]
    }
  }

  depends_on = [kubernetes_secret.eventhub_credentials]
}

# ── Output ───────────────────────────────────────────────────

output "result" {
  value = {
    values = {
      componentName = var.context.resource.name
      topic         = local.topic
    }
  }
}
