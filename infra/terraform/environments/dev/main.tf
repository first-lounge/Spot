# =============================================================================
# Data Sources
# =============================================================================
data "aws_caller_identity" "current" {}

# =============================================================================
# Network (SPOT)
# =============================================================================
module "network_spot" {
  source = "../../modules/network"

  name_prefix          = "${local.name_prefix}-spot"
  common_tags          = local.common_tags
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  nat_instance_type    = var.nat_instance_type
}



# =============================================================================
# Database
# =============================================================================
module "database" {
  source = "../../modules/database"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  vpc_id            = module.network_spot.vpc_id
  vpc_cidr          = module.network_spot.vpc_cidr
  subnet_ids        = module.network_spot.private_subnet_ids

  allowed_security_group_ids = [module.eks.node_security_group_id]

  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  engine_version    = var.db_engine_version
}



# =============================================================================
# ECR (Multiple Repositories)
# =============================================================================
module "ecr" {
  source = "../../modules/ecr"

  project       = var.project
  name_prefix   = local.name_prefix
  common_tags   = local.common_tags
  service_names = toset(keys(var.services))
}

# =============================================================================
# DNS (Route 53 + ACM)
# =============================================================================
module "dns" {
  source = "../../modules/dns"

  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
  domain_name  = var.domain_name

  create_alb_record = var.create_alb_record
  alb_name          = "spot-dev-alb"
  alb_record_name   = "spotorder.org"
}


# =============================================================================
# WAF (Web Application Firewall)
# =============================================================================
module "waf" {
  source = "../../modules/waf"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  rate_limit         = var.waf_rate_limit
  log_retention_days = var.waf_log_retention_days
}


# =============================================================================
# S3 (정적 파일 / 로그 저장)
# =============================================================================
module "s3" {
  source = "../../modules/s3"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  account_id          = data.aws_caller_identity.current.account_id
  region              = var.region
  log_transition_days = var.s3_log_transition_days
  log_expiration_days = var.s3_log_expiration_days
}

# =============================================================================
# ElastiCache (Redis 캐시/세션)
# =============================================================================
module "elasticache" {
  source = "../../modules/elasticache"

  name_prefix                = local.name_prefix
  common_tags                = local.common_tags
  vpc_id                     = module.network_spot.vpc_id
  subnet_ids                 = module.network_spot.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_cache_clusters
  engine_version             = var.redis_engine_version
}

# =============================================================================
# Kafka (EC2 - KRaft Mode)
# =============================================================================
module "kafka" {
  source = "../../modules/kafka"

  name_prefix                = local.name_prefix
  common_tags                = local.common_tags
  vpc_id                     = module.network_spot.vpc_id
  vpc_cidr                   = module.network_spot.vpc_cidr
  subnet_id                  = module.network_spot.public_subnet_a_id # NAT 문제로 public 사용
  allowed_security_group_ids = [module.eks.node_security_group_id]
  assign_public_ip           = true

  instance_type       = var.kafka_instance_type
  volume_size         = var.kafka_volume_size
  log_retention_hours = var.kafka_log_retention_hours
}

# =============================================================================
# Parameter Store (Secrets & Dynamic Infrastructure Values)
# =============================================================================
module "parameters" {
  source = "../../modules/parameter-store"

  project     = var.project
  environment = var.environment
  common_tags = local.common_tags

  # 민감 정보 (SecureString)
  db_password     = var.db_password
  jwt_secret      = var.jwt_secret
  mail_password   = var.mail_password
  toss_secret_key = var.toss_secret_key

  # 동적 인프라 값 (RDS만 - Redis는 순환 의존성 방지를 위해 제외)
  db_endpoint = module.database.endpoint

  depends_on = [module.database]
}

# =============================================================================
# CloudWatch Monitoring (Updated for MSA)
# =============================================================================
module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
  alert_email = var.alert_email

  # RDS 모니터링
  rds_instance_id = module.database.instance_id

  # Redis 모니터링
  redis_cluster_id = "${local.name_prefix}-redis-001"
}


# =============================================================================
# eks (SPOT)
# =============================================================================
module "eks" {
  source = "../../modules/eks"

  name_prefix = "${local.name_prefix}-spot"
  common_tags = local.common_tags

  cluster_name    = "${var.cluster_name}-spot"
  cluster_version = var.cluster_version

  vpc_id = module.network_spot.vpc_id

  subnet_ids      = module.network_spot.private_subnet_ids
  node_subnet_ids = module.network_spot.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs    = var.eks_public_access_cidrs

  enable_node_group = true
  node_desired_size = 1
  node_min_size     = 1
  node_max_size     = 1

  enable_node_ssm = true
}


module "irsa" {
  source = "../../modules/irsa"

  name_prefix = "${local.name_prefix}-spot"
  common_tags = local.common_tags

  oidc_issuer_url = module.eks.oidc_issuer_url

  service_accounts = {
    aws_load_balancer_controller = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy_arn      = ""
      create_k8s_sa   = true
    }
    ebs_csi_driver = {
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
      policy_arn      = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      # ebs csi용 k8s sa는 만들지 않기
      create_k8s_sa   = false
    }

  }
}

module "eks_addons" {
  source = "../../modules/eks-addons"

  common_tags           = local.common_tags
  cluster_name          = module.eks.cluster_name
  ebs_csi_irsa_role_arn = module.irsa.service_account_role_arns["ebs_csi_driver"]


  enable_vpc_cni    = true
  enable_coredns    = true
  enable_kube_proxy = true
  enable_ebs_csi    = true
}
