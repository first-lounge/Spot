# =============================================================================
# Subnet Group
# =============================================================================
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis-subnet"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis-subnet"
  })
}

# =============================================================================
# Parameter Group
# =============================================================================
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name_prefix}-redis-7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis-parameter-group"
  })
}

# =============================================================================
# Replication Group
# =============================================================================

# Redis 랜덤 비밀번호 (Prod만)
# 운영 전환 시 삭제
resource "random_password" "this" {
  count = var.enable_elasticache_auth ? 1 : 0

  length           = 16
  special          = true
  override_special = "!&#$^<>-"
}

# # 운영 전환 시
# ephemeral "random_password" "this" {
#   count = var.enable_elasticache_auth ? 1 : 0
#
#   length           = 16
#   special          = true
#   override_special = "!&#$^<>-"
# }

# Redis 설정
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis cluster for Spot"

  # 엔진 설정
  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  # 복제 설정 (Dev=1, Prod= 2+)
  num_cache_clusters = var.num_cache_clusters

  # Multi-AZ 자동 장애 조치
  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? true : false

  # 네트워크 설정
  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.elasticache_sg_id]

  # 파라미터 그룹
  parameter_group_name = aws_elasticache_parameter_group.this.name

  # 암호화
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.enable_elasticache_auth
  auth_token                 = var.enable_elasticache_auth ? random_password.this[0].result : null # 운영 전환 시 삭제

  # # 운영 전환 시
  # auth_token_wo = var.enable_elasticache_auth ? ephemeral.random_password.this[0].result : null
  # auth_token_wo_version = var.elasticache_password_version

  # 유지보수 설정
  maintenance_window       = var.maintenance_window
  snapshot_window          = var.snapshot_window
  snapshot_retention_limit = var.snapshot_retention_limit

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis"
  })
}
