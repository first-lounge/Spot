variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (보안그룹용)"
  type        = string
}

variable "subnet_ids" {
  description = "DB 서브넷 ID 목록"
  type        = list(string)
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "username" {
  description = "DB 사용자 이름"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "DB 비밀번호"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "스토리지 크기 (GB)"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "16"
}

# =============================================================================
# Production Settings
# =============================================================================
variable "multi_az" {
  description = "Multi-AZ 배포 여부"
  type        = bool
  default     = false
}

variable "create_read_replica" {
  description = "Read Replica 생성 여부"
  type        = bool
  default     = false
}

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
  default     = "Mon:04:00-Mon:05:00"
}

variable "deletion_protection" {
  description = "삭제 보호 활성화"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring 간격 (초, 0이면 비활성화)"
  type        = number
  default     = 0
}

variable "storage_encrypted" {
  description = "스토리지 암호화"
  type        = bool
  default     = true
}

variable "max_allocated_storage" {
  description = "Auto Scaling 최대 스토리지 (GB), null이면 비활성화"
  type        = number
  default     = null
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to access the database"
  default     = []
}
