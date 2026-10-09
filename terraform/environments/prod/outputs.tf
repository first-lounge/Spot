# output "acm_certificate_arn" {
#   description = "ACM 인증서 ARN"
#   value       = module.acm.aws_acm_certificate_arn
# }

output "rds_host" {
  description = "RDS Host"
  value       = module.rds.rds_host
}

output "elasticache_primary_endpoint" {
  description = "Redis 쓰기용 엔드포인트"
  value       = module.elasticache.elasticache_primary_endpoint
}

# output "github_oidc_role_arn" {
#   description = "GitHub OIDC Role ARN"
#   value       = module.github_oidc.github_oidc_role_arn
# }
