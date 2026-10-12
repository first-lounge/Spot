# =============================================================================
# 공통 설정값
# =============================================================================
variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
}

variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

# =============================================================================
# RDS 알람 지표
# =============================================================================
variable "rds_identifiers" {
  description = "RDS 인스턴스별 식별자"
  type        = map(string)
}

variable "rds_thresholds" {
  description = "RDS 지표별 임계값"
  type = object({
    cpu_percent          = optional(number, 80)  # 퍼센트
    free_storage_ratio   = optional(number, 0.2) # 비율 (0.2 = 20%)
    rds_connection_ratio = optional(number, 0.8)
  })
  default = {}
}

variable "slot_lag_thresholds" {
  description = "복제 슬롯 지연 알람 기준 (GiB)"
  type = object({
    warning  = optional(number, 2)
    critical = optional(number, 10)
  })
  default = {}
}

variable "rds_allocated_storage" {
  description = "RDS 스토리지 크기 (GiB)"
  type        = number
}

variable "rds_max_connection" {
  description = "RDS 인스턴스에 동시에 접속해 연결을 유지할 수 있는 최대 클라이언트 수"
  type        = number
}

variable "rds_instances" {
  description = "환경별 RDS 인스턴스 설정"
  type = map(object({
    cdc = bool # CDC 여부
  }))
}

# =============================================================================
# ElastiCache 알람 지표
# =============================================================================
variable "elasticache_thresholds" {
  description = "ElastiCache 지표별 임계값"
  type = object({
    mem_usage = optional(number, 80) # 퍼센트
    evictions = optional(number, 0)  # 합계(n개 이상)
  })
  default = {}
}

variable "elasticache_ids" {
  description = "ElastiCache 노드별 ID"
  type        = map(string)
}
