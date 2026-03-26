extension radius
extension radiusAi
extension radiusData
extension radiusStorage

@description('The Radius environment to deploy to')
param environment string

@description('Container registry for the application images')
param registry string = 'ghcr.io/radius-project/lab'

@description('Image tag')
param tag string = '1.0'

@description('Azure OpenAI model deployment name')
param model string = 'gpt-4.1-mini'

@description('System prompt for the agent')
param prompt string = loadTextContent('../src/prompt.txt')

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'contoso-support-agent'
  properties: {
    environment: environment
  }
}

// Shared resource Orders Database : postgreSqlDatabases
resource postgresql 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' existing = {
  name: 'contoso-db'
}

// Shared resource Store Policies : blobStorages
resource blobstorage 'Radius.Storage/blobStorages@2025-08-01-preview' existing = {
  name: 'contoso-knowledge-base'
}

// ── Customer Service Agent : agents ─────────────────────────
resource agent 'Radius.AI/agents@2025-08-01-preview' = {
  name: 'support-agent'
  properties: {
    application: app.id
    environment: environment
    prompt: prompt
    model: model
    enableObservability: true
    connections: {
      postgres: {
        source: postgresql.id
      }
      blobstorage: {
        source: blobstorage.id
      }
    }
  }
}

// ── Front End : containers ────────────────────────────────────
resource frontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend-ui'
  properties: {
    application: app.id
    environment: environment
    container: {
      image: '${registry}/frontend-ui:${tag}'
      ports: {
        http: {
          containerPort: 3000
        }
      }
    }
    connections: {
      agent: {
        source: agent.id
      }
    }
  }
}
