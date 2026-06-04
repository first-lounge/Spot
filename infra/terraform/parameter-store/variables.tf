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
variable "db_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT 시크릿 키"
  type        = string
  sensitive   = true
}

variable "mail_password" {
  description = "SMTP 비밀번호"
  type        = string
  sensitive   = true
  default     = ""
}

variable "toss_secret_key" {
  description = "Toss Payments 시크릿 키"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# 동적 인프라 값 (String으로 저장)
# =============================================================================
variable "db_endpoint" {
  description = "RDS 엔드포인트 (Terraform이 생성 후 자동 저장)"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis 엔드포인트 (Terraform이 생성 후 자동 저장)"
  type        = string
  default     = ""
}
