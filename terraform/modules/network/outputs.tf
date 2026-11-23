output "vpc_id" {
  value = aws_vpc.spot_vpc.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "private_subnet_ids_map" {
  value = { for k, v in aws_subnet.private : k => v.id }
}

output "db_subnet_ids" {
  value = [for s in aws_subnet.db : s.id]
}
