# =============================================================================
# 공통 변수
# =============================================================================
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

# =============================================================================
# 알림 설정
# =============================================================================
variable "alert_email" {
  description = "알람 알림 받을 이메일 (빈 값이면 구독 안함)"
  type        = string
  default     = ""
}

# =============================================================================
# ECS 모니터링 대상
# =============================================================================
variable "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS 서비스 이름"
  type        = string
  default     = ""
}

variable "ecs_cpu_threshold" {
  description = "ECS CPU 알람 임계값 (%)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "ECS Memory 알람 임계값 (%)"
  type        = number
  default     = 80
}

# =============================================================================
# RDS 모니터링 대상
# =============================================================================
variable "rds_instance_id" {
  description = "RDS 인스턴스 ID"
  type        = string
}

variable "rds_cpu_threshold" {
  description = "RDS CPU 알람 임계값 (%)"
  type        = number
  default     = 80
}

variable "rds_connections_threshold" {
  description = "RDS 연결 수 알람 임계값"
  type        = number
  default     = 50
}

variable "rds_storage_threshold_bytes" {
  description = "RDS 남은 스토리지 알람 임계값 (bytes)"
  type        = number
  default     = 5368709120 # 5GB
}

# =============================================================================
# ALB 모니터링 대상
# =============================================================================
variable "alb_arn_suffix" {
  description = "ALB ARN suffix (app/xxx/xxx 형식)"
  type        = string
  default     = ""
}

variable "alb_5xx_threshold" {
  description = "ALB 5XX 에러 수 알람 임계값"
  type        = number
  default     = 10
}

variable "alb_response_time_threshold" {
  description = "ALB 응답 시간 알람 임계값 (초)"
  type        = number
  default     = 3
}

# =============================================================================
# Redis 모니터링 대상 (선택)
# =============================================================================
variable "redis_cluster_id" {
  description = "ElastiCache 클러스터 ID (빈 값이면 Redis 알람 생략)"
  type        = string
  default     = ""
}

variable "redis_cpu_threshold" {
  description = "Redis CPU 알람 임계값 (%)"
  type        = number
  default     = 75
}

variable "redis_memory_threshold" {
  description = "Redis Memory 알람 임계값 (%)"
  type        = number
  default     = 80
}

# =============================================================================
# Monitoring 옵션
# =============================================================================
variable "enable_ecs_alarms" {
  description = "ECS 알람 생성 여부 (EKS 전환 시 보통 false)"
  type        = bool
  default     = false
}

variable "enable_alb_alarms" {
  description = "ALB 알람 생성 여부 (ALB ARN suffix가 확정된 경우에만 true)"
  type        = bool
  default     = false
}
