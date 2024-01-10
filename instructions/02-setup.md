# Step 2: Setup your Radius lab environment

Let's get you up and running with a lab environment for Radius. While Radius supports any Kubernetes cluster, the following steps will ensure the lab will proceed smoothly.

## Step 2.1: Launch a new GitHub Codespace (preferred)

The easiest way to try out Radius in this lab is via GitHub Codespaces. The best part is, they're free! Simply click the button below to launch a new Codespace:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/radius-project/lab)

Once launched, you can continue straight to the [next step](./03-initialize.md).

## Step 2.2: Setup a local lab environment

If you prefer to run the lab locally, you can follow these steps.

### Pre-requisites

1. [Docker](https://docs.docker.com/get-docker/)
1. [kubectl](https://kubernetes.io/docs/tasks/tools/)
1. [k3d CLI](https://k3d.io/#installation)
1. [Helm](https://helm.sh/docs/intro/install/)
1. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
1. [rad CLI](https://docs.radapp.io/installation/)
1. [Visual Studio Code](https://code.visualstudio.com/download)
1. [Radius-Bicep extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.rad-vscode-bicep)

### Create a local Kubernetes cluster

Create a new Kubernetes cluster using k3d:

```bash
k3d cluster create
```

This will spin up a lightweight Kubernetes cluster using Docker containers. You can verify it's running by running `kubectl cluster-info`:

```
Kubernetes control plane is running at https://host.docker.internal:64243
CoreDNS is running at https://host.docker.internal:64243/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://host.docker.internal:64243/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy
```

### Initialize Dapr

Next, initialize Dapr on your cluster:

```bash
dapr init -k
```

This will be used in a later step when we start adding some Dapr building blocks to our applications.

### Test the Radius CLI

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

### Make sure you have the correct extensions installed

Radius is currently leveraging a fork of the [Bicep language](https://github.com/azure/bicep) while we work with them to upstream our extensibility features. During this phase, you need to ensure **you have disabled the official Bicep extension** and installed the Radius-Bicep extension. You can do this by opening the Extensions pane in VS Code and searching for "Bicep".

## Next step

Now that you have a lab environment setup, let's initialize a Radius environment on your Kubernetes cluster in [the next step](./03-initialize.md).
