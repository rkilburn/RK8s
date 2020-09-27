# Deploy an Application
Now you have a fully functioning cluster, lets deploy an app!

## 1. Look at the resource file
```
cat ./web-server.yml
```

We can see from the YAML, we are going to create a `Deployment` called "web-server" in the `Namespace` "default". We want 1 `Replica`. Looking at the `Template`, we have a `Label` "name" set to "web-server", and in each `Pod`, we have one container called "nginx" using the "nginx:1.19.2"

## 2. Deploy the file
Lets actually spin up the Pods in our cluster:
```
kubectl apply -f ./web-server.yml
```

## 3. Check the Deployment
```
kubectl get deployment
```

## 4. Check the Pods
Lets list all the pods to make sure their status is `Running`.
```
kubectl get pods
```
Or, just get the pods with the label name set to web-server
```
kubectl get pods -l name=webserver
```

We can go one step futher and describe a pod to see what image it is running, and any events or errors it experienced. Run the following command, using one of the Pod's name from the previous commands
```
kubectl describe pod <POD NAME>
```

## 5. Scale up the deployment
One pod is great, but this Kubernetes and we should design our apps to be fault tolerant. Lets scale up our deployment to have 3 replicas. 

```
kubectl scale deployment web-server --replicas 3
```

Bare in mind, if you now re-apply the yaml file, the deployment will scale back down to 1, as specified in the YAML. 

By default, Kubernetes will try and spread out the pods evenly over the nodes (though, we can mandate this better as shown in a future guide). As we only have a few Pods in our cluster, the scheduler should have done a fine job at this without any rules. Lets see which nodes our Pods ended up on
```
kubectl get pods -o wide
```

## Challenge 1: Debugging Deployments
Apply the `./web-server-challenge-1.yml` file and work out why the Pods do not start.

## 6. Tear down our web server
You've now completed Deploy an Application. Lets clean up!

```
kubectl delete -f .
```