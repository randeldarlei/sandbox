# README – Join manual dos nodes Worker no cluster Kubernetes

## Contexto

Este cenário assume que:

* As **três instâncias EC2 já foram criadas** via Terraform:

  * 1 instância **Control Plane**
  * 2 instâncias **Worker**
* Todas as instâncias já executaram com sucesso o `user_data` de preparação:

  * kubelet, kubeadm e kubectl instalados
  * containerd configurado
  * módulos e sysctl aplicados
* O cluster **já foi inicializado no Control Plane** com `kubeadm init`

Este README descreve **exclusivamente o passo manual necessário** para que os nodes Worker entrem no cluster.

---
## Configurando Provider e gerando uma chave SSH para acesso as inatâncias do Worker:

Vá a console da AWS, crie um usuário atribua permissões necessárias para gerenciar `EC2`, `VPC` e `IAM`.

Gere uma `ACCESS_KEY` e `SECRET_KEY`, adicione ao arquivo `providers.tf`.

No seu terminal local execute o comando a seguir e siga o fluxo para gerar uma chave `ssh`:

```bash
ssh-keygen -t ed25519 -f k8s-workers-key
```

Em seguida rode o `Terraform` normalmente:

```bash

terraform init

terraform apply
```

---


## 1️⃣ Acessar o Control Plane

Conecte-se via SSH na instância que atua como **Control Plane**.

Exemplo:

```bash
ssh -A -i k8s-workers-key.pem ubuntu@<IP_DO_CONTROL_PLANE>
```

Validar se o `user_data` deu certo:

```bash

sudo cloud-init status

sudo tail -n 200 /var/log/cloud-init-output.log

sudo kubeadm init
```

---

## 2️⃣ Gerar o comando de join

No Control Plane, execute:

```bash
sudo kubeadm token create --print-join-command
```

Esse comando irá gerar uma saída semelhante a:

```bash
kubeadm <CONTROL_PLANE_IP> --token <TOKEN_ID>\
  --discovery-token-ca-cert-hash sha256:<CERT_ID>
```

Copie o comando de `Join` e acesse uma das instâncias `Workers` via ssh diretamente do `Control Plane` ele irá servir como um bastion host:

ssh ubuntu@<PRIVATE_IP_HOST>

### O que o comando de Join contém

* **IP:PORT do Control Plane** (API Server)
* **Token de bootstrap** para o node entrar no cluster
* **Hash do certificado da CA**, usado para validar o cluster

> ⚠️ Importante: o token possui tempo de validade. Caso expire, gere um novo repetindo este passo.

---

## 3️⃣ Executar o join em cada Worker

Agora, conecte-se via SSH **em cada instância Worker**, uma por vez.

Exemplo:

```bash
ssh ubuntu@<IP_DO_WORKER>
```

Execute **exatamente o comando gerado no passo anterior**, adicionando `sudo`:

```bash
kubeadm <CONTROL_PLANE_IP> --token <TOKEN_ID>\
  --discovery-token-ca-cert-hash sha256:<CERT_ID>
```

Aguarde a mensagem de sucesso indicando que o node foi registrado no cluster.

Repita este passo para **todos os Workers**.

---

## 4️⃣ Validar os nodes no cluster

Volte ao Control Plane e execute:

```bash
kubectl get nodes
```

Já no Node execute:

```bash
kubectl run nginx-test \
  --image=nginx:latest \
  --restart=Never
```

Valide a integridade do Pod criado:

```bash
kubectl logs <pod-name> -o wide
``

---