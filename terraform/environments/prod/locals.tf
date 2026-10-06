locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# EKS Node Group
# =============================================================================
locals {
  node_groups = {
    spot = {
      taints        = [{ key = "spot", value = "backend", effect = "NO_SCHEDULE" }]
      workload      = "backend"
      capacity_type = "SPOT"
      desired_size  = 3
      max_size      = 3
      min_size      = 3
    }
    infra = {
      taints        = [{ key = "spot", value = "infra", effect = "NO_SCHEDULE" }]
      workload      = "infra"
      capacity_type = "ON_DEMAND"
      desired_size  = 3
      max_size      = 3
      min_size      = 3
    }
    monitoring = {
      taints        = [{ key = "spot", value = "monitoring", effect = "NO_SCHEDULE" }]
      workload      = "monitoring"
      capacity_type = "ON_DEMAND"
      desired_size  = 2
      max_size      = 2
      min_size      = 2
    }
    etc = {
      taints        = [{ key = "CriticalAddonsOnly", value = "", effect = "NO_SCHEDULE" }]
      workload      = "etc"
      capacity_type = "ON_DEMAND"
      desired_size  = 2
      max_size      = 2
      min_size      = 2
    }

  }
}

# =============================================================================
# RDS 설정
# =============================================================================
locals {
  rds_settings = {
    # Parameter Group
    log_min_duration_statement = 1000
    log_connections            = 1
    log_disconnections         = 1

    # RDS 설정
    allocated_storage           = 50
    multi_az                    = true
    manage_master_user_password = true

    # 백업
    backup_retention_period  = 30
    skip_final_snapshot      = true  # 운영 전환 시 prod는 false
    delete_automated_backups = true  # 운영 전환 시 prod는 false
    deletion_protection      = false # 운영 전환 시 prod는 true
    copy_tags_to_snapshot    = false # 운영 전환 시 prod는 true

    # Performance Insights
    performance_insights_enabled = true

    # CloudWatch
    log_retention_days = 30

    # Secrets Manager 로테이션 (운영 전환 시 true)
    rotation_enabled = false
  }

  rds_instances = {
    user = {
      instance_class        = "db.t4g.small"
      db_name               = "spot_user"
      cdc                   = false
      max_allocated_storage = null
    }

    store = {
      instance_class        = "db.t4g.small"
      db_name               = "spot_store"
      cdc                   = false
      max_allocated_storage = null
    }

    order = {
      instance_class        = "db.t4g.medium"
      db_name               = "spot_order"
      cdc                   = true
      max_allocated_storage = 200
    }

    payment = {
      instance_class        = "db.t4g.medium"
      db_name               = "spot_payment"
      cdc                   = true
      max_allocated_storage = 200
    }

    temporal = {
      instance_class        = "db.t4g.medium"
      db_name               = null
      cdc                   = false
      max_allocated_storage = null
    }
  }
}
