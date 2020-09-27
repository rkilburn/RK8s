# Scheduling
Now that we've proven our cluster is working, it's time to start thinking about multi-tenancy. Let's think about what our cluster is going to be running?

- Critical Node Pods
- Critical Cluster Pods
- Core Networking Pods (Ingress Controllers, Load Balancer Provisioners, API Authentication)
- Core Storage Pods (Storage Providers such as CEPH)
- Core Operators for running 'managed' services (Rook CEPH, Elasticsearch, Kafka, etc)
- Standard Applications
- Legacy Applications
- Data Science Workers
- Unused Capacity Workers

So, we want to be pretty open in how much CPU and Memory our users can use, but we need to prioritise certain Pods other other to prevent core cluster service Pods from being killed (or Evicted as a Pod status). 

In Kubernetes, we can achieve this with PriorityClasses. We assign each Pod a PriorityClass and the Scheduler will prioritise Pods with a PriorityClass with a higher value. If Pods are requested but there is not enough capacity, the lowest PriorityClass Pods will be Evicted from the cluster.

If you do not have your web-server deployment from the previous guide, recreate it with the following command:
```
kubectl apply -f web-server.yml
```

## 1. See current PriorityClasses
Let's see what classes we already have:
```
kubectl get priorityclass
# NAME                      VALUE        GLOBAL-DEFAULT   AGE
# system-cluster-critical   2000000000   false            80m
# system-node-critical      2000001000   false            80m
```

As shown in the previous output, Kubernetes has two PriorityClasses by default. Lets see how they are being used:

```
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,PRIORITY:.spec.priorityClassName

# NAME                                      NAMESPACE     PRIORITY
# calico-kube-controllers-c9784d67d-9mm5g   kube-system   system-cluster-critical
# calico-node-264dp                         kube-system   system-node-critical
# calico-node-9rcg4                         kube-system   system-node-critical
# calico-node-wb4qt                         kube-system   system-node-critical
# calico-node-p62j4                         kube-system   system-node-critical
# calico-typha-5f846c74-z8z4q               kube-system   system-cluster-critical
# coredns-f9fd979d6-f8bsn                   kube-system   system-cluster-critical
# coredns-f9fd979d6-xrw5f                   kube-system   system-cluster-critical
# etcd-rk8s-c1                              kube-system   system-node-critical
# etcd-rk8s-c2                              kube-system   system-node-critical
# etcd-rk8s-c3                              kube-system   system-node-critical
# kube-apiserver-rk8s-c1                    kube-system   system-node-critical
# kube-controller-manager-rk8s-c1           kube-system   system-node-critical
# kube-proxy-5rfx2                          kube-system   system-node-critical
# kube-proxy-6lqct                          kube-system   system-node-critical
# kube-proxy-7xw8b                          kube-system   system-node-critical
# kube-proxy-9pzk5                          kube-system   system-node-critical
# web-server66764df4cc-bfgdx                web-server    default
# kube-scheduler-rk8s-c1                    kube-system   system-node-critical
```

We can see that the following have `system-node-critical`:
- calico-node - a DaemonSet running the CNI on each node
- kube-proxy - a DaemonSet that controls networking on each node
- etcd - the core cluster state database engine
- kube-apiserver - the Kubernetes API server that all requests to etcd must use
- kube-scheduler - the Scheduler that assigns resources to nodes
- kube-controller-manager - the Controller Manager that ensures the cluster is in the desired state

These services must be running for the cluster to start up. Next up we have `system-cluster-critical`: 
- calico-kube-controllers - a controller for Calico
- calico-typha - a caching layer for Calico
- coredns - DNS servers for the entire cluster

Last up, we have our web-server pods that do not have a priority class.

## 2. Create PriorityClasses
Apply the resource file with our desired PriorityClasses and check their values:
```
kubectl apply -f <root>/scheduling
kubectl get priorityclass
```

## 3. Watching Scheduling In Action
In this example, we are going to fill our cluster with low priority Pods, and then begin scheduling higher priority Pods and watch the scheduler do its magic.

Apply the low priority web server resource file:
```
kubectl apply -f ./web-server-low-priority.yml
```

Scale up the pods to fill up your cluster. Each Pod is requesting 0.5CPU Cores and 512Mi - nginx will not use all of this so it will kill your cluster - even if it did, the resource limits and scheduler would prevent this. Keeping scaling the deployment so that you have no Pending Pods. 

```
kubectl scale -f ./web-server-low-priority.yml --replicas 25
kubectl get pods -n web-server
```

Once you have filled your cluster with low priority Pods, lets create the high priority deployment and see what happens. To watch what happens live, open a second terminal and run the following. 

```
kubectl get pods --watch
```

Lets create the high Priority Deployment
```
kubectl apply -f ./web-server-high-priority.yml 
```

You will see a lot of output, but what is happening is the following:

1. The High Priority Pods are scheduled
2. X of the Low Priority Pods are Terminated to allow the High Priority Pods to be created
3. X Low Priority Pods are then scheduled but remain in Pending state until there are enough resources in the cluster to create them.

If you now delete the High Priority Deployment, you will see the X Low Priority Pods be created:

```
kubectl delete -f ./web-server-high-priority.yml
```

In a later guide, we will see how we restrict which PriorityClasses can be scheduled in a Namespace

## 4. Challenge 1
The following YAML creates a deployment called `scheduling-challenge-1`. What PriorityClass does it have, any why? How and why is this different to the PriorityClass our web-server had at the start of this guide?

```
kubectl apply -f ./scheduling-challenge-1.yml
```


## 5. Challenge 2
The following YAML creates a deployment called `scheduling-challenge-2`, but it's Pods are missing when running `kubectl get pods -n web-server`. Why is this, and where can you see the exact error message?
```
kubectl apply -f ./scheduling-challenge-2.yml
```

Hint: Think about the hierarchy of Deployment to Pod resources and what is responsibly for controlling Pods.

## 5. Clean up resources
```
kubectl delete -f .
```