
extension radius

@description('Azure subscription ID for recipe resource provisioning')
param azureSubscriptionId string

@description('Azure resource group for recipe-provisioned resources')
param azureResourceGroup string

@description('Azure region for provisioned resources')
param location string = 'westus3'

resource env 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'azure'
  location: 'global'
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
      'Radius.Dapr/stateStores': {
        default: {
          templateKind: 'terraform'
          templatePath: 'git::https://github.com/radius-project/lab.git//002-order-console/radius/recipes/azure/statestore'
          parameters: {
            location: location
          }
        }
      }
      'Radius.Dapr/pubSubBrokers': {
        default: {
          templateKind: 'terraform'
          templatePath: 'git::https://github.com/radius-project/lab.git//002-order-console/radius/recipes/azure/pubsub'
          parameters: {
            location: location
          }
        }
      }
    }
  }
}
