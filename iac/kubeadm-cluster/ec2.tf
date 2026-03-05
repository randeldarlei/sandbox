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
set -euxo pipefail

exec > >(tee /var/log/bootstrap.log) 2>&1

echo "Waiting for internet..."

until ping -c1 google.com >/dev/null 2>&1
do
  sleep 5
done

until apt-get update -y
do
  echo "APT not ready yet"
  sleep 10
done

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
cat <<EOT > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

modprobe overlay
modprobe br_netfilter

# Sysctl
cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system

# Dependencies
apt-get install -y \
  apt-transport-https \
  curl \
  gnupg \
  lsb-release \
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

# Wait runtime
until systemctl is-active --quiet containerd
do
  sleep 2
done

# Metadata
TOKEN=$(curl -sX PUT \
"http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

CONTROL_PLANE_IP=$(curl -s \
-H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/local-ipv4)

PUBLIC_IP=$(curl -s \
-H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/public-ipv4)

# Init cluster
kubeadm init \
--pod-network-cidr=10.10.0.0/16 \
--apiserver-advertise-address=$CONTROL_PLANE_IP \
--apiserver-cert-extra-sans=$PUBLIC_IP,127.0.0.1

# kubeconfig
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

# Wait API
for i in {1..60}
do
  if kubectl get nodes >/dev/null 2>&1
  then
    break
  fi
  sleep 5
done

# Install CNI
kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml

# Publish join command
JOIN_CMD=$(kubeadm token create --ttl 0 --print-join-command)

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

resource "aws_key_pair" "k8s_workers" {
  key_name   = "k8s-workers-key"
  public_key = file("k8s-workers-key.pub")
}


