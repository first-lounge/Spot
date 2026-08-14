data "aws_caller_identity" "current" {}

# =============================================================================
# Network (VPC, CIDR, Subnet, IGW, Route Table, NAT)
# =============================================================================
module "network" {
  source = "../../modules/network"

  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
  service_region            = var.region
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_subnet_cidrs      = var.private_subnet_cidrs
  db_subnet_cidrs           = var.db_subnet_cidrs
  nat_sg_id                 = module.security.nat_sg_id
  enable_nat_instance       = var.enable_nat_instance
  enable_nat_gateway        = var.enable_nat_gateway
  enable_interface_endpoint = var.enable_interface_endpoint
}

# =============================================================================
# Security (SG, IAM)
# =============================================================================
module "security" {
  source = "../../modules/security"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_cidr            = var.vpc_cidr
  vpc_id              = module.network.vpc_id
  enable_nat_instance = var.enable_nat_instance
}

# =============================================================================
# S3
# =============================================================================
module "s3" {
  source = "../../modules/s3"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
  account_id  = data.aws_caller_identity.current.account_id
  region      = var.region
}


# =============================================================================
# EKS (Cluster, Node Group, Add-Ons, IRSA, SA, LBC)
# =============================================================================
module "eks" {
  source = "../../modules/eks"

  # 공통
  project      = var.project
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
  cluster_name = var.cluster_name

  # Cluster
  cluster_role_arn = module.security.cluster_role_arn
  admin_role_arn   = data.aws_caller_identity.current.arn

  # Node Group
  node_group_role_arn = module.security.node_group_role_arn
  node_group_sg_id    = module.security.node_group_sg_id
  node_subnet_ids     = module.network.private_subnet_ids
  subnet_ids          = module.network.private_subnet_ids
  public_access_cidrs = var.public_access_cidrs

  min_size     = var.min_size
  max_size     = var.max_size
  desired_size = var.desired_size

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  volume_size    = var.volume_size

  # IRSA (EKS Addons)
  hosted_zone_id = module.route53.hosted_zone_id
  account_id     = data.aws_caller_identity.current.account_id
  region         = var.region

  depends_on = [module.network, module.security]
}

# =============================================================================
# ECR
# =============================================================================
module "ecr" {
  source = "../../modules/ecr"

  # 공통
  name_prefix   = local.name_prefix
  common_tags   = local.common_tags
  services_name = var.services
}


# =============================================================================
# RDS
# =============================================================================
module "rds" {
  source = "../../modules/rds"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # DB 설정
  engine                      = var.db_engine
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  username                    = var.db_username
  password                    = var.db_password
  manage_master_user_password = var.manage_master_user_password

  # DB 네트워크
  db_subnet_ids = module.network.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id
}

# =============================================================================
# Redis
# =============================================================================
module "redis" {
  source = "../../modules/redis"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Redis 네트워크
  db_subnet_ids = module.network.db_subnet_ids
  redis_sg_id   = module.security.redis_sg_id

  # Redis 설정
  engine             = var.redis_engine
  engine_version     = var.redis_engine_version
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_num_cache_clusters
}

# =============================================================================
# WAF
# =============================================================================
module "waf" {
  source = "../../modules/waf"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  rate_limit         = var.waf_rate_limit
  log_retention_days = var.waf_log_retention_days
}

# =============================================================================
# Route53
# =============================================================================
module "route53" {
  source = "../../modules/route53"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  domain_name        = var.domain_name
  zone_force_destroy = var.zone_force_destroy
}

# =============================================================================
# ACM
# =============================================================================
module "acm" {
  source = "../../modules/acm"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  domain_name = var.domain_name
  zone_id     = module.route53.hosted_zone_id
}

# =============================================================================
# Github OIDC
# =============================================================================
module "github_oidc" {
  source = "../../modules/github-oidc"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  git_branch     = var.git_branch
  account_id     = data.aws_caller_identity.current.account_id
  service_region = var.region
}

# =============================================================================
# SSM Parameter Store
# =============================================================================
module "parameter_store" {
  source = "../../modules/parameter-store"

  common_tags = local.common_tags
  project     = var.project
  environment = var.environment

  db_username     = var.db_username
  db_password     = var.db_password
  mail_username   = var.mail_username
  mail_password   = var.mail_password
  jwt_secret      = var.jwt_secret
  toss_secret_key = var.toss_secret_key

  db_endpoint    = module.rds.rds_endpoint
  redis_endpoint = module.redis.redis_reader_endpoint
}
