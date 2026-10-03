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
