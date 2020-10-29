# Networking

We already have core cluster networking enabled through Calico, but what about getting application traffic in and out of the cluster. We have a number of options:

1.  Node Ports
Node Ports expose a port on every host in the cluster (typically in the 32000-32768 range). This then typically means your user or downstream application points to one host in the cluster. 

2. Host Ports
Host Ports open a port on a specific host depending on where your Pod is running, which means then you then need to lock your Pod to a specific host to make sure it has a stable IP. 

3. Ingress Controller
If we have an application that uses HTTP traffic, we can use an Ingress Controller. An Ingress Controller can route traffic based on hostnames, paths and ports, as well as handling all of the SSL and authentication. For this, we are going to use Traefik 2 for our cluster.

