variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "db_subnet_ids" {
  type        = list(string)
  description = "Redis 서브넷 ID (DB 서브넷과 겸용)"
}

variable "redis_sg_id" {
  type        = string
  description = "Redis 보안 그룹 ID"
}

# =============================================================================
# Redis 설정
# =============================================================================
variable "engine" {
  type        = string
  description = "ElastiCache 엔진"
}

variable "engine_version" {
  type        = string
  description = "ElastiCache 엔진 버전"
}

variable "node_type" {
  type        = string
  description = "노드 유형"
}

variable "num_cache_clusters" {
  description = "캐시 클러스터 수 (1=단일노드, 2+=복제본)"
  type        = number
}

variable "auth_token" {
  description = "Redis AUTH 토큰 (선택, 설정 시 전송 암호화 활성화)"
  type        = string
  default     = null
  sensitive   = true
}

# =============================================================================
# 유지보수 설정
# =============================================================================
variable "maintenance_window" {
  description = "유지보수 윈도우 (UTC)"
  type        = string
  default     = null # Dev 기준
}

variable "snapshot_window" {
  description = "스냅샷 윈도우 (UTC)"
  type        = string
  default     = null # Dev 기준
}

variable "snapshot_retention_limit" {
  description = "스냅샷 보존 일수 (0=비활성화)"
  type        = number
  default     = 0 # Dev 기준
}
