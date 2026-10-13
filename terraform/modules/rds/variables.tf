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
variable "engine" {
  description = "DB 엔진"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "DB 엔진 버전"
  type        = string
  default     = "16"
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
  default     = null
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
# RDS Settings & Instances
# =============================================================================
variable "rds_kms_arn" {
  description = "RDS용 KMS 키 ARN"
  type        = string
  default     = null
}

variable "rds_settings" {
  description = "환경별 RDS 설정"
  type = object({
    # Parameter Group
    max_connections            = number # 인스턴스에 허용되는 동시 클라이언트 연결 수
    log_min_duration_statement = number # 이 시간(ms) 이상 걸린 쿼리 기록
    log_connections            = number # 성공한 연결 기록 (0/1)
    log_disconnections         = number # 세션 종료·기간 기록 (0/1)

    # 인스턴스
    allocated_storage            = number # 스토리지 크기 (GB)
    multi_az                     = bool
    manage_master_user_password  = bool # true면 Secrets Manager 관리형 암호
    performance_insights_enabled = bool

    # 백업·삭제
    backup_retention_period  = number # 백업 보관 기간 (일)
    deletion_protection      = bool   # 삭제 요청 자체를 거부
    skip_final_snapshot      = bool   # 삭제 전 최종 스냅샷 생략
    delete_automated_backups = bool   # 삭제 시 자동 백업도 같이 삭제
    copy_tags_to_snapshot    = bool

    # 로그
    log_retention_days = number # CloudWatch 로그 보관 기간 (일)

    # CMK
    rotation_enabled = bool
  })
}

variable "rds_instances" {
  description = "환경별 RDS 인스턴스 설정"
  type = map(object({
    instance_class        = string # 인스턴스 클래스
    db_name               = string # DB 이름
    cdc                   = bool   # CDC 여부
    max_allocated_storage = number # 자동 확장 최대 크기
  }))
}

# =============================================================================
# Backup settings
# =============================================================================

variable "backup_window" {
  description = "백업 시간 (UTC)"
  type        = string
  default     = "17:00-18:00"
}

variable "maintenance_window" {
  description = "유지보수 시간 (UTC)"
  type        = string
  default     = "Sat:19:00-Sat:20:00"
}

# =============================================================================
# 로깅
# =============================================================================
variable "cloudwatch_logs_exports" {
  description = "CloudWatch로 내보낼 로그 유형"
  type        = list(string)
  default     = ["postgresql", "upgrade", "iam-db-auth-error"]
}
