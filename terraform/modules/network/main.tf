# =============================================================================
# VPC
# =============================================================================
resource "aws_vpc" "spot_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

# =============================================================================
# VPC Gateway Endpoint
# =============================================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.spot_vpc.id
  service_name = "com.amazonaws.${var.service_region}.s3"
  route_table_ids = [
    aws_route_table.public_rt.id,
    aws_route_table.private_rt.id
  ]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

# =============================================================================
# VPC Interface Endpoint (Prod)
# =============================================================================

# ecr.api: ECR API 호출용
resource "aws_vpc_endpoint" "ecr_api" {
  count             = var.enable_interface_endpoint ? 1 : 0
  vpc_id            = aws_vpc.spot_vpc.id
  service_name      = "com.amazonaws.${var.service_region}.ecr.api"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    # TODO: Endpoint SG 추가 (VPC CIDR → 443 허용)
  ]

  private_dns_enabled = true
  tags                = merge(var.common_tags, { Name = "${var.name_prefix}-ecr-api-endpoint" })
}

# ecr.dkr: 이미지 pull용
resource "aws_vpc_endpoint" "ecr_dkr" {
  count             = var.enable_interface_endpoint ? 1 : 0
  vpc_id            = aws_vpc.spot_vpc.id
  service_name      = "com.amazonaws.${var.service_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  security_group_ids = [

  ]

  private_dns_enabled = true
  tags                = merge(var.common_tags, { Name = "${var.name_prefix}-ecr-dkr-endpoint" })
}

# =============================================================================
# Subnet
# =============================================================================

# Public   
resource "aws_subnet" "public" {
  for_each                = var.public_subnet_cidrs
  vpc_id                  = aws_vpc.spot_vpc.id
  availability_zone       = var.availability_zones[each.key]
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags = merge(var.common_tags, {
    Name                     = "${var.name_prefix}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private  
resource "aws_subnet" "private" {
  for_each          = var.private_subnet_cidrs
  vpc_id            = aws_vpc.spot_vpc.id
  availability_zone = var.availability_zones[each.key]
  cidr_block        = each.value
  tags = merge(var.common_tags, {
    Name                              = "${var.name_prefix}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# DB
resource "aws_subnet" "db" {
  for_each          = var.db_subnet_cidrs
  vpc_id            = aws_vpc.spot_vpc.id
  availability_zone = var.availability_zones[each.key]
  cidr_block        = each.value
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-${each.key}"
  })
}

# =============================================================================
# Internet Gateway
# =============================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.spot_vpc.id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-igw" }) # spot-igw
}

# =============================================================================
# NAT Instance (Dev)
# =============================================================================
data "aws_ami" "nat" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "nat_instance" {
  count                       = var.enable_nat_instance ? 1 : 0
  ami                         = data.aws_ami.nat.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [var.nat_sg_id]
  subnet_id                   = aws_subnet.public["a"].id
  associate_public_ip_address = true
  source_dest_check           = false

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail

              dnf install -y nftables

              # IP 포워딩 활성화
              echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf
              sysctl -p /etc/sysctl.d/99-nat.conf

              INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

              # NAT (masquerade) 설정 via nftables
              nft list table ip nat >/dev/null 2>&1 || nft add table ip nat
              nft list chain ip nat postrouting >/dev/null 2>&1 || nft add chain ip nat postrouting '{ type nat hook postrouting priority 100 ; }'
              nft add rule ip nat postrouting oifname "$INTERFACE" masquerade 2>/dev/null || true

              # 서비스 활성화 및 활서화된 규칙 저장 (재부팅 시에도 규칙 유지)
              nft "chain ip filter FORWARD { policy accept; }"
              nft list ruleset > /etc/sysconfig/nftables.conf
              systemctl enable --now nftables
              EOF

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-instance" })
}

# =============================================================================
# NAT Gateway (Prod)
# =============================================================================
resource "aws_eip" "nat_gateway" {
  for_each = var.enable_nat_gateway ? var.availability_zones : {}
  domain   = "vpc"
  tags     = merge(var.common_tags, { Name = "${var.name_prefix}-nat-gateway-eip-${each.key}" })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gateway" {
  for_each      = var.enable_nat_gateway ? var.availability_zones : {}
  allocation_id = aws_eip.nat_gateway[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge(var.common_tags, { Name = "${var.name_prefix}-nat-gateway-${each.key}" })

  depends_on = [aws_internet_gateway.igw]
}

# =============================================================================
# Route Table
# =============================================================================

# Public
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.spot_vpc.id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnet_cidrs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public_rt.id
}

# Private
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.spot_vpc.id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-private-rt" })
}

resource "aws_route" "private_nat_instance" {
  count                  = var.enable_nat_instance ? 1 : 0
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
}

resource "aws_route" "private_nat_gw" {
  for_each               = var.enable_nat_gateway ? var.availability_zones : {}
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each       = var.private_subnet_cidrs
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db" {
  for_each       = var.db_subnet_cidrs
  subnet_id      = aws_subnet.db[each.key].id
  route_table_id = aws_route_table.private_rt.id
}
