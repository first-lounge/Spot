# =============================================================================
# Database Security Group
# =============================================================================
resource "aws_security_group" "db_sg" {
  name   = "${var.name_prefix}-db-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-db-sg" })
}

# =============================================================================
# RDS Subnet Group
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

# =============================================================================
# Enhanced Monitoring IAM Role
# =============================================================================
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# RDS Parameter Group (Production tuning)
# =============================================================================
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-pg16"
  family = "postgres16"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-pg16" })
}

# =============================================================================
# RDS Instance (PostgreSQL)
# =============================================================================
resource "aws_db_instance" "main" {
  identifier            = "${var.name_prefix}-db"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  db_name               = var.db_name
  username              = var.username
  password              = var.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  # Production settings
  multi_az            = var.multi_az
  publicly_accessible = false
  storage_type        = "gp3"
  storage_encrypted   = var.storage_encrypted

  # Backup settings
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name_prefix}-db-final-snapshot" : null
  delete_automated_backups  = !var.deletion_protection
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true

  # Monitoring
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-db" })
}

# =============================================================================
# Read Replica
# =============================================================================
resource "aws_db_instance" "replica" {
  count = var.create_read_replica ? 1 : 0

  identifier             = "${var.name_prefix}-db-replica"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.instance_class
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible = false
  storage_encrypted   = var.storage_encrypted
  skip_final_snapshot = true

  # Monitoring
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-replica"
    Role = "replica"
  })
}
