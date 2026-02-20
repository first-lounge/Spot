# =============================================================================
# Network
# =============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.network_spot.vpc_id
}

# =============================================================================
# Database
# =============================================================================
output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.database.endpoint
}

output "spring_datasource_url" {
  description = "Spring JDBC URL"
  value       = module.database.jdbc_url
}

# =============================================================================
# ECR
# =============================================================================
output "ecr_repository_urls" {
  description = "ECR 저장소 URL 맵"
  value       = module.ecr.repository_urls
}

# =============================================================================
# WAF
# =============================================================================
# output "waf_web_acl_arn" {
#   description = "WAF Web ACL ARN"
#   value       = module.waf.web_acl_arn
# }

# =============================================================================
# S3
# =============================================================================
output "s3_static_bucket" {
  description = "정적 파일 버킷 이름"
  value       = module.s3.static_bucket_id
}

output "s3_logs_bucket" {
  description = "로그 버킷 이름"
  value       = module.s3.logs_bucket_id
}

# =============================================================================
# ElastiCache (Redis)
# =============================================================================
output "redis_endpoint" {
  description = "Redis 엔드포인트"
  value       = module.elasticache.redis_endpoint
}

output "redis_connection_string" {
  description = "Redis 연결 문자열 (Spring Boot용)"
  value       = module.elasticache.redis_connection_string
}

# =============================================================================
# Monitoring
# =============================================================================
output "sns_alerts_topic_arn" {
  description = "알람 알림 SNS Topic ARN"
  value       = module.monitoring.sns_topic_arn
}


# =============================================================================
# eks
# =============================================================================

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  value = module.eks.cluster_ca
}

output "eks_node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "oidc_issuer_url_spot" {
  value = module.eks.oidc_issuer_url
}

output "irsa_role_arns" {
  value = module.irsa.service_account_role_arns
}
