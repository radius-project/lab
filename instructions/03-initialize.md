# Step 3: Initialize a Radius environment

In this step, you'll initialize Radius and create a development-focused, "local-dev", environment on your Kubernetes cluster. This environment will be used to deploy your applications into and will contain all of the Recipes and configuration you'll need to get up and running during development.

## Step 3.1: Initialize Radius

Begin by running the following command to initialize Radius on your Kubernetes cluster:

```bash
rad init
```

When prompted to scaffold an application, select `No`:

You will see Radius being installed and configured on your cluster:

```
> rad init

Initializing Radius. This may take a minute or two...

🕖 Install Radius v0.29.0
   - Kubernetes cluster: k3d-k3s-default
   - Kubernetes namespace: radius-system
⏳ Create new environment default
   - Kubernetes namespace: default
   - Recipe pack: local-dev
⏳ Update local configuration
```

## Step 3.2: Verify Radius is running

Once the installation is complete, you can verify Radius is running by running the following command:

```bash
kubectl get pods -n radius-system
```

You'll see the Radius control-plane pods and some Contour pods running:

```
NAME                               READY   STATUS    RESTARTS   AGE
ucp-5d784f9b5d-rg7qk               1/1     Running   0          54s
applications-rp-697cdf6b-lp4gk     1/1     Running   0          54s
bicep-de-567fbc6c85-hnvzv          1/1     Running   0          54s
controller-74d4ccfb48-w4bf5        1/1     Running   0          54s
contour-envoy-hxhvr                2/2     Running   0          42s
contour-contour-6bbbd945d9-cqv8h   1/1     Running   0          42s
```

> 💡 Radius is not a Kubernetes controller. Instead, it leverages the Universal Control Plane service and Resource Providers just like Azure. The goal is for Radius to be able to run across any platform, not just Kubernetes. For more information on the Radius architecture, visit our [architecture docs](https://docs.radapp.io/concepts/architecture/).

## Step 3.3: Verify the environment was created

Next, you can verify the environment was created by running the following command:

```bash
rad env list
```

You should see your new, "default", environment listed:

```
RESOURCE  TYPE                            GROUP     STATE
default   Applications.Core/environments  default   Succeeded
```

> 💡 Radius resource types, such as environments and applications, have types like "Applications.Core/environments", which should look familiar if you've used Azure. This is because Radius' Universal Control Plane extends a lot of the ideas and architecture pioneered in Azure Resource Manager. UCP can interact with any Azure, Radius, or even AWS resource. You'll see more of this in a later step.

Let's take a look under the covers and learn more about the environment you just created. Run the following command to get the raw JSON API response for the environment:

```bash
rad env show default -o json
```

You should see the following payload:

```
{
  "id": "/planes/radius/local/resourcegroups/default/providers/Applications.Core/environments/default",
  "location": "global",
  "name": "default",
  "properties": {
    "compute": {
      "kind": "kubernetes",
      "namespace": "default"
    },
    "provisioningState": "Succeeded",
    "recipes": {
      "Applications.Dapr/pubSubBrokers": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/pubsubbrokers:0.29"
        }
      },
      "Applications.Dapr/secretStores": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/secretstores:0.29"
        }
      },
      "Applications.Dapr/stateStores": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/statestores:0.29"
        }
      },
      "Applications.Datastores/mongoDatabases": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/mongodatabases:0.29"
        }
      },
      "Applications.Datastores/redisCaches": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/rediscaches:0.29"
        }
      },
      "Applications.Datastores/sqlDatabases": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/sqldatabases:0.29"
        }
      },
      "Applications.Messaging/rabbitMQQueues": {
        "default": {
          "plainHttp": false,
          "templateKind": "bicep",
          "templatePath": "ghcr.io/radius-project/recipes/local-dev/rabbitmqqueues:0.29"
        }
      }
    }
  },
  "systemData": {},
  "tags": {},
  "type": "Applications.Core/environments"
}
```

A couple things to note about this response:

1. You'll see a list of Recipes that were added to the environment. These are infrastructure templates that can be used to deploy resources into the environment. You'll see how to use these in a later step.
1. The `compute` section shows that this environment is backed by Kubernetes and is uses the `default` namespace as a base. When applications are deployed into this environment, they will be deployed to Kubernetes, based on this namespace. In the future additional runtimes, such as serverless AWS/Azure infrastructure, can be supporterd here. But for now it's just Kubernetes.
1. The resource id, `/planes/radius/local/resourcegroups/default/providers/Applications.Core/environments/default`, looks a lot like an Azure Resource Manager (ARM) ID. Radius extends ARM to support any cloud, not just Azure, which introduces the concept of "planes". We'll pop back and explore this more in a later step.

## Step 3.4: Examine a Recipe

Let's take a look at one of the Recipes that was added to the environment. Run the following command to learn more about this Recipe:

```bash
rad recipe show default --resource-type "Applications.Dapr/stateStores"
```

You should see a table with information about the Recipe kind, template, and parameters:

```
RECIPE    TYPE                           TEMPLATE KIND  TEMPLATE VERSION  TEMPLATE
default   Applications.Dapr/stateStores  bicep                            ghcr.io/radius-project/recipes/local-dev/statestores:0.29

PARAMETER        TYPE      DEFAULT VALUE  MIN       MAX
tag              string    7              -         -
memoryRequest    string    128Mi          -         -
memoryLimit      string    1024Mi         -         -
actorStateStore  bool      false          -         -
```

> 💡 Bicep Recipes leverage Bicep module registries, which are a way for Bicep modules to be stored in a container registry via the [Open Container Initiative](https://opencontainers.org/) spec. The Radius team maintains a set of [community Recipes](https://github.com/radius-project/recipes), such as these local-dev Recipes.

Let's take a look at the Bicep template that defines this Recipe. Visit https://github.com/radius-project/recipes/blob/main/local-dev/statestores.bicep to view the source template. You'll see that it's a standard Bicep template with some Kubernetes resources defined to run a lightweight Redis Cache, plus the Dapr component. When a developer asks for a Dapr State Store, this template will be used to deploy it automatically.

## Next step

Now that you have an environment ready to go, let's move on to the next step where you'll author your first Radius application and deploy it to the environment. [Next: Step 4: Deploy a Radius application](./04-application.md).
