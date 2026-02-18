output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_a_id" {
  description = "Public Subnet A ID"
  value       = aws_subnet.public_a.id
}

output "public_subnet_c_id" {
  value = try(aws_subnet.public_c[0].id, null)
}

output "public_subnet_ids" {
  value = compact([
    aws_subnet.public_a.id,
    try(aws_subnet.public_c[0].id, null)
  ])
}

output "private_subnet_a_id" {
  description = "Private Subnet A ID"
  value       = aws_subnet.private_a.id
}

output "private_subnet_c_id" {
  description = "Private Subnet C ID"
  value       = aws_subnet.private_c.id
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
}

# =============================================================================
# NAT Gateway Outputs
# =============================================================================
output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_elastic_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = aws_eip.nat[*].public_ip
}

output "nat_type" {
  description = "NAT 유형 (gateway 또는 instance)"
  value       = var.use_nat_gateway ? "gateway" : "instance"
}
