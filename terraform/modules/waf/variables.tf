variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "rate_limit" {
  description = "IP당 요청 수 제한 (5분 기준)"
  type        = number
}

variable "log_retention_days" {
  description = "WAF 로그 보관 기간 (일)"
  type        = number
}
