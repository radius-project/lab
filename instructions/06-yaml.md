# Step 6: Annote existing YAML with Radius

In this step, you'll learn how to use Radius to annotate existing Kubernetes YAML files with Radius metadata. This allows you to use Radius with existing Kubernetes YAML files.

## Step 6.1: Define a YAML file

Let's start by defining a simple YAML file that we'll use for this step. Create a file called `app.yaml`:

```bash
code app.yaml
```

and paste in the following:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
  namespace: default
spec:
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: demo
        image: ghcr.io/radius-project/samples/demo:latest
        ports:
        - containerPort: 3000
```

## Step 6.2: Annotate the YAML file

Now, let's annotate this YAML file with Radius metadata. Add the following annotations to the Deployments (_**not** in the spec_):

```diff
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
  namespace: default
+ annotations:
+   radapp.io/enabled: "true"
+   radapp.io/application: "lab-yaml"
spec:
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: demo
        image: ghcr.io/radius-project/samples/demo:latest
        ports:
        - containerPort: 3000
```

## Step 6.3: Apply the YAML file

1. Apply this YAML file to your Kubernetes cluster:

   ```bash
   kubectl apply -f app.yaml
   ```

1. Verify the resources were created by running:

   ```bash
   kubectl get pods
   ```
   
   You should see the following:
   
   ```
   NAME                    READY   STATUS    RESTARTS   AGE
   demo-5f4d88b6f9-964pb   1/1     Running   0          6s
   ```

1. Show the Radius app graph for the `lab-yaml` app:

   ```bash
   rad app graph lab-yaml -g default-lab-yaml
   ```

   _Note: the `-g` flag is used to specify the resource group. The Kubernetes controller, which is acting as a client for Radius in this step, automatically creates a resource group for you based on the namespace and name of the application._

   You should see the following, showing your Radius application:
   
   ```
   Displaying application: lab-yaml
   
   Name: demo (Applications.Core/containers)
   Connections: (none)
   Resources:
     demo (apps/Deployment)
   ```

## Step 6.4: Add a Recipe

Now, let's add a Recipe to the application. This will allow us to add a Redis Cache to the application with only a few lines of YAML:

1. Add the following to the end of the YAML file:

   ```yaml
   ---
   apiVersion: radapp.io/v1alpha3
   kind: Recipe
   metadata:
     name: db
     namespace: default
   spec:
     type: Applications.Datastores/redisCaches
     application: lab-yaml
   ```

1. Re-apply the YAML file:

   ```bash
   kubectl apply -f app.yaml
   ```

1. Show your application graph again:

   ```bash
   rad app graph lab-yaml -g default-lab-yaml
   ```

   You should see the following, showing your Radius application, now with a Redis Cache:

   ```
   Displaying application: lab-yaml
   
   Name: demo (Applications.Core/containers)
   Connections: (none)
   Resources:
     demo (apps/Deployment)
   
   Name: db (Applications.Datastores/redisCaches)
   Connections: (none)
   Resources:
     redis-dnea4gmji6uou (apps/Deployment)
     redis-dnea4gmji6uou (core/Service)
   ```

## Step 6.5: Add a connection

Now, let's add a connection between the demo container and the Redis cache. This will allow us to use the Redis Cache from the demo container:

1. Add the following annotation to your deployment:

   ```diff
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: demo
     namespace: default
     annotations:
       radapp.io/enabled: "true"
       radapp.io/application: "lab-yaml"
   +   radapp.io/connection-redis: 'db'
   spec:
     ...
   ```

1. Re-apply the YAML file:

   ```bash
   kubectl apply -f app.yaml
   ```

1. Get your application graph one last time to see the connection:

   ```
   Displaying application: lab-yaml
   
   Name: demo (Applications.Core/containers)
   Connections:
     db (Applications.Datastores/redisCaches) -> demo
   Resources:
     demo (apps/Deployment)
   
   Name: db (Applications.Datastores/redisCaches)
   Connections: (none)
   Resources:
     redis-dnea4gmji6uou (apps/Deployment)
     redis-dnea4gmji6uou (core/Service)
   ```

## Step 6.6: Clean up

When you're done, you can clean up your application's resources by running:

```bash
kubectl delete -f app.yaml
```

## Done

Congratulations! You've successfully used Radius to annotate existing Kubernetes YAML files with Radius metadata. You can now use Radius with existing Kubernetes YAML files.

This concludes the lab. We hope you enjoyed it and learned something new about Radius. If you have any questions, please reach out to us on [Discord](https://aka.ms/radius/discord) or [GitHub](https://github.com/radius-project/radius).
