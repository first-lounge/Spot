variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "account_id" {
  description = "AWS 계정 ID"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
}

variable "enable_versioning" {
  description = "Bucket 버저닝 활성화 여부"
  type        = bool
  default     = false # Dev: 비활성화 / Prod: true
}

variable "log_retention_days" {
  description = "로그 보관 기간 (일)"
  type        = number
  default     = 30 # Dev 기준
}
