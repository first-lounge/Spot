# =============================================================================
# 공통
# =============================================================================
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

# =============================================================================
# DB 설정
# =============================================================================
variable "db_name" {
  description = "DB 이름"
  type        = string
}

variable "engine" {
  description = "DB 엔진"
  type        = string
}

variable "engine_version" {
  description = "DB 엔진 버전"
  type        = string
}

variable "instance_class" {
  description = "인스턴스 클래스"
  type        = string
}

variable "allocated_storage" {
  description = "스토리지 크기 (GB)"
  type        = number
}

variable "username" {
  description = "DB 사용자 이름"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "Dev용 DB 비밀번호"
  type        = string
  sensitive   = true
}

variable "manage_master_user_password" {
  description = "Prod용 DB 비밀번호"
  type        = bool
}

# =============================================================================
# DB 네트워크
# =============================================================================
variable "db_subnet_ids" {
  description = "DB 서브넷 ID"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS 보안 그룹 ID"
  type        = string
}

# =============================================================================
# Production Settings
# =============================================================================
variable "multi_az" {
  description = "Multi AZ 배포 여부"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "스토리지 암호화 여부"
  type        = bool
  default     = true
}

# =============================================================================
# Backup settings
# =============================================================================
variable "backup_retention_period" {
  description = "백업 보관 기간 (일)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "백업 시간 (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 시간 (UTC)"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "deletion_protection" {
  description = "삭제 보호 활성화"
  type        = bool
  default     = false
}

variable "copy_tags_to_snapshot" {
  description = "value"
  type        = bool
  default     = false
}

# =============================================================================
# Monitoring
# =============================================================================
variable "performance_insights_enabled" {
  description = "성능 모니터링 활성화 여부"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring 간격 (초, 0이면 비활성화)"
  type        = number
  default     = 0
}

variable "rds_monitoring_role_arn" {
  description = "RDS 모니터링 Role ARN"
  type        = string
  default     = ""
}

# =============================================================================
# 로깅
# =============================================================================
variable "cloudwatch_logs_exports" {
  description = "CloudWatch로 내보낼 로그 유형"
  type        = list(string)
  default     = ["postgresql", "upgrade", "iam-db-auth-error"]
}


variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 7 # Dev 기준 / Prod: 30
}
