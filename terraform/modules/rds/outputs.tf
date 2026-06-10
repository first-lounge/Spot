output "rds_arn" {
  description = "RDS ARN"
  value       = aws_db_instance.rds.arn
}

output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = aws_db_instance.rds.address
}
