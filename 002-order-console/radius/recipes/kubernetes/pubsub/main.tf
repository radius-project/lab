terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

variable "context" {
  description = "Radius-provided context for the recipe"
  type        = any
}

locals {
  name           = var.context.resource.name
  namespace      = var.context.runtime.kubernetes.namespace
  broker_port    = 9092
  consumer_group = "fulfillment-group"
}

# Deploy Kafka (KRaft mode, no Zookeeper)
resource "kubernetes_deployment" "kafka" {
  metadata {
    name      = local.name
    namespace = local.namespace
  }

  spec {
    selector {
      match_labels = {
        app = local.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.name
        }
      }

      spec {
        container {
          name  = "kafka"
          image = "apache/kafka:latest"

          port {
            container_port = local.broker_port
          }

          env {
            name  = "KAFKA_NODE_ID"
            value = "0"
          }
          env {
            name  = "KAFKA_PROCESS_ROLES"
            value = "controller,broker"
          }
          env {
            name  = "KAFKA_CONTROLLER_QUORUM_VOTERS"
            value = "0@localhost:9093"
          }
          env {
            name  = "KAFKA_LISTENERS"
            value = "PLAINTEXT://:${local.broker_port},CONTROLLER://:9093"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://${local.name}.${local.namespace}.svc.cluster.local:${local.broker_port}"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
          }
          env {
            name  = "KAFKA_CONTROLLER_LISTENER_NAMES"
            value = "CONTROLLER"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }
          env {
            name  = "CLUSTER_ID"
            value = "MkU3OEVBNTcwNTJENDM2Qk"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka" {
  metadata {
    name      = local.name
    namespace = local.namespace
  }

  spec {
    selector = {
      app = local.name
    }

    port {
      port        = local.broker_port
      target_port = local.broker_port
    }
  }
}

# Create the Dapr Component pointing to Kafka
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
          value = "${kubernetes_service.kafka.metadata[0].name}.${kubernetes_service.kafka.metadata[0].namespace}.svc.cluster.local:${local.broker_port}"
        },
        {
          name  = "consumerGroup"
          value = local.consumer_group
        },
        {
          name  = "authType"
          value = "none"
        },
        {
          name  = "disableTls"
          value = "true"
        }
      ]
    }
  }

  depends_on = [kubernetes_deployment.kafka]
}

output "result" {
  value = {
    values = {
      componentName = var.context.resource.name
      topic         = "orders"
    }
  }
}
