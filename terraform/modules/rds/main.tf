# =============================================================================
# RDS Subnet Group
# =============================================================================
resource "aws_db_subnet_group" "rds" {
  name       = "${var.name_prefix}-rds-subnet"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-subnet"
  })
}

# =============================================================================
# RDS Parameter Group
# =============================================================================
resource "aws_db_parameter_group" "rds_pg_16" {
  for_each = toset([for v in var.rds_instances : v.cdc ? "cdc" : "default"])

  name   = "${var.name_prefix}-pg16-${each.key}"
  family = "postgres16"

  # ── 정적 파라미터 (재부팅 필요) ──────────────────
  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  # wal_level=logical
  parameter {
    name         = "rds.logical_replication"
    value        = each.key == "cdc" ? "1" : "0"
    apply_method = "pending-reboot"
  }

  # ── 일반 설정 (즉시 적용) ────────────────────────
  # 한국 시간대
  parameter {
    name         = "timezone"
    value        = "Asia/Seoul"
    apply_method = "immediate"
  }

  # ── 쿼리 로깅 ────────────────────────────────────
  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = var.rds_settings.log_min_duration_statement
    apply_method = "immediate"
  }

  # 10MB 이상 디스크로 넘친 쿼리 기록 (단위: KB)
  parameter {
    name         = "log_temp_files"
    value        = "10240"
    apply_method = "immediate"
  }

  # ── 동시성 로깅 ──────────────────────────────────
  # deadlock_timeout(기본 1초) 이상 락을 기다린 쿼리 기록
  parameter {
    name         = "log_lock_waits"
    value        = "1"
    apply_method = "immediate"
  }

  # ── 접속 로깅 ────────────────────────────────────
  parameter {
    name         = "log_connections"
    value        = var.rds_settings.log_connections
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = var.rds_settings.log_disconnections
    apply_method = "immediate"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-parameter-group-${each.key}"
  })
}

# =============================================================================
# RDS 설정 (Dev & Prod)
# =============================================================================
resource "aws_db_instance" "this" {
  for_each = var.rds_instances

  db_name               = each.value.db_name
  identifier            = "${var.name_prefix}-${each.key}-rds"
  allocated_storage     = var.rds_settings.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage
  engine                = var.engine
  engine_version        = var.engine_version
  instance_class        = each.value.instance_class

  kms_key_id                    = var.rds_kms_arn
  master_user_secret_kms_key_id = var.rds_kms_arn
  username                      = var.username
  # Dev: 직접 설정 / Prod: Secrets Manager 사용
  manage_master_user_password = var.rds_settings.manage_master_user_password ? true : null
  password                    = var.rds_settings.manage_master_user_password ? null : var.password

  port = 5432

  parameter_group_name   = aws_db_parameter_group.rds_pg_16[each.value.cdc ? "cdc" : "default"].name
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az            = var.rds_settings.multi_az
  publicly_accessible = false
  storage_type        = "gp3"
  storage_encrypted   = true

  # Backup settings
  backup_retention_period = var.rds_settings.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Dev, Prod: deletion_protection=false → 스냅샷 없이 바로 삭제
  skip_final_snapshot       = var.rds_settings.skip_final_snapshot
  final_snapshot_identifier = "${var.name_prefix}-${each.key}-final-snapshot"
  delete_automated_backups  = var.rds_settings.delete_automated_backups
  deletion_protection       = var.rds_settings.deletion_protection
  copy_tags_to_snapshot     = var.rds_settings.copy_tags_to_snapshot

  # Monitoring (Performance Insight)
  performance_insights_enabled = var.rds_settings.performance_insights_enabled

  # Logging
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}-rds" })

  depends_on = [aws_cloudwatch_log_group.rds]
}

resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset([
    for pair in setproduct(keys(var.rds_instances), var.cloudwatch_logs_exports) :
    "/aws/rds/instance/${var.name_prefix}-${pair[0]}-rds/${pair[1]}"
  ])

  name              = each.value
  retention_in_days = var.rds_settings.log_retention_days

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-cloudwatch-log" })
}

# =============================================================================
# Secret Manager 로테이션
# =============================================================================
resource "aws_secretsmanager_secret_rotation" "rds" {
  for_each = { for k, v in aws_db_instance.this : k => v if var.rds_settings.manage_master_user_password }

  secret_id        = aws_db_instance.this[each.key].master_user_secret[0].secret_arn
  rotation_enabled = false
}
