output "rds_arn" {
  description = "RDS ARN"
  value       = { for k, s in aws_db_instance.this : k => s.arn }
}

output "rds_host" {
  description = "RDS Host 이름"
  value       = { for k, s in aws_db_instance.this : k => s.address }
}

output "rds_secret_arn" {
  description = "RDS 인스턴스별 Secret ARN"
  value       = { for k, s in aws_db_instance.this : k => s.master_user_secret[0].secret_arn if length(s.master_user_secret) > 0 }
}
