extension radius

@description('Radius-provided context for the recipe')
param context object

@description('Azure region for provisioned resources (defaults to resource group location)')
param location string = resourceGroup().location

// ── Resolve properties from Radius context ──────────────────

@description('Model version string for the Azure OpenAI deployment')
param modelVersion string = '2025-04-14'

var name = context.resource.name
var application = context.resource.properties.application
var environment = context.resource.properties.environment
var prompt = context.resource.properties.prompt
var model = context.resource.properties.?model ?? 'gpt-4.1-mini'
var knowledgeBase = '${name}-kb'
var enableObservability = context.resource.properties.?enableObservability ?? true
var agentImage = 'ghcr.io/radius-project/lab/agent-runtime:1.0'
var openAiSkuName = 'S0'

// Postgres connection from environment (passed via connections)
var postgresHost = context.resource.connections.?postgres.?properties.?host ?? ''
var postgresPort = context.resource.connections.?postgres.?properties.?port ?? ''
var postgresDatabase = context.resource.connections.?postgres.?properties.?database ?? ''
var postgresUser = context.resource.connections.?postgres.?properties.?user ?? ''
var postgresPassword = context.resource.connections.?postgres.?properties.?password ?? ''

// Blob storage connection from environment (passed via connections)
var storageEndpoint = context.resource.connections.?blobstorage.?properties.?endpoint ?? ''
var storageAccountName = context.resource.connections.?blobstorage.?properties.?accountName ?? ''
var storageAccountKey = context.resource.connections.?blobstorage.?properties.?accountKey ?? ''
var storageContainer = context.resource.connections.?blobstorage.?properties.?container ?? 'documents'

var uniqueSuffix = take(uniqueString(context.resource.id, resourceGroup().id), 8)

var tags = {
  'radius-app': name
  'radius-resource-type': 'Radius.AI/agents'
}

// ── Managed Identity ────────────────────────────────────────
// Used by the deployment script to set up AI Search indexes.
// The agent-runtime container uses API keys instead of managed identity

resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-identity'
  location: location
  tags: tags
}

// ── Log Analytics Workspace ─────────────────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${name}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ── Application Insights ────────────────────────────────────

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-insights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ── Azure AI Search ─────────────────────────────────────────

resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${name}-search-${uniqueSuffix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// ── Azure OpenAI ────────────────────────────────────────────

resource openAi 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: '${name}-openai-${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: openAiSkuName
  }
  properties: {
    customSubDomainName: '${name}-openai-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAi
  name: model
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model
      version: modelVersion
    }
  }
}

// ── Agent Runtime Container ─────────────────────────────────
// Deployed as a Radius container on the same K8s cluster.

resource agentRuntime 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'agent-runtime'
  location: 'global'
  properties: {
    application: application
    environment: environment
    container: {
      image: agentImage
      imagePullPolicy: 'Always'
      ports: {
        http: {
          containerPort: 8000
        }
      }
      env: any({
        AGENT_PROMPT: {
          value: prompt
        }
        CONNECTION_MODEL_ENDPOINT: {
          value: openAi.properties.endpoint
        }
        CONNECTION_MODEL_DEPLOYMENT: {
          value: model
        }
        CONNECTION_SEARCH_ENDPOINT: {
          value: 'https://${aiSearch.name}.search.windows.net'
        }
        CONNECTION_SEARCH_INDEX: {
          value: knowledgeBase
        }
        CONNECTION_STORAGE_ENDPOINT: {
          value: storageEndpoint
        }
        CONNECTION_STORAGE_KEY: {
          value: storageAccountKey
        }
        CONNECTION_MODEL_APIKEY: {
          value: openAi.listKeys().key1
        }
        CONNECTION_SEARCH_APIKEY: {
          value: listAdminKeys(aiSearch.id, aiSearch.apiVersion).primaryKey
        }
        CONNECTION_INSIGHTS_CONNECTIONSTRING: {
          value: appInsights.properties.ConnectionString
        }
        CONNECTION_POSTGRES_HOST: {
          value: postgresHost
        }
        CONNECTION_POSTGRES_PORT: {
          value: string(postgresPort)
        }
        CONNECTION_POSTGRES_DATABASE: {
          value: postgresDatabase
        }
        CONNECTION_POSTGRES_USER: {
          value: postgresUser
        }
        CONNECTION_POSTGRES_PASSWORD: {
          value: postgresPassword
        }
      })
    }
  }
}

