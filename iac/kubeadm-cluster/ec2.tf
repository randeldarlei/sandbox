data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_iam_instance_profile" "k8s_profile" {
  name = "k8s-instance-profile"
  role = aws_iam_role.ec2_k8s_admin_role.name
}


resource "aws_instance" "control_plane" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.k8s_profile.name
  subnet_id = aws_subnet.public_cluster_subnet_1.id
  key_name = aws_key_pair.k8s_workers.key_name

user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y

# Desabilita swap
sed -i '/ swap / s/^/#/' /etc/fstab
swapoff -a

# Módulos de kernel
mkdir -p /etc/modules-load.d
cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Sysctl
mkdir -p /etc/sysctl.d
cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# Dependências
apt-get install -y apt-transport-https curl awscli gnupg lsb-release ca-certificates

# Kubernetes repo
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=1.29.* kubeadm=1.29.* kubectl=1.29.*
apt-mark hold kubelet kubeadm kubectl

# Containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd

# Descobre IP privado
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

CONTROL_PLANE_IP=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# Init do cluster
kubeadm init \
  --pod-network-cidr=10.10.0.0/16 \
  --apiserver-advertise-address=$${CONTROL_PLANE_IP}

# kubeconfig
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

export KUBECONFIG=/etc/kubernetes/admin.conf

# Espera API
echo "Aguardando API Server..."
for i in {1..60}; do
  if kubectl get --raw='/healthz' >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

# CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml

# Publica join no SSM
JOIN_CMD=$(kubeadm token create --print-join-command)

aws ssm put-parameter \
  --name "/k8s/join-command" \
  --type "String" \
  --value "$JOIN_CMD" \
  --overwrite \
  --region us-east-2
EOF

  tags = {
    Name = "K8s-Control-Plane"
  }
  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
}

resource "aws_instance" "worker_1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.k8s_profile.name
  subnet_id     = aws_subnet.private_cluster_subnet_1.id
  key_name = aws_key_pair.k8s_workers.key_name

user_data = <<-EOF
#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "===== INICIANDO USER DATA WORKER ====="

# IPv6 + APT

echo "Desabilitando IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

cat <<EOT > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOT

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# BASE

apt-get update -y

sed -i '/ swap / s/^/#/' /etc/fstab
swapoff -a

# KERNEL

cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# DEPENDÊNCIAS

apt-get install -y \
  apt-transport-https \
  curl \
  gnupg \
  lsb-release \
  ca-certificates \
  unzip

# AWS CLI

apt-get remove -y awscli || true

curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install

# KUBERNETES

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
 | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
 > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=1.29.* kubeadm=1.29.* kubectl=1.29.*
apt-mark hold kubelet kubeadm kubectl

# CONTAINERD

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
 | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
 > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

# JOIN AUTOMÁTICO

echo "Aguardando join command no SSM..."

for i in {1..60}; do
  JOIN_CMD=$(aws ssm get-parameter \
    --name "/k8s/join-command" \
    --query "Parameter.Value" \
    --output text \
    --region us-east-2 2>/dev/null)

  if [[ -n "$JOIN_CMD" ]]; then
    echo "Join command encontrado."
    break
  fi

  sleep 10
done

if [[ -z "$JOIN_CMD" ]]; then
  echo "Join command não encontrado após timeout."
  exit 1
fi

# Evita rejoin se já estiver configurado
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "Node já parece estar configurado. Abortando join."
  exit 0
fi

echo "Executando kubeadm join..."

$JOIN_CMD --node-name $(hostname -s) --v=5 | tee /var/log/kubeadm-join.log

echo "Worker entrou no cluster com sucesso"

echo "===== FIM USER DATA WORKER ====="
EOF

  tags = {
    Name = "k8sWorker"
  }
  vpc_security_group_ids = [aws_security_group.workers_sg.id]
}


resource "aws_instance" "worker_2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.k8s_profile.name
  subnet_id     = aws_subnet.private_cluster_subnet_2.id
  key_name = aws_key_pair.k8s_workers.key_name

user_data = <<-EOF
#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "===== INICIANDO USER DATA WORKER ====="

# IPv6 + APT

echo "Desabilitando IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

cat <<EOT > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOT

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# BASE

apt-get update -y

sed -i '/ swap / s/^/#/' /etc/fstab
swapoff -a

# KERNEL

cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# DEPENDÊNCIAS

apt-get install -y \
  apt-transport-https \
  curl \
  gnupg \
  lsb-release \
  ca-certificates \
  unzip

# AWS CLI

apt-get remove -y awscli || true

curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install

# KUBERNETES

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
 | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
 > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=1.29.* kubeadm=1.29.* kubectl=1.29.*
apt-mark hold kubelet kubeadm kubectl

# CONTAINERD

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
 | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
 > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

# JOIN AUTOMÁTICO

echo "Aguardando join command no SSM..."

for i in {1..60}; do
  JOIN_CMD=$(aws ssm get-parameter \
    --name "/k8s/join-command" \
    --query "Parameter.Value" \
    --output text \
    --region us-east-2 2>/dev/null)

  if [[ -n "$JOIN_CMD" ]]; then
    echo "Join command encontrado."
    break
  fi

  sleep 10
done

if [[ -z "$JOIN_CMD" ]]; then
  echo "Join command não encontrado após timeout."
  exit 1
fi

# Evita rejoin se já estiver configurado
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "Node já parece estar configurado. Abortando join."
  exit 0
fi

echo "Executando kubeadm join..."

$JOIN_CMD --node-name $(hostname -s) --v=5 | tee /var/log/kubeadm-join.log

echo "Worker entrou no cluster com sucesso"

echo "===== FIM USER DATA WORKER ====="
EOF

  tags = {
    Name = "k8sWorker"
  }
  vpc_security_group_ids = [aws_security_group.workers_sg.id]
}

resource "tls_private_key" "k8s_workers" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_workers" {
  key_name   = "k8s-workers-key"
  public_key = tls_private_key.k8s_workers.public_key_openssh
}


