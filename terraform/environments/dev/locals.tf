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
      workload      = "backend"
      capacity_type = "SPOT"
      desired_size  = 3
      max_size      = 3
      min_size      = 3
      taints        = [] # dev는 taint 없음
    }
  }
}
