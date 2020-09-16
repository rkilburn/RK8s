# RK8s

A template for a secure, multitenant Kubernetes Cluster

### Work In Progress

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