extension radius

resource env 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'local'
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'local'
    }
    recipes: {
      'Radius.Dapr/stateStores': {
        default: {
          templateKind: 'terraform'
          templatePath: 'git::https://github.com/radius-project/lab.git//002-order-console/radius/recipes/kubernetes/statestore'
        }
      }
      'Radius.Dapr/pubSubBrokers': {
        default: {
          templateKind: 'terraform'
          templatePath: 'git::https://github.com/radius-project/lab.git//002-order-console/radius/recipes/kubernetes/pubsub'
        }
      }
    }
  }
}
