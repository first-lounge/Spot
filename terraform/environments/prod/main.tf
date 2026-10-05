data "aws_caller_identity" "current" {}

# =============================================================================
# Network (VPC, CIDR, Subnet, IGW, Route Table, NAT GW)
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
  ebs_kms_arn         = module.kms.ebs_kms_arn
  node_group_role_arn = module.security.node_group_role_arn
  node_group_sg_id    = module.security.node_group_sg_id
  node_subnet_ids     = module.network.private_subnet_ids
  subnet_ids          = module.network.private_subnet_ids
  public_access_cidrs = var.public_access_cidrs

  node_groups    = local.node_groups
  instance_types = var.instance_types
  volume_size    = var.volume_size

  # IRSA (EKS Addons)
  hosted_zone_id = module.route53.hosted_zone_id
  account_id     = data.aws_caller_identity.current.account_id
  region         = var.region

  depends_on = [module.network, module.security]
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
# KMS
# =============================================================================
module "kms" {
  source = "../../modules/kms"

  # 공통
  name_prefix = local.name_prefix
  common_tags = local.common_tags
  account_id  = data.aws_caller_identity.current.account_id
}
