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

resource "aws_instance" "control_plane" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y

swapoff -a

# Garante diretório
mkdir -p /etc/modules-load.d

# Módulos do Kubernetes
cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Sysctl para Kubernetes
mkdir -p /etc/sysctl.d

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# Dependências
apt-get install -y apt-transport-https curl

# Repositório Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOT > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOT

apt-get update -y

# Instala Kubernetes
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
EOF

  tags = {
    Name = "k8sadm"
  }
  vpc_security_group_ids = [aws_security_group.sandbox_sg.id]
}

resource "aws_instance" "worker_1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y

swapoff -a

# Garante diretório
mkdir -p /etc/modules-load.d

# Módulos do Kubernetes
cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Sysctl para Kubernetes
mkdir -p /etc/sysctl.d

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# Dependências
apt-get install -y apt-transport-https curl

# Repositório Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOT > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOT

apt-get update -y

# Instala Kubernetes
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
EOF

  tags = {
    Name = "k8sadm"
  }
  vpc_security_group_ids = [aws_security_group.sandbox_sg.id]
}

resource "aws_instance" "worker_2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y

swapoff -a

# Garante diretório
mkdir -p /etc/modules-load.d

# Módulos do Kubernetes
cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Sysctl para Kubernetes
mkdir -p /etc/sysctl.d

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# Dependências
apt-get install -y apt-transport-https curl

# Repositório Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOT > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOT

apt-get update -y

# Instala Kubernetes
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
EOF

  tags = {
    Name = "k8sadm"
  }
  vpc_security_group_ids = [aws_security_group.sandbox_sg.id]
}