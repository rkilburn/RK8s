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

The --request-header flags tell the API server which headers to look into in order to identify a user. The front-proxy-ca.crt determines who must make the request - remember, users can set headers so we want to ensure the request is coming from Traefik and only Traefik. kubeadm has already created client certs for us that are signed the the CA called front-proxy-client.crt

```bash
openssl x509 -in /etc/kubernetes/pki/front-proxy-client.crt -text | grep Issuer
# Issuer: CN = front-proxy-ca
```


