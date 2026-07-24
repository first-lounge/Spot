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

variable "enable_interface_endpoint" {
  description = "VPC 인터페이스 엔드포인트 활성화 여부"
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
variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

variable "manage_master_user_password" {
  description = "Secrets Manager용 DB 비밀번호"
  type        = bool
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS 스토리지 크기 (GB)"
  type        = number
}

variable "db_engine" {
  description = "DB 엔진"
  type        = string
}

variable "db_engine_version" {
  description = "PostgreSQL 버전"
  type        = string
}

# =============================================================================
# ALB DNS / 도메인 이름
# =============================================================================
variable "domain_name" {
  description = "도메인 이름"
  type        = string
  default     = "hbksv.cloud"
}

# =============================================================================
# WAF 모듈
# =============================================================================
variable "waf_rate_limit" {
  description = "5분당 최대 요청 수 (Rate Limiting)"
  type        = number
}

variable "waf_log_retention_days" {
  description = "WAF 로그 보관 일수"
  type        = number
}

# =============================================================================
# S3 모듈
# =============================================================================
variable "s3_log_transition_days" {
  description = "로그를 Glacier로 이동하는 일수"
  type        = number
  default     = 30
}

variable "s3_log_expiration_days" {
  description = "로그 삭제 일수"
  type        = number
  default     = 90
}

# =============================================================================
# Redis (ElastiCache) 모듈
# =============================================================================
variable "redis_engine" {
  description = "Redis 엔진"
  type        = string
}

variable "redis_node_type" {
  description = "Redis 노드 타입"
  type        = string
}

# dev 환경에서는 단일 노드
variable "redis_num_cache_clusters" {
  description = "Redis 클러스터 수 (1=단일, 2+=복제본)"
  type        = number
}

variable "redis_engine_version" {
  description = "Redis 엔진 버전"
  type        = string
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

variable "jwt_expire_ms" {
  description = "JWT 만료 시간 (밀리초)"
  type        = number
  default     = 3600000
}

variable "refresh_token_expire_days" {
  description = "리프레시 토큰 만료 일수"
  type        = number
  default     = 14
}

# Mail
variable "mail_username" {
  description = "SMTP 사용자 이름 (Gmail)"
  type        = string
  default     = ""
}

variable "mail_password" {
  description = "SMTP 비밀번호 (Gmail 앱 비밀번호)"
  type        = string
  sensitive   = true
  default     = ""
}

# Toss Payments
variable "toss_secret_key" {
  description = "Toss Payments 시크릿 키"
  type        = string
  sensitive   = true
  default     = ""
}

variable "toss_customer_key" {
  description = "Toss Payments 고객 키"
  type        = string
  default     = "customer_1"
}

# =============================================================================
# EKS 모듈
# =============================================================================
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.35"
}

variable "public_access_cidrs" {
  description = "EKS 클러스터 접속 허용 IP"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 인스턴스 유형"
  type        = list(string)
}

variable "capacity_type" {
  description = "인스턴스 구매 방식"
  type        = string
}

variable "desired_size" {
  description = "노드 희망 개수"
  type        = number
}

variable "max_size" {
  description = "노드 최대 개수"
  type        = number
}

variable "min_size" {
  description = "노드 최소 개수"
  type        = number
}

variable "volume_size" {
  description = "EBS 용량 크기"
  type        = number
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
