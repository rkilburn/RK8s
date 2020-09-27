# Creating Namespaces

Namespaces are a way of groups resources in Kubernetes. It is good practise to have one namespace per application. Lets create some namespaces and deploy our application to it. 

## 1. Create a Namespace
Let's create a namespace for our application. 
```bash
kubectl create namespace web-server
```

## 2. View the Namespace
Run the following command:
```bash
kubectl get all -n web-server
# No resources found in web-server namespace.
```

We are told there is nothing in the namespace. But if we run the following, what do we see: 
```bash
kubectl get serviceaccount -n web-server
# NAME      SECRETS   AGE
# default   1         4m9s
```
So Kubernetes just lied to us?! 😢 Not quite, `kubectl get all` only shows Pods, Deployments and Services which are the three most common things you'll probably want to check. There are many resource types. See them all using the following command:
```bash
kubectl api-resources
```
You will see columns with the follwong headers:
```
NAME SHORTNAMES APIGROUP NAMESPACED KIND
```
Short names are shorthand that can be used in kubectl commands. For example, you can use `kubectl get po` to get Pods or `kubectl get pvc` to get all PersistentVolumeClaims (we'll use these later). You can also perform commands like `kubectl get deployments,svc,cm,secrets` to list multiple resources at once.


## 2. Deploy an app to a namespace
Lets deploy the same web server we deployed earlier:
```bash
kubectl apply -f ./web-server.yml
```
Lets see the pods:
```bash
kubectl get pods -n web-server
```
Hang on, where are our pods?! We didn't speicify a namespace in the resource YAML or on the command line. Therefore it's deployed to what namespace is defined in our kubectl configuration. Lets check what namespace we are using.
```bash
kubectl config get-contexts
# CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
# *         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
```
There is no namespace set, so it using the `default` namespace. Lets confirm this and find our deployment:
```bash
kubectl get deployments --all-namespaces
```
We can see our web-server Deployment is in default. Lets delete this and re-deploy to our web-server namespace. 
```bash
kubectl delete -f web-server.yml -n default
kubectl apply -f web-server.yml -n web-server
kubectl get pods -n web-server
```
This works, but specifying a namespace each time isn't best practise. Update the web-server to specify a namespace. Change the YAML to begin with the following and apply it without the namespace flag on kubectl:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: web-server
spec:
...
```
```bash
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


## 4. Securing the Network
We will start by securing the cluster networking using the following two Policies. The first is a default deny all ingress traffic:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ryan
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```
Note: Whilst not clear, this still allow traffic between Pods within the same naespace.

Next up, we need to allow traffic from System namespaces, such as Operators and Traefik: 

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-allow-system
  namespace: bob
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          type: system
  policyTypes:
  - Ingress
```

Before we apply these policies, let's see what happens at the moment. 

First, create a service in the `web-server` namespace for us to curl

```
kubectl apply -f ./web-server-service.yml
```

Create a pod in the `default` Namespace and curl the web server in the `web-server` Namespace:

```bash
kubectl run -it --rm --restart=Never alpine -n default --image=alpine sh

# In the container, run the following:
apk add curl

# -m specifies a timeout for the request
curl -m 3 web-server.web-server.svc.cluster.local

exit
```

We were able to curl the service successfully. Now, lets apply the policy to the `web-server` Namespace and try the curl again

```bash
kubectl apply -f ./web-server-network-policies.yml

kubectl run -it --rm --restart=Never alpine -n default --image=alpine sh

# In the container, run the following:
apk add curl

curl -m 3 web-server.web-server.svc.cluster.local
exit
```

You will see that the request now times out. If we try the following from a 'system' namespace, the request will succeed:

```bash
kubectl apply -f ./system-namespace.yml

kubectl run -it --rm --restart=Never alpine -n test-system --image=alpine sh

# In the container, run the following:
apk add curl

curl -m 3 web-server.web-server.svc.cluster.local
exit
```

And the request succeeds from this namespace!

## 5. Quotas
Let's apply some ResourceQuotas to solve some more concerns we have.

Using NodePorts typically means that someone is directing traffic directly at a single host (even though the NodePort is listening on all hosts). A quota for this looks like: 

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: network
spec:
  hard:
    services.nodeports: "0"
```

We also want to prevent users scheduling Pods at very high PriorityClasses. We can prevent this by using a Quota on those classes:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: priority-class
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
    - operator : In
      scopeName: PriorityClass
      values: 
        - system-node-critical
        - system-cluster-critical
        - core-cluster-networking
        - core-cluster-storage
        - core-cluster-operators
```

And finally, lets limit the amount of storage each Namespace can request:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage
spec:
  hard:
    ceph-block-ssd.storageclass.storage.k8s.io/requests.storage: 10Gi
    ceph-block-hdd.storageclass.storage.k8s.io/requests.storage: 100Gi
```

Apply these to the `web-server` Namespace using the following YAML and check that it is applied:
```bash
kubectl apply -f ./web-server-quotas.yml

kubectl get quota -n web-server
#NAME             AGE     REQUEST                                                                                                                                     LIMIT
#network          3m32s   services.nodeports: 0/0                                                                                                                     
#priority-class   3m32s   pods: 0/0                                                                                                                                   
#storage          3m32s   ceph-block-hdd.storageclass.storage.k8s.io/requests.storage: 0/100Gi, ceph-block-ssd.storageclass.storage.k8s.io/requests.storage: 0/10Gi
```

See what happens when you try and make a Service with a NodePort:
```bash
kubectl apply -f ./web-server-service-nodeport.yml
# Error from server (Forbidden): error when creating "./web-server-service-nodeport.yml": services "web-server-nodeport" is forbidden: exceeded quota: network, requested: services.nodeports=1, used: services.nodeports=0, limited: services.nodeports=0
```

## 6. Default Resource Requests & Limits

Last up, we need to enforce that all containers have Resource Requests and Limits. We can use a LimitRange to enforce this:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limits
spec:
  limits:
  - default:
      memory: 512Mi
      cpu: "1"
      nvidia.com/gpu: "0"
    defaultRequest:
      memory: 256Mi
      cpu: "0.5"
      nvidia.com/gpu: "0"
    type: Container
```

Apply this to the `web-server` Namespace and ensure its enforced:
```bash
kubectl apply -f ./web-server-limitrange.yml
kubectl describe limitrange limits -n web-server

#Name:       limits
#Namespace:  web-server
#Type        Resource        Min  Max  Default Request  Default Limit  Max Limit/Request Ratio
#----        --------        ---  ---  ---------------  -------------  -----------------------
#Container   cpu             -    -    500m             1              -
#Container   memory          -    -    256Mi            512Mi          -
#Container   nvidia.com/gpu  -    -    0                0              -
```

Let's spin up another web-server that we haven't set Resource Requests and Limits on and describe one if its Pods:

```bash
kubectl apply -f ./web-server-limitless.yml

kubectl get pods -l name=web-server-limitless -n web-server

kubectl describe pod <POD NAME> -n web-server
```

About half way down the output, you'll see the following: 
```
Limits:
  cpu:             1
  memory:          512Mi
  nvidia.com/gpu:  0
Requests:
  cpu:             500m
  memory:          256Mi
  nvidia.com/gpu:  0
```

Compare this to our original web-server:

```bash
kubectl get pods -l name=web-server -n web-server

kubectl describe <POD NAME> -n web-server
```
You will see it has no Resource Requests or Limits. We can fix this. Because everything in our cluster should be redundant and fault tolerant, we should have confidence in being about to restart anything (if not, have a strong word with your users!). Restart the old web-server deployment and check to see that the limits have applied:

```bash
kubectl rollout restart deployment web-server -n web-server
# deployment.apps/web-server restarted
kubectl get pods -l name=web-server -n web-server
kubectl describe pod <POD NAME> -n web-server
```

And the limits have now been applied!

## 7. Clean up Resources
Well done for making it through that! Time to clean up:

```bash
kubectl delete -f .
```

## Scripts
In the `scripts` folder, there is a bash script to template Namespaces based on the contents of `namespaces/namespaces.txt`