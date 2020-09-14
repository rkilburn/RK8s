    
# Initial Cluster Setup

## 1. Install Docker

```
#Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable"

apt-get update && apt-get install -y   containerd.io=1.2.13-2   docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)   docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)

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

## 3. Install Kubernetes
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl
```

## 4. Bootstrap Cluster

```
kubeadm config images pull
```

Change the IP Address in the `pod-network-cidr` endpoint to the IP Address of your Load Balancer. 

If you are running a Controller node with less than 2 CPU cores, add `--ignore-preflight-errors=NumCPU` to the end of the following command.

```
kubeadm init --pod-network-cidr=192.168.0.0/16 --control-plane-endpoint=10.0.0.4:6443
```