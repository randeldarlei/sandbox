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

## 1️⃣ Acessar o Control Plane

Conecte-se via SSH na instância que atua como **Control Plane**.

Exemplo:

```bash
ssh ubuntu@<IP_DO_CONTROL_PLANE>
```

Validar se o `user_data` deu certo:

```bash

sudo cloud-init status

sudo tail -n 200 /var/log/cloud-init-output.log

sudo tail -n 200 /var/log/cloud-init.log

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

### O que este comando contém

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

Saída esperada (exemplo):

```text
NAME            STATUS     ROLES           AGE     VERSION
control-plane   NotReady   control-plane   10m     v1.xx.x
worker-1        NotReady   <none>           2m      v1.xx.x
worker-2        NotReady   <none>           1m      v1.xx.x
```

> ⚠️ É normal os nodes aparecerem como **NotReady** neste momento, pois ainda **nenhum CNI foi instalado**.

---

## Conclusão

Com estes passos:

* O cluster Kubernetes está corretamente inicializado
* Os Workers foram adicionados manualmente de forma explícita e controlada
* O fluxo respeita exatamente o comportamento do `kubeadm`

Este método é **didático, previsível e alinhado com documentação oficial e provas (CKA)**.

O próximo passo natural após este README é a instalação de um **CNI (Calico, Flannel, Cilium, etc.)**.
