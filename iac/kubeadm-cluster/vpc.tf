############################
# VPC (BASE DO AMBIENTE)
############################

resource "aws_vpc" "cluster_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Cluster VPC"
  }
}

############################
# CONTEXTO PÚBLICO
# - Entrada da Internet
# - NAT Gateway
############################

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "Cluster IGW"
  }
}

# Route Table Pública
resource "aws_route_table" "public_cluster_route_table" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "Public Route Table"
  }
}

# Rota pública para Internet
resource "aws_route" "public_to_internet" {
  route_table_id         = aws_route_table.public_cluster_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Subnets Públicas
resource "aws_subnet" "public_cluster_subnet_1" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_cluster_subnet_2" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 2"
  }
}

# Associações públicas
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_cluster_subnet_1.id
  route_table_id = aws_route_table.public_cluster_route_table.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_cluster_subnet_2.id
  route_table_id = aws_route_table.public_cluster_route_table.id
}

# Elastic IP para NAT
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "Cluster NAT EIP"
  }
}

# NAT Gateway (fica em subnet pública)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_cluster_subnet_1.id

  tags = {
    Name = "Cluster NAT Gateway"
  }

  depends_on = [aws_internet_gateway.gw]
}

############################
# CONTEXTO PRIVADO
# - Nodes do cluster
# - Pods
############################

# Route Table Privada
resource "aws_route_table" "private_cluster_route_table" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "Private Route Table"
  }
}

# Rota privada para NAT
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private_cluster_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# Subnets Privadas
resource "aws_subnet" "private_cluster_subnet_1" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private_cluster_subnet_2" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 2"
  }
}

# Associações privadas
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_cluster_subnet_1.id
  route_table_id = aws_route_table.private_cluster_route_table.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_cluster_subnet_2.id
  route_table_id = aws_route_table.private_cluster_route_table.id
}
