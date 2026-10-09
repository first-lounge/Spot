# =============================================================================
# 프로젝트 공통 설정
# =============================================================================
variable "project" {
  description = "프로젝트 이름"
  type        = string
  default     = "spot"
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "services" {
  description = "SPOT 서비스 목록"
  type        = set(string)
  default     = ["gateway", "user", "store", "order", "payment"]
}

# =============================================================================
# Network 모듈
# =============================================================================
variable "enable_nat_instance" {
  description = "NAT Instance 활성화 여부"
  type        = bool
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 활성화 여부"
  type        = bool
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  type        = map(string)
  default = {
    "a" = "10.0.3.0/24"
    "c" = "10.0.4.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  type        = map(string)
  default = {
    "a" = "10.0.31.0/24"
    "c" = "10.0.41.0/24"
  }
}

variable "db_subnet_cidrs" {
  description = "DB 서브넷 CIDR 목록"
  type        = map(string)
  default = {
    "a" = "10.0.5.0/24"
    "c" = "10.0.6.0/24"
  }
}

variable "availability_zones" {
  description = "사용할 가용 영역"
  type        = map(string)
  default = {
    "a" = "ap-northeast-2a"
    "c" = "ap-northeast-2c"
  }
}

# =============================================================================
# RDS 모듈
# =============================================================================
variable "rds_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

# =============================================================================
# ALB DNS / 도메인 이름
# =============================================================================
variable "domain_name" {
  description = "도메인 이름"
  type        = string
  default     = "hbksv.com"
}

# =============================================================================
# Redis (ElastiCache) 모듈
# =============================================================================
variable "elasticache_node_type" {
  description = "Redis 노드 타입"
  type        = string
}

# dev 환경에서는 단일 노드
variable "elasticache_num_cache_clusters" {
  description = "Redis 클러스터 수 (1=단일, 2+=복제본)"
  type        = number
}

# =============================================================================
# Monitoring 모듈
# =============================================================================
variable "alert_email" {
  description = "알람 알림 받을 이메일 (빈 값이면 구독 안함)"
  type        = string
}

# =============================================================================
# SSM 모듈
# =============================================================================

# JWT
variable "jwt_secret" {
  description = "JWT 시크릿 키"
  type        = string
  sensitive   = true
}

# Mail
variable "mail_username" {
  description = "SMTP 사용자 이름 (Gmail)"
  type        = string
  sensitive   = true
}

variable "mail_password" {
  description = "SMTP 비밀번호 (Gmail 앱 비밀번호)"
  type        = string
  sensitive   = true
}

# Toss Payments
variable "toss_secret_key" {
  description = "Toss Payments 시크릿 키"
  type        = string
  sensitive   = true
}

# =============================================================================
# EKS 모듈
# =============================================================================
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "spot-dev-cluster"
}

variable "public_access_cidrs" {
  description = "EKS 클러스터 접속 허용 IP"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 인스턴스 유형"
  type        = list(string)
  default     = ["t3.large", "t3a.large"]
}

variable "volume_size" {
  description = "EBS 용량 크기"
  type        = number
  default     = 30
}

# =============================================================================
# DNS
# =============================================================================

variable "create_alb_record" {
  type    = bool
  default = true
}

# =============================================================================
# Github
# =============================================================================
variable "git_branch" {
  description = "Github 브랜치"
  type        = string
}

# =============================================================================
# Route53
# =============================================================================
variable "zone_force_destroy" {
  description = "zone destroy 시 남은 레코드까지 강제 삭제(dev만 true, prod는 false)"
  type        = bool
  default     = false
}
