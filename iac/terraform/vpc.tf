resource "aws_security_group" "sandbox_sg" {
  name        = "sandbox_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}


resource "aws_vpc_security_group_ingress_rule" "allow_http_2" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 10250
  ip_protocol       = "tcp"
  to_port           = 10259
}


resource "aws_vpc_security_group_ingress_rule" "allow_http_3" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  ip_protocol       = "tcp"
  to_port           = 30000
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_4" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 32767
  ip_protocol       = "tcp"
  to_port           = 32767
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_5" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 2379
  ip_protocol       = "tcp"
  to_port           = 2380
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_6" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6783
  ip_protocol       = "tcp"
  to_port           = 6783
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_7" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6783
  ip_protocol       = "udp"
  to_port           = 6783
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_8" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.sandbox_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
