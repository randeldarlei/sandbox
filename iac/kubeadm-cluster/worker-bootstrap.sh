#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/bootstrap.log) 2>&1

echo "===== BOOTSTRAP WORKER ====="

# Espera rede
echo "Waiting for internet..."

until ping -c1 google.com >/dev/null 2>&1
do
  sleep 5
done

# Retry apt
until apt-get update -y
do
  echo "APT not ready..."
  sleep 10
done

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Dependências
apt-get install -y \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  ca-certificates \
  awscli

# Kubernetes repo
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
 | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
> /etc/apt/sources.list.d/kubernetes.list

apt-get update -y

apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

# Containerd
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' \
/etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

# Espera runtime
until systemctl is-active --quiet containerd
do
  sleep 2
done

echo "Container runtime ready"

# Espera join command no SSM
echo "Waiting join command..."

for i in {1..60}
do

JOIN_CMD=$(aws ssm get-parameter \
  --name "/k8s/join-command" \
  --query "Parameter.Value" \
  --output text \
  --region us-east-2 2>/dev/null)

if [[ ! -z "$JOIN_CMD" ]]
then
  break
fi

sleep 10
done

if [[ -z "$JOIN_CMD" ]]
then
  echo "Join command not found"
  exit 1
fi

echo "Executing join..."

$JOIN_CMD --node-name $(hostname -s)

echo "Worker joined cluster"

echo "===== BOOTSTRAP COMPLETE ====="