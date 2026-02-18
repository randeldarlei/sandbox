resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg"
  description = "Security Group for Kubernetes Control Plane"
  vpc_id      = aws_vpc.cluster_vpc.id

  tags = {
    Name = "control-plane-sg"
  }
}

# SECURITY GROUP - CONTROL-PLANE

# SSH somente do seu IP
resource "aws_vpc_security_group_ingress_rule" "cp_ssh" {
  security_group_id = aws_security_group.control_plane_sg.id
  cidr_ipv4         = "200.53.202.33/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# API Server acessível apenas do seu IP
resource "aws_vpc_security_group_ingress_rule" "cp_api_from_admin" {
  security_group_id = aws_security_group.control_plane_sg.id
  cidr_ipv4         = "200.53.202.33/32"
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# API Server acessível pelos workers
resource "aws_vpc_security_group_ingress_rule" "cp_api_from_workers" {
  security_group_id            = aws_security_group.control_plane_sg.id
  referenced_security_group_id = aws_security_group.workers_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

# Kubelet communication (control-plane → workers)
resource "aws_vpc_security_group_ingress_rule" "cp_kubelet" {
  security_group_id            = aws_security_group.control_plane_sg.id
  referenced_security_group_id = aws_security_group.workers_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

# Egress livre (necessário para internet via NAT)
resource "aws_vpc_security_group_egress_rule" "cp_egress" {
  security_group_id = aws_security_group.control_plane_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# SECURITY GROUP - WORKERS

resource "aws_security_group" "workers_sg" {
  name        = "workers-sg"
  description = "Security Group for Kubernetes Worker Nodes"
  vpc_id      = aws_vpc.cluster_vpc.id

  tags = {
    Name = "workers-sg"
  }
}

# SSH somente do seu IP (opcional, mas útil para debug)
resource "aws_vpc_security_group_ingress_rule" "workers_ssh" {
  security_group_id = aws_security_group.workers_sg.id
  cidr_ipv4         = "200.53.202.33/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Comunicação interna entre workers (CNI, pods, etc)
resource "aws_vpc_security_group_ingress_rule" "workers_internal" {
  security_group_id            = aws_security_group.workers_sg.id
  referenced_security_group_id = aws_security_group.workers_sg.id
  ip_protocol                  = "-1"
}


# Comunicação do control plane → workers
resource "aws_vpc_security_group_ingress_rule" "workers_from_cp" {
  security_group_id            = aws_security_group.workers_sg.id
  referenced_security_group_id = aws_security_group.control_plane_sg.id
  ip_protocol                  = "-1"
}

# Egress livre (internet via NAT)
resource "aws_vpc_security_group_egress_rule" "workers_egress" {
  security_group_id = aws_security_group.workers_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# SECURITY GROUP - ALB

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security Group for Application Load Balancer"
  vpc_id      = aws_vpc.cluster_vpc.id

  tags = {
    Name = "alb-sg"
  }
}

# HTTP
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ALB → Workers
resource "aws_vpc_security_group_ingress_rule" "workers_from_alb" {
  security_group_id            = aws_security_group.workers_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
}