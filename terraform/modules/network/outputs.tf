output "vpc_id" {
  value = aws_vpc.spot_vpc.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "db_subnet_ids" {
  value = [for s in aws_subnet.db : s.id]
}
