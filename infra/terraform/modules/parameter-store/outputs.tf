# =============================================================================
# Parameter Store Module Outputs
# =============================================================================

# =============================================================================
# Parameter ARNs (EKS에서는 IRSA로 Pod에서 SSM GetParameter 권한 부여 후 사용)
# =============================================================================
output "db_password_arn" {
  description = "DB Password Parameter ARN"
  value       = aws_ssm_parameter.db_password.arn
}

output "jwt_secret_arn" {
  description = "JWT Secret Parameter ARN"
  value       = aws_ssm_parameter.jwt_secret.arn
}

output "mail_password_arn" {
  description = "Mail Password Parameter ARN"
  value       = var.mail_password != "" ? aws_ssm_parameter.mail_password[0].arn : null
}

output "toss_secret_key_arn" {
  description = "Toss Secret Key Parameter ARN"
  value       = var.toss_secret_key != "" ? aws_ssm_parameter.toss_secret_key[0].arn : null
}

output "db_endpoint_arn" {
  description = "DB Endpoint Parameter ARN"
  value       = aws_ssm_parameter.db_endpoint.arn
}

output "redis_endpoint_arn" {
  description = "Redis Endpoint Parameter ARN"
  value       = var.redis_endpoint != "" ? aws_ssm_parameter.redis_endpoint[0].arn : null
}

# =============================================================================
# All Parameter ARNs (IAM Policy용)
# =============================================================================
output "all_parameter_arns" {
  description = "모든 Parameter ARN 목록 (EKS IRSA/IAM Policy용)"
  value = compact([
    aws_ssm_parameter.db_password.arn,
    aws_ssm_parameter.jwt_secret.arn,
      var.mail_password != "" ? aws_ssm_parameter.mail_password[0].arn : null,
      var.toss_secret_key != "" ? aws_ssm_parameter.toss_secret_key[0].arn : null,
    aws_ssm_parameter.db_endpoint.arn,
      var.redis_endpoint != "" ? aws_ssm_parameter.redis_endpoint[0].arn : null,
  ])
}

# =============================================================================
# Parameter Name Prefix (for wildcard IAM policies)
# =============================================================================
output "parameter_prefix" {
  description = "Parameter Store prefix (EKS IRSA/IAM wildcard policy에서 사용)"
  value       = "/${var.project}/${var.environment}"
}
