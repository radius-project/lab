# Step 5: Deploy your application to Azure

Now that you've got your application running locally, let's deploy it to Azure.

## Step 5.1: Configure your Azure credentials and scope

In order for your Radius environment to be able to deploy resources into Azure, you'll need to configure your Azure credentials. Radius uses Azure service principals to authenticate with Azure, so you'll need to create a new service principal and configure it with the appropriate permissions.

1. Create a new service principal with Owner access to the resource group:

    ```bash
    az ad sp create-for-rbac -n radius-lab --role Owner --scopes /subscriptions/<your-subscription-id>/resourceGroups/<your-resource-group>
    ```
1. Add the new service principal credentials to your Radius installation. This will tell Radius _how_ to deploy Azure resources:

    ```bash
    rad credential register azure --client-id <app id> --client-secret <password> --tenant-id <tenant>
    ```
1. Update your Radius environment with your resource group. This will tell Radius _where_ to deploy Azure resources:

    ```bash
    rad env update default --azure-resource-group <resourcegroup-name> --azure-subscription-id <subscription-id>
    ```

## Step 5.2: Switch to an Azure Recipe

In order to deploy Azure infrastructure, **all you'll need to do is swap out the Recipe. There is no change needed to the application**. Run the following command to update your default Dapr state store Recipe with one that uses an Azure Storage Account instead of a Redis container:

```bash
rad recipe register default --resource-type Applications.Dapr/stateStores --template-kind bicep --template-path ghcr.io/radius-project/recipes/azure/statestores:latest
```

You can find the source for this Recipe [here](https://github.com/radius-project/recipes/blob/main/azure/statestores.bicep).

> 💡 Note that the application definition didn't need to change at all, just the Recipe template. When Radius & Dapr are combined, application definitions become fully portable across code + dependencies.

## Step 5.3: Re-run your application

Re-run your same `app.bicep` file, without any changes:

```bash
rad run app.bicep -a lab
```

You should see the same output as before, but this time your application is running in Azure!

Output the application graph again to see the new Azure resources that were deployed:

```bash
rad app graph lab
```

You should see the same app graph, but this time the Dapr state store is being hosted in Azure:

```
Name: demo (Applications.Core/containers)
Connections:
  statestore (Applications.Dapr/stateStores) -> demo
Resources:
  demo (apps/Deployment)
  demo (core/Secret)
  demo (core/Service)
  demo (core/ServiceAccount)
  demo (rbac.authorization.k8s.io/Role)
  demo (rbac.authorization.k8s.io/RoleBinding)

Name: statestore (Applications.Dapr/stateStores)
Connections: (none)
Resources:
  recipe2lkqwvspyl24g (Microsoft.Storage/storageAccounts) open portal
  default (Microsoft.Storage/storageAccounts/blobServices) open portal
  statestore (Microsoft.Storage/storageAccounts/blobServices/containers) open portal
  statestore (dapr.io/Component)
```

Try clicking on the `open portal` links to see the Azure resources that were deployed. You'll be deep-linked into the Azure portal for that specific resource.

## Step 5.4: Clean up

When you're done, you can clean up your application's resources, including the Azure resources, by running:

```bash
rad app delete lab -y
```

## Next steps

Now that we've taken our application and run it both locally and in Azure, let's take a look at one more feature of Radius, where you can use Radius with existing Kubernetes YAML. Check [it out here](./06-yaml.md).
