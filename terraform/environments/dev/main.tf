data "aws_caller_identity" "current" {}

# =============================================================================
# Network (VPC, CIDR, Subnet, IGW, Route Table, NAT)
# =============================================================================
module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  common_tags          = local.common_tags
  service_region       = var.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  nat_instance_sg_id   = module.security.nat_instance_sg_id
  enable_nat_instance  = var.enable_nat_instance
  enable_nat_gateway   = var.enable_nat_gateway
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

  node_groups    = local.node_groups
  instance_types = var.instance_types
  volume_size    = var.volume_size

  # IRSA (EKS Addons)
  hosted_zone_id           = module.route53.hosted_zone_id
  account_id               = data.aws_caller_identity.current.account_id
  region                   = var.region
  enable_rds_secret_access = local.rds_settings.manage_master_user_password

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
  rds_settings  = local.rds_settings
  rds_instances = local.rds_instances
  username      = var.rds_username
  password      = var.rds_password

  # DB 네트워크
  db_subnet_ids = module.network.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id
}

# =============================================================================
# Redis
# =============================================================================
module "elasticache" {
  source = "../../modules/elasticache"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Redis 네트워크
  db_subnet_ids     = module.network.db_subnet_ids
  elasticache_sg_id = module.security.elasticache_sg_id

  # Redis 설정
  node_type          = var.elasticache_node_type
  num_cache_clusters = var.elasticache_num_cache_clusters
}

# =============================================================================
# SSM Parameter Store
# =============================================================================
module "parameter_store" {
  source = "../../modules/parameter-store"

  common_tags = local.common_tags
  project     = var.project
  environment = var.environment

  rds_username      = var.rds_username
  enable_rds_secret = local.rds_settings.manage_master_user_password
  rds_password      = var.rds_password
  mail_username     = var.mail_username
  mail_password     = var.mail_password
  jwt_secret        = var.jwt_secret
  toss_secret_key   = var.toss_secret_key

  services             = local.services
  rds_host             = local.rds_host
  elasticache_endpoint = module.elasticache.elasticache_primary_endpoint
}

# =============================================================================
# Route53
# =============================================================================
module "route53" {
  source = "../../modules/route53"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  domain_name = var.domain_name
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

