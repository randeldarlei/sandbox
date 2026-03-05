# 🚀 Kubernetes Cluster with kubeadm on AWS (Terraform)

## 📌 Arquitetura

Este projeto provisiona automaticamente um **cluster Kubernetes com kubeadm na AWS** utilizando **Terraform**.

Infraestrutura criada:

- VPC customizada
- Subnets públicas e privadas
- Internet Gateway
- NAT Gateway
- Security Groups segregados
- 1 EC2 **Control Plane**
- **Auto Scaling Group** de Worker Nodes
- **Launch Template** para bootstrap automático
- **Application Load Balancer (ALB)**
- Join automático dos Workers via **AWS SSM Parameter Store**

---

# 🏗 Topologia

```

```
             Internet
                 │
                ALB
                 │
         Target Group (NodePort)
                 │
         Auto Scaling Group
          /              \
    Worker Node       Worker Node
       (private)        (private)
            │              │
            └──── Kubernetes ────┘
                      │
              Control Plane
                (public subnet)
                      │
                  NAT Gateway
```

````

### Características da arquitetura

- Workers **não possuem IP público**
- Comunicação externa ocorre via **ALB**
- Workers são **auto escaláveis**
- Worker nodes fazem **join automático no cluster**

---

# 🔐 Pré-requisitos

- Conta AWS
- Terraform
- AWS CLI
- kubectl
- Docker (para rodar a API local)

Permissões necessárias no IAM:

- EC2
- VPC
- IAM
- SSM
- Elastic Load Balancer
- Auto Scaling

---

# 🔑 Configurando credenciais AWS

Configure suas credenciais:

```bash
aws configure
````

Ou exporte variáveis:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-2
```

---

# 🔑 Gerando chave SSH

```bash
ssh-keygen -t ed25519 -f k8s-workers-key
```

Arquivos gerados:

```
k8s-workers-key
k8s-workers-key.pub
```

A chave pública é usada pelo Terraform.

---

# 🏗 Provisionando infraestrutura

Inicialize Terraform:

```bash
terraform init
```

Crie o cluster:

```bash
terraform apply
```

Terraform irá provisionar automaticamente:

* VPC
* Subnets
* NAT Gateway
* Security Groups
* Control Plane
* Auto Scaling Group
* Worker nodes
* Application Load Balancer

---

# 🖥 Obtendo kubeconfig do cluster

Primeiro obtenha o IP do control plane:

```bash
terraform output -raw Control_Plane_Public_Ip
```

Copie o kubeconfig:

```bash
scp -i k8s-workers-key \
ubuntu@<CONTROL_PLANE_PUBLIC_IP>:/etc/kubernetes/admin.conf \
kubeconfig.yaml
```

Edite o arquivo e substitua:

```
server: https://10.x.x.x:6443
```

por

```
server: https://<CONTROL_PLANE_PUBLIC_IP>:6443
```

---

# ⚙️ Configurando kubectl

Exportar kubeconfig:

```bash
export KUBECONFIG=$(pwd)/kubeconfig.yaml
```

Testar acesso ao cluster:

```bash
kubectl get nodes
```

---

# 🔎 Validando cluster

```bash
kubectl get nodes -o wide
```

Saída esperada:

```
NAME            STATUS   ROLES
ip-10-0-1-79    Ready    control-plane
ip-10-0-3-12    Ready    <none>
ip-10-0-5-44    Ready    <none>
```

---

# 🧪 Testando deploy

Criar um pod de teste:

```bash
kubectl run nginx-test --image=nginx --restart=Never
```

Verificar pods:

```bash
kubectl get pods -o wide
```

---

# 🌐 Testando acesso via ALB

Exponha um serviço NodePort:

```bash
kubectl expose deployment nginx \
--type=NodePort \
--port=80
```

Verifique NodePort:

```bash
kubectl get svc
```

O ALB encaminha tráfego para a porta:

```
30007
```

Acesse via DNS do Load Balancer:

```bash
terraform output Alb_dns_name
```

---

# 📊 Logs importantes

## Worker Nodes

```
/var/log/user-data.log
/var/log/kubeadm-join.log
```

## Control Plane

```
/var/log/cloud-init-output.log
```

---

# ⚙️ Estrutura do projeto

```
iac/
 └ kubeadm-cluster
     ├ provider.tf
     ├ vpc.tf
     ├ security_groups.tf
     ├ control-plane.tf
     ├ alb.tf
     ├ outputs.tf
     └ worker-bootstrap.sh
```

---

# 🧨 Destruir infraestrutura

Para remover todo ambiente:

```bash
terraform destroy
```

---

# 🧠 Componentes principais

### kubeadm

Inicializa o cluster Kubernetes.

### containerd

Runtime de containers utilizado pelos nodes.

### Calico

CNI responsável pela rede de pods.

### AWS SSM Parameter Store

Utilizado para distribuir o comando de join dos workers.

---

# 📦 Fluxo de criação do cluster

```
terraform apply
      │
      ▼
Control Plane inicia
      │
kubeadm init
      │
Join command salvo no SSM
      │
Workers iniciam
      │
worker-bootstrap.sh executa
      │
Workers fazem join automático
      │
Cluster disponível
```

---

# 🚀 Melhorias futuras

Possíveis evoluções da arquitetura:

* Metrics Server
* Horizontal Pod Autoscaler
* AWS Load Balancer Controller
* Cluster Autoscaler
* CI/CD para provisionamento
* API de provisionamento de clusters

```

---

✅ Esse README agora está **100% alinhado com sua arquitetura atual**:

- kubeadm  
- ALB  
- ASG  
- Launch Template  
- Worker bootstrap  
- Join automático via SSM  

---

Se quiser, também posso gerar uma **versão ainda mais profissional (estilo GitHub open-source)** com:

- diagramas
- badges
- arquitetura visual
- explicação de cada módulo Terraform.
```
