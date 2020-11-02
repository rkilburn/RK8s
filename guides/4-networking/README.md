# Networking

We already have core cluster networking enabled through Calico, but what about getting application traffic in and out of the cluster. We have a number of options:

1.  Node Ports
Node Ports expose a port on every host in the cluster (typically in the 32000-32768 range). This then typically means your user or downstream application points to one host in the cluster. 

2. Load Balancers
Load Balancers can be used to automatically a network or application load balancer on a cloud provider to route traffic with a resiliant and stable IP address. On a bare metal cluster, a system such as MetalLB can be used which uses floating IP addresses. 

3. Ingress Controller
If we have an application that uses HTTP traffic, we can use an Ingress Controller. An Ingress Controller can route traffic based on hostnames, paths and ports, as well as handling all of the SSL and authentication. 

For the majority of services we run on cluster, they will be HTTP traffic and therefore we will focus on this type of networking in this guide. We are therefore going to use Traefik 2 for our cluster.

Traefik handles a number of roles for us:
1. SSL Offloading - By default, Treafik will handle all certificates and TLS termination and therefore taking the SSL connection load and general configuration away from our application pods
2. Host and Path based routing - We can specify fine grained routing, enabling microservice deployment, such as the following:
   - Host Portal.com - Path /api/v1/users -> Service user-service
   - Path Portal.com - Path /api/v1/groups -> Service group-service
   - Path Metrics.com - Path /api/v1/metrics -> Service metrics-service
   - etc
3. Authentication - we can do the authentication at the Ingress layer before the requests even hit our Pods. A more detailed example of this will be shown in the Users guide.  
4. Middlewares - these can be added to an Ingress to manipulate the headers, throttle requests, provide authentication and many other functions.

## 1. Install the Traefik CRDs
Traefik uses Custom Resource Definitions (CRDs) to add additional types of Resources within our Kubernetes Cluster. These specify the fields and types that a resource can have. First up, deploy the the CRDs into your cluster:
```bash
kubectl apply -f networking/traefik-crds.yml
```

## 2. Create Certificate Secrets for Traefik
In order to make our cluster secure, we are going to create a secure Entrypoint for Traefik (an Entrypoint is the term that Traefik uses for a Port). By default, an Entrypoint that has TLS enabled will generate its own self-signed certificate and therefore we should specify our own certificates in production. For this set of guides, a Certificate Authority, a web certificate and two client ceritificates have been generated for you. These provided certificates should never be used in production or clusters exposed to the internet.

There is a standard way of formatting TLS certificate Secrets in Kubernetes. These can be generated using the following command:

```bash
kubectl create secret tls my-web-cert --cert=path/to/tls.cert --key=path/to/tls.key 
```

This creates a secret that looks like: 

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-web-cert
data:
  tls.key: S0tLS1CRUdJTiBQUklWQVR...
  tls.crt: LS0tLS1CRUdJTiBDRVJUSU...
```

This has already been done for you, and an additional CA certifcate been added. Apply this now using the following command. We will use these certificates in our Traefik Pods by mounting the Secret as a Volume.

```bash
kubectl apply -f networking/traefik-certs.yml
```

One thing to note, this also creates a ConfigMap that contains a Traefik configuration file which instructs Traefik to look at the certificates. You'll see how this is mounted in the next step. 

## 3. Configuring Traefik
It's now time to create our Traefik instances. Traefik requires a few things in order to work (which are all preconfigured for us by Traefik)

1. A ClusterRole - a set of permissions to the Kubernetes API. In this case, a set of permissions that allow querying of the API for Ingresses and the Traefik Custom Resources.
2. A ServiceAccount - A service account that has been assigned a set of permissions and can be attached to a Pod to give that Pods access to the Kubernetes API
3. A ClusterRoleBinding - an assignment of the ClusterRole to the ServiceAccount
4. A DaemonSet - A set of Pods that run on every host that matches the Affinity
5. A Service - A Kubernetes Service to allow networking to the Pods

Looking closer at the DaemonSet, there's a few things to note. Earlier we said we would mount the certificates and Traefik configuration from the Secrets and ConfigMaps. In Kubernetes, we can mount these as Volumes, with the keys in YAML files becoming files on the Pods filesystem. By not specifying any subPaths in the volumeMounts, each top level key (so tls.key, tls.crt, traefik.toml, etc in the ConfigMap and Secrets), become a file:

```yaml 
...
  volumeMounts:
    - name: data
      mountPath: /data
    - name: tmp
      mountPath: /tmp
    - name: certs
      mountPath: /certs
    - name: config
      mountPath: /config
volumes:
  - name: data
    emptyDir: {}
  - name: tmp
    emptyDir: {}
  - name: certs
    secret:
      secretName: traefik-certs
  - name: config
    configMap:
      name: traefik-certs-config
```
Therefore if we look in the /certs and /config in the Pods, we will see the following files:

```bash
/certs/tls.key
/certs/tls.crt
/certs/ca.crt
/config/certs.toml
```

A DaemonSet, by definiton, runs one Pod on every host in the cluster providing the Taints and Tolerations allow. For Traefik, and other core services, personally I prefer these to be on the controller nodes. To mandate this for Traefik, the following is added to the DaemonSet definiton:
```yaml
tolerations:
  - key: node-role.kubernetes.io/master
    operator: Equal
    effect: NoSchedule
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role.kubernetes.io/master
              operator: Exists
