extension radius

@description('Azure subscription ID for recipe resource provisioning')
param azureSubscriptionId string

@description('Azure resource group for recipe-provisioned resources')
param azureResourceGroup string

@description('Azure region for provisioned resources')
param location string = 'westus3'

resource env 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'azure'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'azure'
    }
    providers: {
      azure: {
        scope: '/subscriptions/${azureSubscriptionId}/resourceGroups/${azureResourceGroup}'
      }
    }
    recipes: {
      'Radius.AI/agents': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/lab/recipes/agent:1.0'
          parameters: {
            location: location
          }
        }
      }
      'Radius.Data/postgreSqlDatabases': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/lab/recipes/postgres:1.0'
          parameters: {
            location: location
          }
        }
      }
      'Radius.Storage/blobStorages': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/lab/recipes/blobstorage:1.0'
          parameters: {
            location: location
          }
        }
      }
    }
  }
}
