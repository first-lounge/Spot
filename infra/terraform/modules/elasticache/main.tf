# =============================================================================
# ElastiCache Redis - 캐시 및 세션 저장소
# =============================================================================
#
# -----------------------------------------------------------------------------
# Subnet Group
# -----------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis-subnet"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-redis-subnet" })
}

# # -----------------------------------------------------------------------------
# # Security Group
# # -----------------------------------------------------------------------------
resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-redis-sg" })
}

# -----------------------------------------------------------------------------
# Parameter Group (Redis 설정 커스터마이징)
# -----------------------------------------------------------------------------
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name_prefix}-redis-params"
  family = "redis7"

  # 세션 저장용 설정
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-redis-params" })
}

# -----------------------------------------------------------------------------
# Redis Replication Group (Cluster Mode Disabled)
# -----------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "${var.name_prefix} Redis cluster"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  # 인증 설정
  auth_token                 = var.auth_token != "" ? var.auth_token : null
  transit_encryption_enabled = var.auth_token != "" ? true : false
  at_rest_encryption_enabled = true

  # 자동 장애 조치 (Multi-AZ)
  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? true : false

  # 유지보수 윈도우
  maintenance_window       = var.maintenance_window
  snapshot_window          = var.snapshot_window
  snapshot_retention_limit = var.snapshot_retention_limit

  # 자동 버전 업그레이드
  auto_minor_version_upgrade = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-redis" })
}
