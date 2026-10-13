# =============================================================================
# 프로젝트 공통 설정
# =============================================================================
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

variable "elasticache_sg_id" {
  type        = string
  description = "Redis 보안 그룹 ID"
}

# =============================================================================
# Redis 설정
# =============================================================================
variable "engine" {
  description = "ElastiCache 엔진"
  type        = string
  default     = "redis"
}

variable "engine_version" {
  description = "ElastiCache 엔진 버전"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "노드 유형"
  type        = string
}

variable "num_cache_clusters" {
  description = "캐시 클러스터 수 (1=단일노드, 2+=복제본)"
  type        = number
}

variable "enable_elasticache_auth" {
  description = "ElastiCache Auth 사용 여부"
  type        = bool
  default     = false
}

# # 운영 전환 시
# variable "elasticache_password_version" {
#   description = "Write-Only용 ElastiCache 비밀번호 버전"
#   type        = number
#   default     = 0
# }

# =============================================================================
# 유지보수 설정
# =============================================================================
variable "maintenance_window" {
  description = "유지보수 시간 (UTC)"
  type        = string
  default     = "Sat:19:00-Sat:20:00"
}

variable "snapshot_window" {
  description = "스냅샷 윈도우 (UTC)"
  type        = string
  default     = null # Dev, Prod 모두
}

variable "snapshot_retention_limit" {
  description = "스냅샷 보존 일수 (0=비활성화)"
  type        = number
  default     = 0
}
