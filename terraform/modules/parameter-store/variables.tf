# =============================================================================
# Parameter Store Module Variables
# =============================================================================

variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

# =============================================================================
# 민감 정보 (SecureString으로 저장)
# =============================================================================
variable "rds_username" {
  description = "데이터베이스 유저명"
  type        = string
  sensitive   = true
}

variable "enable_rds_secret" {
  description = "Secrets Manager 사용 여부"
  type        = bool
}

variable "rds_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
  default     = null
}

variable "jwt_secret" {
  description = "JWT 시크릿 키"
  type        = string
  sensitive   = true
}

variable "mail_username" {
  description = "SMTP 유저명"
  type        = string
  sensitive   = true
}

variable "mail_password" {
  description = "SMTP 비밀번호"
  type        = string
  sensitive   = true
}

variable "toss_secret_key" {
  description = "Toss Payments 시크릿 키"
  type        = string
  sensitive   = true
}

# =============================================================================
# 동적 인프라 값 (String으로 저장)
# =============================================================================
variable "services" {
  description = "Spot 앱 서비스"
  type        = set(string)
}

variable "rds_host" {
  description = "RDS Host 이름"
  type        = map(string)
}

variable "elasticache_endpoint" {
  description = "Redis 엔드포인트 (Terraform이 생성 후 자동 저장)"
  type        = string
}

variable "enable_elasticache_auth" {
  description = "Redis Auth 사용 여부"
  type        = bool
  default     = false
}

variable "elasticache_password" {
  description = "Redis 비밀번호"
  type        = string
  sensitive   = true
  default     = null
  # ephemeral = true  # 운영 전환 시
}

# # 운영 전환 시
# variable "elasticache_password_version" {
#   description = "Write-Only용 ElastiCache 비밀번호 버전"
#   type        = number
#   default     = 0
# }
