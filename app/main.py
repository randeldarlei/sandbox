import json
import tempfile
import os
import re
import subprocess
from fastapi import FastAPI

app = FastAPI()

TERRAFORM_DIR = "iac/kubeadm-cluster"


def run_terraform(command: list):
    return subprocess.run(
        command,
        cwd=TERRAFORM_DIR,
        capture_output=True,
        text=True
    )


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


from fastapi.responses import Response

@app.get("/get")
def get_cluster_context():

    output = run_terraform(["terraform", "output", "-json", "-no-color"])

    if output.returncode != 0:
        return {"error": output.stderr}

    data = json.loads(output.stdout)

    try:
        master_ip = data["Control_Plane_Public_Ip"]["value"]
        private_key = data["private_key_pem"]["value"]
    except KeyError:
        return {"error": "Cluster outputs not found. Is the cluster created?"}

    with tempfile.NamedTemporaryFile(delete=False) as key_file:
        key_file.write(private_key.encode())
        key_file.flush()
        os.chmod(key_file.name, 0o600)
        key_path = key_file.name

    ssh = subprocess.run(
        [
            "ssh",
            "-o", "StrictHostKeyChecking=no",
            "-i", key_path,
            f"ubuntu@{master_ip}",
            "sudo cat /etc/kubernetes/admin.conf"
        ],
        capture_output=True,
        text=True
    )

    os.remove(key_path)

    if ssh.returncode != 0:
        return {"error": ssh.stderr}

    kubeconfig = ssh.stdout

    kubeconfig = re.sub(
        r"https://.*:6443",
        f"https://{master_ip}:6443",
        kubeconfig
    )

    return Response(
        content=kubeconfig,
        media_type="application/x-yaml",
        headers={
            "Content-Disposition": "attachment; filename=kubeconfig.yaml"
        }
    )
