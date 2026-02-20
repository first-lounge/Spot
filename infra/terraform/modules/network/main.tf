# =============================================================================
# VPC
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

# =============================================================================
# Public Subnets
# =============================================================================
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs["a"]
  availability_zone       = var.availability_zones["a"]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-a"
    Tier = "public"

    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  })
}

resource "aws_subnet" "public_c" {
  count                   = var.use_nat_gateway && !var.single_nat_gateway ? 1 : (contains(keys(var.public_subnet_cidrs), "c") ? 1 : 0)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = lookup(var.public_subnet_cidrs, "c", "10.1.2.0/24")
  availability_zone       = var.availability_zones["c"]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-c"
    Tier = "public"

    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  })
}

# =============================================================================
# Private Subnets
# =============================================================================
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs["a"]
  availability_zone       = var.availability_zones["a"]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-a"
    Tier = "private"

    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  })
}

resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs["c"]
  availability_zone       = var.availability_zones["c"]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-c"
    Tier = "private"

    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  })
}

# =============================================================================
# Internet Gateway
# =============================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-igw" })
}

# =============================================================================
# NAT Instance (Development - Cost Optimized)
# =============================================================================
resource "aws_security_group" "nat_sg" {
  count  = var.use_nat_gateway ? 0 : 1
  name   = "${var.name_prefix}-nat-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-sg" })
}

data "aws_ami" "al2023" {
  count       = var.use_nat_gateway ? 0 : 1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "nat_instance" {
  count                       = var.use_nat_gateway ? 0 : 1
  ami                         = data.aws_ami.al2023[0].id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.nat_sg[0].id]
  associate_public_ip_address = true
  source_dest_check           = false

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              sysctl -w net.ipv4.ip_forward=1

              # NAT (masquerade) via nftables (AL2023)
              nft list table ip nat >/dev/null 2>&1 || nft add table ip nat
              nft list chain ip nat postrouting >/dev/null 2>&1 || nft add chain ip nat postrouting '{ type nat hook postrouting priority 100 ; }'
              nft add rule ip nat postrouting oifname "eth0" masquerade 2>/dev/null || true
              EOF

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-instance" })
}

# =============================================================================
# NAT Gateway (Production - High Availability)
# =============================================================================
resource "aws_eip" "nat" {
  count  = var.use_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index == 0 ? "a" : "c"}"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "main" {
  count         = var.use_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = count.index == 0 ? aws_subnet.public_a.id : aws_subnet.public_c[0].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-gw-${count.index == 0 ? "a" : "c"}"
  })

  depends_on = [aws_internet_gateway.igw]
}
# =============================================================================
# Route Tables
# =============================================================================
# -------------------------
# Public Route Table
# -------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

locals {
  create_public_c = (
    var.use_nat_gateway && !var.single_nat_gateway
    ? true
    : contains(keys(var.public_subnet_cidrs), "c")
  )
}

resource "aws_route_table_association" "public_c" {
  count          = local.create_public_c ? 1 : 0
  subnet_id      = aws_subnet.public_c[0].id
  route_table_id = aws_route_table.public.id
}



# -------------------------
# Private Route Table (AZ-a)
# -------------------------
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-private-rt-a" })
}

# Private default route via NAT Gateway (when enabled)
resource "aws_route" "private_a_nat_gw" {
  count                  = var.use_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# Private default route via NAT Instance (dev cost optimized)
resource "aws_route" "private_a_nat_instance" {
  count                  = var.use_nat_gateway ? 0 : 1
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# -------------------------
# Private Route Table (AZ-c)
# - Multi NAT GW이면 별도 RT + NAT GW(1)
# - Single NAT GW이면 private_a RT를 공유
# -------------------------
resource "aws_route_table" "private_c" {
  count  = var.use_nat_gateway && !var.single_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-rt-c" })
}

resource "aws_route" "private_c_nat_gw" {
  count                  = var.use_nat_gateway && !var.single_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private_c[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[1].id
}

resource "aws_route_table_association" "private_c" {
  subnet_id = aws_subnet.private_c.id
  route_table_id = (
    var.use_nat_gateway && !var.single_nat_gateway
    ? aws_route_table.private_c[0].id
    : aws_route_table.private_a.id
  )
}
