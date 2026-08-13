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
  name   = "${var.name_prefix}-pg16"
  family = "postgres16"

  # 연결 설정
  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000" # 1초 이상 쿼리 로깅
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot" # 정적 파라미터라 재부팅 필요
  }

  # wal_level=logical
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # 한국 시간대
  parameter {
    name         = "timezone"
    value        = "Asia/Seoul"
    apply_method = "pending-reboot"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-parameter-group"
  })
}

# =============================================================================
# RDS 설정(Dev만)
# =============================================================================
resource "aws_db_instance" "rds" {
  identifier        = "${var.name_prefix}-rds"
  allocated_storage = var.allocated_storage
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class

  username = var.username

  # Dev: 직접 설정 / Prod: Secrets Manager 사용
  manage_master_user_password = var.manage_master_user_password ? true : null
  password                    = var.manage_master_user_password ? null : var.password

  port = 5432

  parameter_group_name   = aws_db_parameter_group.rds_pg_16.name
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_sg_id]

  # Production settings
  multi_az            = var.multi_az
  publicly_accessible = false
  storage_type        = "gp3"
  storage_encrypted   = var.storage_encrypted

  # Backup settings
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Dev: deletion_protection=false → 스냅샷 없이 바로 삭제 가능
  # Prod: deletion_protection=true → 삭제 전 최종 스냅샷 생성
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name_prefix}-db-final-snapshot" : null
  delete_automated_backups  = !var.deletion_protection
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot

  # Monitoring
  performance_insights_enabled = var.performance_insights_enabled # Prod에서만
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? var.rds_monitoring_role_arn : null

  # Logging
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds" })
}

resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset([
    for log in var.cloudwatch_logs_exports :
    "/aws/rds/${var.name_prefix}-rds/${log}"
  ])

  name              = each.value
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-cloudwatch-log" })
}
