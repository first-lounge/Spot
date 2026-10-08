output "elasticache_primary_endpoint" {
  description = "Redis 쓰기용 엔드포인트"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "elasticache_password" {
  description = "Redis 비밀번호"
  value       = var.enable_elasticache_auth ? random_password.this[0].result : null # 운영 전환 시 삭제
  sensitive   = true

  # # 운영 전환 시 
  # ephemeral   = true 
  # value       = var.enable_elasticache_auth ? ephemeral.random_password.this[0].result : null 
}
