# =============================================================================
# Subnet Group
# =============================================================================
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis-subnet"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis-subnet"
  })
}

# =============================================================================
# Parameter Group
# =============================================================================
resource "aws_elasticache_parameter_group" "redis_7" {
  name   = "${var.name_prefix}-redis-7"
  family = "redis7"

  # 세션 저장용 설정
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
resource "aws_elasticache_replication_group" "redis" {
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
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_sg_id]

  # 파라미터 그룹
  parameter_group_name = aws_elasticache_parameter_group.redis_7.name

  # 암호화
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.auth_token != null ? true : null
  auth_token                 = var.auth_token

  # 유지보수 설정
  snapshot_retention_limit = var.snapshot_retention_limit
  maintenance_window       = var.maintenance_window
  snapshot_window          = var.snapshot_window

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis"
  })
}