// ── Role Assignments ────────────────────────────────────────
// These roles are for the deployment script identity and AI Search indexer.
// The agent-runtime container authenticates via API keys (see note above on managed identity).

// AI Search system identity → read blobs for indexing
var storageBlobDataReaderRole = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource searchBlobReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountName, aiSearch.id, storageBlobDataReaderRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRole)
    principalId: aiSearch.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Agent identity → manage search indexes, data sources, indexers (deployment script)
var searchServiceContributorRole = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'

resource searchContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, agentIdentity.id, searchServiceContributorRole)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRole)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Search Index Setup (data source → index → indexer) ─────

resource searchSetup 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${name}-search-setup'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agentIdentity.id}': {}
    }
  }
  dependsOn: [
    searchContributorRoleAssignment
  ]
  properties: {
    azCliVersion: '2.63.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    environmentVariables: [
      { name: 'SEARCH_ENDPOINT', value: 'https://${aiSearch.name}.search.windows.net' }
      {
        name: 'STORAGE_CONNECTION_STRING'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
      }
      { name: 'STORAGE_CONTAINER', value: storageContainer }
      { name: 'INDEX_NAME', value: knowledgeBase }
    ]
    scriptContent: '''#!/bin/bash
set -e

API="2024-07-01"

echo "Creating data source ${INDEX_NAME}-ds ..."
az rest --method PUT \
  --url "${SEARCH_ENDPOINT}/datasources/${INDEX_NAME}-ds?api-version=${API}" \
  --resource "https://search.azure.com" \
  --body "{\"name\":\"${INDEX_NAME}-ds\",\"type\":\"azureblob\",\"credentials\":{\"connectionString\":\"${STORAGE_CONNECTION_STRING}\"},\"container\":{\"name\":\"${STORAGE_CONTAINER}\"}}"

echo "Creating index ${INDEX_NAME} ..."
az rest --method PUT \
  --url "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=${API}" \
  --resource "https://search.azure.com" \
  --body "{\"name\":\"${INDEX_NAME}\",\"fields\":[{\"name\":\"id\",\"type\":\"Edm.String\",\"key\":true,\"filterable\":true},{\"name\":\"content\",\"type\":\"Edm.String\",\"searchable\":true,\"retrievable\":true,\"analyzer\":\"standard.lucene\"},{\"name\":\"title\",\"type\":\"Edm.String\",\"searchable\":true,\"filterable\":true,\"sortable\":true,\"retrievable\":true},{\"name\":\"metadata_storage_path\",\"type\":\"Edm.String\",\"filterable\":true,\"retrievable\":true}]}"

echo "Creating indexer ${INDEX_NAME}-indexer ..."
az rest --method PUT \
  --url "${SEARCH_ENDPOINT}/indexers/${INDEX_NAME}-indexer?api-version=${API}" \
  --resource "https://search.azure.com" \
  --body "{\"name\":\"${INDEX_NAME}-indexer\",\"dataSourceName\":\"${INDEX_NAME}-ds\",\"targetIndexName\":\"${INDEX_NAME}\",\"schedule\":{\"interval\":\"PT5M\"},\"fieldMappings\":[{\"sourceFieldName\":\"metadata_storage_path\",\"targetFieldName\":\"id\",\"mappingFunction\":{\"name\":\"base64Encode\"}},{\"sourceFieldName\":\"metadata_storage_name\",\"targetFieldName\":\"title\"}],\"parameters\":{\"configuration\":{\"dataToExtract\":\"contentAndMetadata\"}}}"

echo "Search setup complete."
'''
  }
}

// ── Output ──────────────────────────────────────────────────

output result object = {
  values: {
    agentEndpoint: 'http://agent-runtime:8000'
  }
  resources: [
    agentIdentity.id
    logAnalytics.id
    openAi.id
    aiSearch.id
    appInsights.id
  ]
}
