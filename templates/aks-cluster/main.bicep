@description('The location where your cluster will be deployed. Defaults to the region of your Azure resource group.')
param location string = resourceGroup().location

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-08-03-preview' = {
  name: 'radius'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'radius-dns'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: 0
        count: 3
        vmSize: 'standard_d4ds_v5'
        osType: 'Linux'
        mode: 'System'
      }
    ]
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        config: {
          enableSecretRotation: 'false'
        }
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

resource daprExtension 'Microsoft.KubernetesConfiguration/extensions@2022-04-02-preview' = {
  name: 'dapr'
  scope: aksCluster
  properties: {
    extensionType: 'Microsoft.Dapr'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'dapr-system'
      }
    }
    configurationProtectedSettings: {}
  }
}

output controlPlaneFQDN string = aksCluster.properties.fqdn
output oidcIssuerURL string = aksCluster.properties.oidcIssuerProfile.issuerURL
