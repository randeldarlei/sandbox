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

```bash
Internet
   │
Public Subnet
   ├── Control Plane (API 6443)
   └── NAT Gateway
           │
Private Subnets
   ├── Worker Node 1
   └── Worker Node 2
```

Workers não possuem IP público.

---

### 🔐 Pré-requisitos

- Conta AWS
- Usuário IAM com permissões:
  - EC2 
  - VPC
  - IAM
  - SSM
  - Conta na HashiCorp Cloud
 
- Crie um ACCESS_KEY e uma SECRET_KEY na AWS.

- Configure suas credenciais AWS:

```bash
aws configure
```

---

### 🔑 Gerando chave SSH

```bash
ssh-keygen -t ed25519 -f k8s-workers-key
```

---

### Configurando Workspace Hashcorp Cloud

- Crie uma *Organization* e um *Workspace* e altere o arquivo `provider.tf`caso necessário:

```hcl
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "<ORG_NAME>"

    workspaces {
      name = "<WORKSPACE_NAME>"
    }
  }
}
```
- Gere um User API_TOKEN e salve como variável neste repositório *HASHICORP_TOKEN*

- Adicione como variável de ambiente no Workspace do Terraform os valores de *ACCESS_KEY* e *SECRET_KEY*:

```hcl
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "us-east-2"
}
```

### 🏗 Provisionando infraestrutura

```hcl
terraform init
terraform apply
```

---

### 🖥 Acessando o Control Plane

```bash
ssh -A -i k8s-workers-key ubuntu@<PUBLIC_IP_CONTROL_PLANE>
```

---

### 🔎 Validando cluster

```bash
kubectl get nodes
```

---

### 🧪 Testando o cluster

```bash
kubectl run nginx-test --image=nginx:latest --restart=Never
kubectl get pods -o wide
```

---

### 📊 Logs importantes

*Worker:*
```bash
/var/log/user-data.log
/var/log/kubeadm-join.log
```

*Control Plane:*
```bash
/var/log/cloud-init-output.log
```

---

### 🧨 Destruir ambiente

```hcl
terraform destroy
```
