# Users

For now, we have been using the cluster-admin user using the certificates created by kubeadm. If we were to give this out to our users, they would have full access to every resource in the cluster - not great for security! 

There actually is no such thing as a User in Kubernetes: you are not able to create a resource with kind: User. However, there is a pseudo-user mechanism and thats provided via Roles. From the Kubernetes website:

```
Kubernetes uses client certificates, bearer tokens, an authenticating proxy, or HTTP basic auth to authenticate API requests through authentication plugins
```

Evaluating these options, we already have an authenticating proxy using certificates and Traefik. Therefore, we will use this to work out what user is making requests! This is configured at the API Server level

## 1. Look at Kube-APIServer Config
SSH onto one of your control plane nodes and edit `/etc/kubernetes/manifiests/kube-apiserver.yaml`

```yaml
apiVersion: v1
kind: Pod
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    ...
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
    - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
    - --requestheader-allowed-names=front-proxy-client
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
```

The --request-header flags tell the API server which headers to look into in order to identify a user. The front-proxy-ca.crt determines which client certificates must make the request kubeadm has already created client certs for us that are signed the the CA called front-proxy-client.crt

```bash
openssl x509 -in /etc/kubernetes/pki/front-proxy-client.crt -text | grep Issuer
# Issuer: CN = front-proxy-ca
```

But we need to make sure that anyone else can't make requests to the API Proxy, otherwise any request with a x-remote-user header would be forwarded. To achieve this, we use a NetworkPolicy to say that Traefik, and only Traefik can connect to the API Proxy.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-proxy
spec:
  podSelector:
    matchLabels:
      app: api-proxy
  ingress:
      - from:
          - podSelector:
              matchLabels:
                app.kubernetes.io/name: traefik
  policyTypes:
  - Ingress
```

And finally, just in case someone tries to set headers before the request hits Traefik, lets remove the X-Remote-User and X-Remote-Group from the request before we forward to the Forward Authentication server. Setting the values to "" removes the header in Traefik Headers middlware.

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: remove-user-headers
spec:
  headers:
    customRequestHeaders:
      X-Remote-User: ""
      X-Remote-Group: ""
```

## 2. Deploy the API Proxy DaemonSet
We run the proxy on all control plane nodes as there will always be the front-proxy-client certificate and there will always be at least three replicas. We can also use podTopology in the service to prioritise that network traffic is routed to Pods on the same node. 

```bash
kubectl apply -f /api-access/api-proxy
```

## 3. Configure the user Roles
In the `scripts` folder, there are is a bash script that generates the RoleBindings and ClusterRoleBindings based on the template in the `users` folder. Alice and Bob's have already been created so let's apply them to the cluster

```bash
kubectl apply -f users
```

## 4. Configure kubectl
We now need to configure `kubectl` to use Alice's or Bob's client certificates. Copy one of their certificate and private keys to a control plane node and run the following commands

```bash
# Create the User
kubectl config set-credentials alice --client-certificate=alice.pem --client-key=alice.key --embed-certs=true
# Create a new cluster - this will point at the Ingress and not the API server. You would normally provide the CA Certificate here for validation, however due the generic certificates being used, it will not verify.
kubectl config set-cluster rk8s-traefik --server=https://localhost:32443/api/ --insecure-skip-tls-verify
# Create a context using the user and cluster
kubectl config set-context alice --user=alice --cluster=kubernetes
# Change the current context
kubectl config use-context alice

# Any commands from now will be as the Alice role
kubectl get pods -n alice
# No resources found in alice namespace.

kubectl get pods -n bob
# Error from server (Forbidden): pods is forbidden: User "alice" cannot list resource "pods" in API group "" in the namespace "bob"
```

## 4. Make Alice a Cluster Administrator
Let's give Alice some more permissions and make them a full Cluster Administrator.

```bash
kubectl apply -f ./alice-admin.yml
```

Get a permissions denied error? This is because Alice doesn't have permissions to create ClusterRoleBindings (which is good - we can't have users giving themselves more permissions!). Swap back to the cluster-admin credentials using the following command, and run the `kubectl apply` command again:

```bash
kubectl config use-context kubernetes-admin@kubernetes
kubectl apply -f ./alice-admin.yml
```

Swap back to Alice, and see if they can list pods in the `kube-system` namespace

```bash
kubectl config use-context alice
kubectl get pods -n kube-system
```

This is a better way of giving Cluster Administrators full access to the cluster, since it is much more difficult to cycle the cluster-admin credentials.

