# Step 2: Setup your Radius lab environment

Let's get you up and running with a lab environment for Radius. While Radius supports any Kubernetes cluster, the following steps will ensure the lab will proceed smoothly.

## 2.1 Pre-requisites

Make sure you have the following tools installed on your machine:

1. [kubectl CLI](https://kubernetes.io/docs/tasks/tools/)
1. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
1. [Visual Studio Code](https://code.visualstudio.com/download)

## 2.2 Create an AKS cluster

1. Create a new Azure Kubernetes Service (AKS) cluster using this template:

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fradius-project%2Flab%2Fmain%2Ftemplates%2Faks-cluster%2Fmain.json)
1. Merge your AKS credentials:

    ```bash
    az aks get-credentials --resource-group <resource-group> --name radius --overwrite-existing
    ```
1. Verify it's running by running `kubectl cluster-info`:

   ```
   Kubernetes control plane is running at https://radius-dns-********.hcp.westus3.azmk8s.io:443
   CoreDNS is running at https://radius-dns-********.hcp.westus3.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
   Metrics-server is running at https://radius-dns-**********.hcp.westus3.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
   ```

## 2.3 Install the Radius CLI

1. Install the Radius (rad) CLI via the installation script:

   **Linux/WSL**
    
    ```bash
    wget -q "https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh" -O - | /bin/bash
    ```

    **MacOS**
     
     ```bash
     curl -fsSL "https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh" | /bin/bash
     ```
    
1. Next, make sure you can use the rad CLI:

   ```bash
   rad version
   ```

   You should see the following:
   
   ```
   > rad version
   RELEASE   VERSION   BICEP     COMMIT
   0.29.0    v0.29.0   0.29.0    6abd7bfc3de0e748a2c34b721d95097afb6a2bba
   ```

## 2.4 Install the Radius-Bicep VSCode extension

Radius is currently leveraging a fork of the [Bicep language](https://github.com/azure/bicep) while we work with them to upstream our extensibility features. During this phase, you need to ensure **you have disabled the official Bicep extension** and installed the Radius-Bicep extension.

1. Disable the Bicep extension, if you have it installed & enabled
1. Install the Radius-Bicep extension from the [VSCode Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.rad-vscode-bicep)

## Next step

Now that you have a lab environment setup, let's initialize a Radius environment on your Kubernetes cluster in [the next step](./03-initialize.md).
