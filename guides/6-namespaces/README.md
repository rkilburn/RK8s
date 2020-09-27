# Creating Namespaces

Namespaces are a way of groups resources in Kubernetes. It is good practise to have one namespace per application. Lets create some namespaces and deploy our application to it. 

## 1. Create a Namespace
Let's create a namespace for our application. 
```
kubectl create namespace web-server
```

## 2. View the Namespace
Run the following command:
```
kubectl get all -n web-server
# No resources found in web-server namespace.
```

We are told there is nothing in the namespace. But if we run the following, what do we see: 
```
kubectl get serviceaccount -n web-server
# NAME      SECRETS   AGE
# default   1         4m9s
```
So Kubernetes just lied to us?! 😢 Not quite, `kubectl get all` only shows Pods, Deployments and Services which are the three most common things you'll probably want to check. There are many resource types. See them all using the following command:
```
kubectl api-resources
```
You will see columns with the follwong headers:
```
NAME SHORTNAMES APIGROUP NAMESPACED KIND
```
Short names are shorthand that can be used in kubectl commands. For example, you can use `kubectl get po` to get Pods or `kubectl get pvc` to get all PersistentVolumeClaims (we'll use these later). You can also perform commands like `kubectl get deployments,svc,cm,secrets` to list multiple resources at once.


## 2. Deploy an app to a namespace
Lets deploy the same web server we deployed earlier:
```
kubectl apply -f ./web-server.yml
```
Lets see the pods:
```
kubectl get pods -n web-server
```
Hang on, where are our pods?! We didn't speicify a namespace in the resource YAML or on the command line. Therefore it's deployed to what namespace is defined in our kubectl configuration. Lets check what namespace we are using.
```
kubectl config get-contexts
# CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
# *         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
```
There is no namespace set, so it using the `default` namespace. Lets confirm this and find our deployment:
```
kubectl get deployments --all-namespaces
```
We can see our web-server Deployment is in default. Lets delete this and re-deploy to our web-server namespace. 
```
kubectl delete -f web-server.yml -n default
kubectl apply -f web-server.yml -n web-server
kubectl get pods -n web-server
```
This works, but specifying a namespace each time isn't best practise. Update the web-server to specify a namespace. Change the YAML to begin with the following and apply it without the namespace flag on kubectl:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: web-server
spec:
...
```
```
kubectl apply -f web-server
# deployment.apps/web-server unchanged
```
The deployment was not changed because we have already applied the web-server Deployment to the namespace in the previous step.

## Namespace Policies
We now have our web-server Namespace and our web-server Deployment in that namespace. This is great, and our web-server is running quite happily, but there is a problem. We are designing our cluster to be multi-tennancy and secure. Here is a list of problems our current setup has

1. Any Pod in any Namespace can currently access our web-server
2. We have not specified any Resource Requests so we don't know how much CPU or Memory to reserve for the Pods. Without Requests, we could overprovision our cluster.
3. We have not specified any Resource Limits, so our Pods can currently use all the CPU and Memory in the cluster without limit
4. The Pods could schedule themselves as any PriorityClass. This means we could schedule them as a higher PriorityClass then our core networking and storage pods, therefore the scheduler would stop the core services to run the web-server Pods
5. Our Pods can request as much storage as they want in PersistentVolumeClaims
6. We can create Services with NodePorts - this is bad practise and means we need to expose these ports through our firewalls.

We can solve all of these issues with the following Kubernetes Resources

| Resource | Purpose |
|-----------|-----------|
| Resource Quotas | Limit the total amount Kubernetes Resources in a Namespace such as Network Services, Storage Requests, Priority Classes |
| LimitRange | Set the default Pod and Container Resource Requests and Limits |
| NetworkPolicy | Control the Ingress and Egress networking from Pods |


TBC...