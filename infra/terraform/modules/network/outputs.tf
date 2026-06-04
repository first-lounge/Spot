output "vpc_id" {
  value = aws_vpc.spot_vpc.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "db_subnet_ids" {
  value = [for s in aws_subnet.db : s.id]
}

output "nat_instance_eni" {
  value = var.enable_nat_instance ? aws_instance.nat_instance[0].primary_network_interface_id : null
}
