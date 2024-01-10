# Step 2: Setup your Radius lab environment

Let's get you up and running with a lab environment for Radius. While Radius supports any Kubernetes cluster, the following steps will ensure the lab will proceed smoothly.

## 2.1 Pre-requisites

1. [kubectl](https://kubernetes.io/docs/tasks/tools/)
1. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
1. [rad CLI](https://docs.radapp.io/installation/)
1. [Visual Studio Code](https://code.visualstudio.com/download)
1. [Radius-Bicep extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.rad-vscode-bicep)

## 2.2 Create an AKS cluster

1. Create a new Azure Kubernetes Service (AKS) cluster using this template:

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fradius-project%2Flab%2Fmain%2Ftemplates%2Faks-cluster%2Fmain.json)
1. Merge your AKS credentials:

    ```bash
    az aks get-credentials --resource-group <resource-group> --name radius
    ```
1. Verify it's running by running `kubectl cluster-info`:

   ```
   Kubernetes control plane is running at https://host.docker.internal:64243
   CoreDNS is running at https://host.docker.internal:64243/api/v1/namespaces/kube-system/services/kube-dns:dns/   proxy
   Metrics-server is running at https://host.docker.internal:64243/api/v1/namespaces/kube-system/services/   https:metrics-server:https/proxy
   ```

## 2.3 Test the Radius CLI

Next, make sure you have the rad CLI installed and working:

```bash
rad version
```

You should see the following:

```
> rad version
RELEASE   VERSION   BICEP     COMMIT
0.29.0    v0.29.0   0.29.0    6abd7bfc3de0e748a2c34b721d95097afb6a2bba
```

## 2.4 Make sure you have the correct extensions installed

Radius is currently leveraging a fork of the [Bicep language](https://github.com/azure/bicep) while we work with them to upstream our extensibility features. During this phase, you need to ensure **you have disabled the official Bicep extension** and installed the Radius-Bicep extension. You can do this by opening the Extensions pane in VS Code and searching for "Bicep".

## Next step

Now that you have a lab environment setup, let's initialize a Radius environment on your Kubernetes cluster in [the next step](./03-initialize.md).
