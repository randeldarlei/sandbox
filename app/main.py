import json
import os
import re
import subprocess
from fastapi import FastAPI
from fastapi.responses import Response

app = FastAPI()

TERRAFORM_DIR = "iac/kubeadm-cluster"
SSH_KEY = "/app/id_rsa"


def run_terraform(command: list):
    """Executa comandos Terraform"""
    return subprocess.run(
        command,
        cwd=TERRAFORM_DIR,
        capture_output=True,
        text=True
    )


def get_control_plane_ip():
    """Obtém o IP público do control plane via terraform output"""

    output = run_terraform(["terraform", "output", "-json", "-no-color"])

    if output.returncode != 0:
        raise Exception(output.stderr)

    data = json.loads(output.stdout)

    try:
        return data["Control_Plane_Public_Ip"]["value"]
    except KeyError:
        raise Exception("Control Plane IP not found in Terraform outputs")


def ssh_command(ip: str, command: str):
    """Executa comando remoto via SSH"""

    ssh = subprocess.run(
        [
            "ssh",
            "-o", "StrictHostKeyChecking=no",
            "-i", SSH_KEY,
            f"ubuntu@{ip}",
            command
        ],
        capture_output=True,
        text=True
    )

    if ssh.returncode != 0:
        raise Exception(ssh.stderr)

    return ssh.stdout


@app.get("/")
def home():
    return {"message": "Cluster Platform"}


@app.post("/create")
def create_cluster():

    init = run_terraform(["terraform", "init", "-reconfigure", "-no-color"])

    if init.returncode != 0:
        return {
            "phase": "init",
            "stdout": init.stdout,
            "stderr": init.stderr
        }

    apply = run_terraform(["terraform", "apply", "-auto-approve", "-no-color"])

    return {
        "phase": "apply",
        "stdout": apply.stdout,
        "stderr": apply.stderr
    }


@app.delete("/delete")
def delete_cluster():

    init = run_terraform(["terraform", "init", "-reconfigure", "-no-color"])

    if init.returncode != 0:
        return {
            "phase": "init",
            "stdout": init.stdout,
            "stderr": init.stderr
        }

    destroy = run_terraform(["terraform", "destroy", "-auto-approve", "-no-color"])

    return {
        "phase": "destroy",
        "stdout": destroy.stdout,
        "stderr": destroy.stderr
    }


@app.get("/get")
def get_cluster_context():
    """
    Retorna o kubeconfig do cluster
    """

    try:
        master_ip = get_control_plane_ip()

        kubeconfig = ssh_command(
            master_ip,
            "sudo cat /etc/kubernetes/admin.conf"
        )

        # Substitui o server interno pelo IP público
        kubeconfig = re.sub(
            r"server: https://.*:6443",
            f"server: https://{master_ip}:6443",
            kubeconfig
        )

        return Response(
            content=kubeconfig,
            media_type="application/x-yaml",
            headers={
                "Content-Disposition": "attachment; filename=kubeconfig.yaml"
            }
        )

    except Exception as e:
        return {"error": str(e)}


@app.get("/status")
def cluster_status():
    """
    Retorna o status do cluster (nodes)
    """

    try:
        master_ip = get_control_plane_ip()

        nodes = ssh_command(
            master_ip,
            "sudo kubectl get nodes -o json"
        )

        return json.loads(nodes)

    except Exception as e:
        return {"error": str(e)}