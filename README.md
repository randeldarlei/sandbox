# 🚀 Kubernetes Cluster with kubeadm on AWS (Terraform)

## 📌 Arquitetura

Este projeto provisiona automaticamente:

- VPC customizada
- Subnets públicas e privadas
- NAT Gateway
- Security Groups segregados
- 1 EC2 Control Plane
- 2 EC2 Worker Nodes
- Join automático via AWS SSM

### Topologia

Internet
   │
Public Subnet
   ├── Control Plane (API 6443)
   └── NAT Gateway
           │
Private Subnets
   ├── Worker Node 1
   └── Worker Node 2

Workers não possuem IP público.

---

# 🔐 Pré-requisitos

- Conta AWS
- Usuário IAM com permissões:
  - EC2
  - VPC
  - IAM
  - SSM

Configure suas credenciais AWS:

aws configure

---

# 🔑 Gerando chave SSH

ssh-keygen -t ed25519 -f k8s-workers-key

---

# 🏗 Provisionando infraestrutura

terraform init
terraform apply

---

# 🖥 Acessando o Control Plane

ssh -A -i k8s-workers-key ubuntu@<PUBLIC_IP_CONTROL_PLANE>

---

# 🔎 Validando cluster

kubectl get nodes

---

# 🧪 Testando o cluster

kubectl run nginx-test --image=nginx:latest --restart=Never
kubectl get pods -o wide

---

# 📊 Logs importantes

Worker:
/var/log/user-data.log
/var/log/kubeadm-join.log

Control Plane:
/var/log/cloud-init-output.log

---

# 🧨 Destruir ambiente

terraform destroy
