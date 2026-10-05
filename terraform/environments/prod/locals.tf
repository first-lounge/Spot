locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

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