```

We also specify some configuration for Traefik via command line arguments. Some key points to note
- Providers
    -  the Kubernetes Ingress and CRD provider to configure Traefik from within Kubernetes
    -  the File provider to configure Traefik from the TOML file in the config map
    -  --entrypoints.websecure.http.tls
       -  This ensures SSL is turned on for this Entrypoint
    -  --log.level=DEBUG
       -  Useful for debugging, not recommended to be set to DEBUG in production (set to ERROR)

```yaml
args:
    - "--accesslog=true"
    - "--log.level=DEBUG"
    - "--entryPoints.traefik.address=:9000/tcp"
    - "--entryPoints.web.address=:8000/tcp"
    - "--entryPoints.websecure.address=:8443/tcp"
    - "--entrypoints.websecure.http.tls"
    - "--api.dashboard=true"
    # - "--global.checknewversion"
    # - "--global.sendanonymoususage"
    - "--ping=true"
    - "--providers.kubernetescrd"
    - "--providers.kubernetesingress"
    - "--providers.file.directory=/config/"
    # - "--tracing.elastic=true"
    # - "--tracing.elastic.serverurl=http://apm-server.default.svc.cluster.local:8200"
```

## 4. Deploy Traefik
Now we have an overview of some of the configuration, let's deploy it!

```bash
kubectl apply -f networking/traefik.yml
```

## 5. Seeing it in action
With Traefik now deployed, lets deploy an application and Ingress to see it work. WhoAmI simply returns the request details to us. Lets look at the Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-ingress
  namespace: kube-system
spec:
  rules:
  - http:
      # hosts: example.com
      paths:
      - path: /whoami
        pathType: Prefix
        backend:
          service:
            name: whoami-service
            port:
              name: http

```

There is one rule defined that states for the Path `/whoami` on all hosts, route to the `whoami-server` on the named port `http`. This port could also be defined as a number. Because we haven't specificed a host, it will listen on all hostnames.

```bash
kubectl apply -f networking/whoami.yml
```

To access the ingress, log on to one of your controller nodes, and run the following (you will need the -k to ignore the untrusted CA certificate):

```bash
curl -k https://localhost:32443/whoami
```

You see something like the following:
```
Hostname: whoami-deployment-7588bf8998-fb6sf
IP: 127.0.0.1
IP: 192.168.59.74
RemoteAddr: 192.168.9.149:49732
GET /whoami HTTP/1.1
Host: A.B.X.Y:32443
User-Agent: curl/7.64.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: A.B.X.Y
X-Forwarded-Host: A.B.X.Y:32443
X-Forwarded-Port: 32443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-cwf7f
X-Real-Ip: A.B.X.Y
```

## 5. Authentication
Remember we said one of the use cases was Authentication, let's see how this works. 

Traefik supports what is called "Forward Authentication". This means we can forward the request to an authentication service and let it make the decision as to whether it can be allowed to the backend service. If the authentication returns a reponse with status code 200, then Traefik will forward the request to the backend server. If it return's any other code, Traefik will deny the request and return the authentications server reply. 

Another feature of forward authentication in Traefik is the `trustForwardHeaders` option. This follows the same pattern of before, but if the request is allowed, Traefik copies some of the headers from the authentication server response to the backend server request. This is what we will see in this step. 

You may have noticed in the certs directory there are two client certificates (alice and bob), and in the Traefik Configuration, the following is specified: 

```toml
[tls.options]
  [tls.options.default]
    [tls.options.default.clientAuth]
      # in PEM format. each file can contain multiple CAs.
      caFiles = ["/certs/ca.crt"]
      clientAuthType = "VerifyClientCertIfGiven"
```

Note the `VerifyClientCertIfGiven`. This means Traefik will request a client certificate and verify it, but will also allow requests through that don't have a certificate. 

A Forward Authentication server has been written for us that if we provide a client certificate, it will return the Common Name (CN) in a header. This header than be passed to our backend service. This requires two Traefik Middlewares to be configured. Because Traefik is handling the TLS termination, the first takes the client certificate and adds into a header of the request. The next then forwards the request the Forward Authentication service

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: pki
spec:
  passTLSClientCert:
    pem: true
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: fwd-auth-pki
  namespace: kube-system
spec:
  forwardAuth:
    address: https://fwd-auth-pki.kube-system.svc.cluster.local:8443/v1/certificate/cn
    authResponseHeaders:
      - X-Remote-User
    tls:
      insecureSkipVerify: true
```
We can see here the authentication server address has been specified, and we will copy the X-Remote-User header from the authentication server response to the backend server request. 

Note: In production, tls should configured fully as per the Traefik documentation for this type of service.




Let's tie all this together. First, deploy the Forward Authentication server and middlewares:
```bash
kubectl apply -f networking/traefik-fwd-auth.yml
```

Next, deploy a version of the WhoAmI ingress that has the Middleware specified:
```bash
kubectl apply -f networking/whoami.yml
```

Copy the client certificates to one of your control plane nodes, run the following command and observe the results:

```bash
curl -k https://localhost:32443/whoami
# Returns a similar response to the previous run

curl -k --key certs/
```

```bash
Hostname: whoami-deployment-7588bf8998-fb6sf
.
X-Forwarded-Port: 32443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-cwf7f
X-Forwarded-Tls-Client-Cert: MIIDMzCCAhsCFCXsR99Er....
X-Real-Ip: A.B.X.Y
X-Remote-User: alice
```

You can see on the last line, the X-Remote-User has been set to alice. If we inspect the certificate, alice is indeed the CN
``` bash
openssl x509 -in certs/alice.pem -text | grep "Subject:"```
# Subject: C=AU, ST=Some-State, O=Internet Widgits Pty Ltd, CN=alice
```

We can then use this header in our downstream application to identify our users. 

## 6. Pat yourself on the back
If you've got this far, well done! There are a lot of moving parts, and many things can go wrong. There are a few challenges with things that can go wrong but this is possibly the most complex part of RK8s!

## Challenge 1