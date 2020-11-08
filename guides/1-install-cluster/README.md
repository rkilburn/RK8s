    
# Initial Cluster Setup

## 0. Provision Infrastructure

Create the following VMs:
- 3x Controller Nodes with 2 Cores, 4GB RAM and 32GB OS SSD
- 3x Worker Nodes with 2 Cores, 4GB RAM, 32GB OS SSD and 16GB Data SSD - do not format/mount this disk

You also will need a Load Balancer that balances traffic across Port 6443 on your Controller Nodes. You can use a cloud provider, another dedicated VM or a VIP with HAProxy and KeepaliveD

If you are using AWS, or a cloud provider that allows User Data, use the user-data.sh script and skip to step 4. 


## 1. Install Docker

```
#Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable"

apt-get update && apt-get install -y containerd.io docker-ce docker-ce-cli

# Set up the Docker daemon
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF


# Restart Docker
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

```
## 2. Configure Host Networking
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

## 3. Disable Swap
Check to see if swap is enabled
```
swapon --show
```
If it, disable it using the following (replace /swap.img with the path from the show output). Edit the fstab file to remove the line containing swap. This prevents it being mounted on reboot.
```
swapoff -v /swap.img
rm /swapfile.img
vi /etc/fstab
```

## 3. Install Kubernetes
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl
```

## 4. Setup Control Plane

```
kubeadm config images pull
```

Change the IP Address in the `pod-network-cidr` endpoint to the IP Address of your Load Balancer. 

If you are running a Controller node with less than 2 CPU cores, add `--ignore-preflight-errors=NumCPU` to the end of the following command.

```
kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-bind-port=6443 \
  --control-plane-endpoint=k8s.rkilburn.com:6443 \
  --image-repository k8s.gcr.io \
  --upload-certs
```

Add additional control plane nodes using the command given from the init. 

## 5. Add Worker Nodes

Run the worker node join command from the output from the control plane init command. 

## 6. Copy the kubectl config your user on the control plane node

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 6.1. Copy the kubectl config to your local machine (optional)
scp or copy the ```/etc/kubernetes/admin.conf``` to ~/.kube/config. Make sure you backup your existing configuration!

## 7. Verify Cluster Nodes
Run the following command to check all nodes are in the cluster
```
kubectl get nodes
```

## 8. Add the Cluster Network Interface (CNI)

```
kubectl apply -f networking/calico.yaml
```

## 9. Check Nodes are Ready
Run the following command to check all nodes are Ready in the cluster
```
kubectl get nodes
```

## 10. Label your nodes
Labelling your nodes allows you to spread Pods out intelligently and target Pods to types of nodes. Edit the `./label.sh` file with your node names as per the previous commands and run the following command. For now, don't worry too much about the storage label, that will become clear later on!
```
./label.sh
```

## Create Awesome Things!
You now have your own Kubernetes cluster. Go forth and kubectl!