# =============================================================================
# 프로젝트 태그 이름
# =============================================================================
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
      workload      = "backend"
      capacity_type = "SPOT"
      desired_size  = 3
      max_size      = 3
      min_size      = 3
      taints        = [] # dev는 taint 없음
    }
  }
}

# =============================================================================
# RDS 설정
# =============================================================================
locals {
  services = ["user", "order", "payment", "store"]

  rds_endpoints = { for svc in local.services : svc => one(values(module.rds.rds_endpoint)) }

  rds_settings = {
    # Parameter Group
    log_min_duration_statement = 200
    log_connections            = 0
    log_disconnections         = 0

    # RDS 설정
    allocated_storage           = 20
    multi_az                    = false
    manage_master_user_password = false

    # 백업
    backup_retention_period  = 7
    skip_final_snapshot      = true
    delete_automated_backups = true
    deletion_protection      = false
    copy_tags_to_snapshot    = false

    # Performance Insights
    performance_insights_enabled = false

    # CloudWatch
    log_retention_days = 7

    # Secrets Manager 로테이션
    rotation_enabled = false
  }

  rds_instances = {
    shared = {
      instance_class        = "db.t4g.small"
      db_name               = null
      cdc                   = true
      max_allocated_storage = null
    }
  }
}
