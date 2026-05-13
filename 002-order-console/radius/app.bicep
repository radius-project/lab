extension radius
extension radiusdapr

@description('The Radius environment to deploy to')
param environment string

@description('The application name')
param applicationName string = 'order-console'

@description('Container registry for the application images')
param registry string = 'ghcr.io/reshrahim'

@description('Image tag')
param tag string = 'latest'

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: applicationName
  location: 'global'
  properties: {
    environment: environment
  }
}

resource statestore 'Radius.Dapr/stateStores@2025-08-01-preview' = {
  name: 'statestore'
  properties: {
    application: app.id
    environment: environment
  }
}

resource pubsub 'Radius.Dapr/pubSubBrokers@2025-08-01-preview' = {
  name: 'pubsub'
  properties: {
    application: app.id
    environment: environment
  }
}

resource orders_api 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'orders-api'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: '${registry}/orders-api:${tag}'
      ports: {
        http: {
          containerPort: 3000
        }
      }
      env: any({
        APP_PORT: {
          value: '3000'
        }
        DAPR_HTTP_PORT: {
          value: '3500'
        }
      })
    }
    connections: {
      statestore: {
        source: statestore.id
      }
      pubsub: {
        source: pubsub.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'orders-api'
        appPort: 3000
      }
    ]
  }
}

resource fulfillment_worker 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'fulfillment-worker'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: '${registry}/fulfillment-worker:${tag}'
      ports: {
        http: {
          containerPort: 3002
        }
      }
      env: any({
        APP_PORT: {
          value: '3002'
        }
        DAPR_HTTP_PORT: {
          value: '3500'
        }
      })
    }
    connections: {
      statestore: {
        source: statestore.id
      }
      pubsub: {
        source: pubsub.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'fulfillment-worker'
        appPort: 3002
      }
    ]
  }
}

resource frontend_ui 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend-ui'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: '${registry}/order-ui:${tag}'
      ports: {
        http: {
          containerPort: 3000
        }
      }
      env: any({
        API_URL: {
          value: 'http://orders-api:3000'
        }
      })
    }
  }
}

