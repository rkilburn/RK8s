# RK8s

A template for a secure, multitenant Kubernetes Cluster

## Features
- Pod Restrictions (Pod Security Policies)
- Pod Scheduling Tiers (Priority Classes)
- Namespace Network Isolation (Network Policies)
- Default Pod Resource Requirements and Limits (Limit Ranges)
- Network, Storage and Scheduling Quotes (Resource Quotas)
- Cluster Admins and User Permissions (Users & Role Bindings)
- Calico (CNI)
- Traefik (Ingress Controller)
- CEPH (Storage Provider)
- NVidia GPU Support (Accelerator)

### Future 
- Traefik Foward Auth
- Application of PSPs
- Metrics & APM Monitoring of Traefik


## User and Namespace Generation
1. Add additional users or namespaces to the txt files in the respective directories
2. Run `scripts/generate-users.sh` or `scripts/generate-namespaces.sh` from the root of this git repo
3. Commit the changes and let Flux roll them out


## Namespace Types

### System Namespaces
This have the label `type: system` and can communicate with all pods via the `default-allow-system` NetworkPolicy

1. kube-system - core networking, scheduling and authentication
2. kube-operators - cluster-wide application operators that are centrally managed
3. rook-ceph - cluster-wide storage operator

### User & Application Namespaces
User and Application namespaces do not allow traffic from other namespaces or from outside the cluster (including via LoadBalancers) by default.