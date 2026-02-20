variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}


variable "rate_limit" {
  description = "5분당 최대 요청 수 (Rate Limiting)"
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "WAF 로그 보관 일수"
  type        = number
  default     = 30
}

variable "alb_name" {
  type    = string
  default = "spot-dev-alb"
}
